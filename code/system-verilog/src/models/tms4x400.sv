//============================================================================
//  tms4x400.sv
//
//  Behavioral (NON-SYNTHESIZABLE) SystemVerilog model of the Texas
//  Instruments TMS44400 / TMS44400P / TMS46400 / TMS46400P
//  1 048 576-word by 4-bit dynamic random-access memory.
//
//  Source: TI datasheet SMHS562C - MAY 1995, REVISED NOVEMBER 1996.
//
//  This is a timing-accurate simulation model, not RTL.  It exists to be
//  driven by a memory controller testbench and to complain loudly when that
//  controller violates the datasheet.  It models:
//
//    * 1M x 4 sparse storage (uninitialised cells read as X)
//    * Multiplexed 10-bit row / 10-bit column addressing (1024 x 1024)
//    * Read, early-write, late-write (read-modify-write) cycles
//    * Enhanced page mode - column address buffers are transparent while
//      CAS is high, so an access may begin before CAS falls (tAA / tCPA)
//    * RAS-only refresh, CAS-before-RAS (CBR) refresh, hidden refresh
//      and (P devices) self refresh
//    * WCBR test mode: 512K x 8 with 2-bit parallel compare per DQ
//    * The full switching-characteristics access-time model
//      (tRAC / tCAC / tAA / tCPA / tOEA / tCLZ / tOFF / tOEZ)
//    * Every min/max entry in the "timing requirements" tables, checked
//      at runtime with a datasheet-named violation message
//    * Refresh interval tracking per row (tREF), with optional data decay
//
//  Speed grade is selected with the SPEED parameter (60, 70 or 80).
//  LOW_POWER selects the 'P' variants (self refresh, 128 ms refresh period).
//
//  Bit mapping: DQ[0] is the datasheet's DQ1 ... DQ[3] is DQ4.
//============================================================================

`timescale 1ns / 1ps

module tms4x400 #(
    // ---- device selection -------------------------------------------------
    parameter int SPEED             = 60,    // 60 | 70 | 80  (ns tRAC grade)
    parameter bit LOW_POWER         = 1'b0,  // 1 => TMS4x400P (self refresh)
    parameter bit LVOLT             = 1'b0,  // 0 => TMS44400 (5V), 1 => TMS46400 (3.3V)

    // ---- model behaviour --------------------------------------------------
    parameter bit TIMING_CHECKS     = 1'b1,  // enforce timing-requirement mins
    parameter bit CHECK_ACCESS_MAX  = 1'b0,  // also flag tRCD/tRAD max overruns
    parameter bit REFRESH_CHECKS    = 1'b1,  // enforce tREF per row
    parameter bit DECAY_ENABLE      = 1'b0,  // corrupt rows that miss tREF
    parameter bit POWERUP_CHECKS    = 1'b1,  // 200us pause + 8 init cycles
    parameter bit STOP_ON_VIOLATION = 1'b0,  // $stop on first violation
    parameter bit VERBOSE           = 1'b0   // log every cycle
) (
    input  wire [9:0] A,      // A0-A9, row then column
    input  wire       RAS_N,  // row-address strobe,    active low
    input  wire       CAS_N,  // column-address strobe, active low
    input  wire       W_N,    // write enable,          active low
    input  wire       OE_N,   // output enable,         active low
    inout  wire [3:0] DQ      // DQ1-DQ4 bidirectional data
);

  //==========================================================================
  // Speed-grade timing tables  (all values in ns, transcribed from
  // SMHS562C pages 8-10).  SG: 0 = -60, 1 = -70, 2 = -80.
  //==========================================================================
  localparam int SG = (SPEED <= 60) ? 0 : (SPEED <= 70) ? 1 : 2;

  // ---- switching characteristics (access times, MAX unless noted) ---------
  localparam real tAA   = (SG==0) ?  30.0 : (SG==1) ?  35.0 :  40.0; // col addr access
  localparam real tCAC  = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0; // CAS low access
  localparam real tCPA  = (SG==0) ?  35.0 : (SG==1) ?  40.0 :  45.0; // col precharge access
  localparam real tRAC  = (SG==0) ?  60.0 : (SG==1) ?  70.0 :  80.0; // RAS low access
  localparam real tOEA  = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0; // OE low access
  localparam real tCLZ  =   0.0;                                     // CAS to low-Z (MIN)
  localparam real tOFF  = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0; // disable after CAS high
  localparam real tOEZ  = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0; // disable after OE high

  // ---- test-mode access times --------------------------------------------
  localparam real tTAA  = (SG==0) ?  35.0 : (SG==1) ?  40.0 :  45.0;
  localparam real tTCPA = (SG==0) ?  40.0 : (SG==1) ?  45.0 :  50.0;
  localparam real tTRAC = (SG==0) ?  65.0 : (SG==1) ?  75.0 :  85.0;

  // ---- timing requirements: cycle times (MIN) -----------------------------
  localparam real tRC   = (SG==0) ? 110.0 : (SG==1) ? 130.0 : 150.0; // random R/W cycle
  localparam real tRWC  = (SG==0) ? 155.0 : (SG==1) ? 181.0 : 205.0; // read-write cycle
  localparam real tPC   = (SG==0) ?  40.0 : (SG==1) ?  45.0 :  50.0; // page R or W cycle
  localparam real tPRWC = (SG==0) ?  85.0 : (SG==1) ?  96.0 : 105.0; // page read-write cycle

  // ---- timing requirements: pulse durations -------------------------------
  localparam real tRASP_MIN = (SG==0) ?  60.0 : (SG==1) ?  70.0 :  80.0; // RAS low, page mode
  localparam real tRASP_MAX = 100000.0;                                  // 100 us
  localparam real tRAS_MIN  = (SG==0) ?  60.0 : (SG==1) ?  70.0 :  80.0; // RAS low, nonpage
  localparam real tRAS_MAX  =  10000.0;                                  // 10 us
  localparam real tRASS_MIN = 100000.0;                                  // RAS low, self refresh
  // NOTE: tCAS MIN is printed as 10/18/20 in SMHS562C table (p.9); the -60
  // column really is the smallest.  Transcribed verbatim.
  localparam real tCAS_MIN  = (SG==0) ?  10.0 : (SG==1) ?  18.0 :  20.0; // CAS low
  localparam real tCAS_MAX  =  10000.0;
  localparam real tCP       =  10.0;                                     // CAS high
  localparam real tRP       = (SG==0) ?  40.0 : (SG==1) ?  50.0 :  60.0; // RAS high (precharge)
  localparam real tRPS      = (SG==0) ? 110.0 : (SG==1) ? 130.0 : 150.0; // precharge after self refresh
  localparam real tWP       =  10.0;                                     // W low

  // ---- timing requirements: setup times (MIN) -----------------------------
  localparam real tASC =   0.0;                                      // col addr before CAS low
  localparam real tASR =   0.0;                                      // row addr before RAS low
  localparam real tDS  =   0.0;                                      // data (see Note 12)
  localparam real tRCS =   0.0;                                      // W high before CAS low
  localparam real tCWL = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0;  // W low before CAS high
  localparam real tRWL = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0;  // W low before RAS high
  localparam real tWCS =   0.0;                                      // W low before CAS low (early write)
  localparam real tWSR =  10.0;                                      // W high before RAS low (CBR)
  localparam real tWTS =  10.0;                                      // W low before RAS low (test mode)

  // ---- timing requirements: hold times (MIN) ------------------------------
  localparam real tCAH = (SG==0) ?  10.0 : (SG==1) ?  15.0 :  15.0;  // col addr after CAS low
  localparam real tDHR = (SG==0) ?  50.0 : (SG==1) ?  55.0 :  60.0;  // data after RAS low
  localparam real tDH  = (SG==0) ?  10.0 : (SG==1) ?  15.0 :  15.0;  // data (see Note 12)
  localparam real tAR  = (SG==0) ?  50.0 : (SG==1) ?  55.0 :  60.0;  // col addr after RAS low
  localparam real tRAH =  10.0;                                      // row addr after RAS low
  localparam real tRCH =   0.0;                                      // W high after CAS high
  localparam real tRRH =   0.0;                                      // W high after RAS high
  localparam real tWCH = (SG==0) ?  10.0 : (SG==1) ?  15.0 :  15.0;  // W low after CAS low
  localparam real tWCR = (SG==0) ?  50.0 : (SG==1) ?  55.0 :  60.0;  // W low after RAS low
  localparam real tWHR =  10.0;                                      // W high after RAS low (CBR)
  localparam real tWTH =  10.0;                                      // W low after RAS low (test mode)
  localparam real tCHS = -50.0;                                      // CAS low after RAS high (self refresh)
  localparam real tOEH = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0;  // OE command
  localparam real tOED = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0;  // OE to data delay
  localparam real tROH =  10.0;                                      // RAS referenced to OE

  // ---- timing requirements: delay times -----------------------------------
  localparam real tAWD     = (SG==0) ?  55.0 : (SG==1) ?  63.0 :  70.0; // col addr -> W low (R-M-W)
  localparam real tCHR     =  10.0;                                     // RAS low -> CAS high (CBR)
  localparam real tCRP     =   0.0;                                     // CAS high -> RAS low
  localparam real tCSH     = (SG==0) ?  60.0 : (SG==1) ?  70.0 :  80.0; // RAS low -> CAS high
  localparam real tCSR     =   5.0;                                     // CAS low -> RAS low (CBR)
  localparam real tCWD     = (SG==0) ?  40.0 : (SG==1) ?  46.0 :  50.0; // CAS low -> W low (R-M-W)
  localparam real tRAD_MIN =  15.0;                                     // RAS low -> col addr
  localparam real tRAD_MAX = (SG==0) ?  30.0 : (SG==1) ?  35.0 :  40.0;
  localparam real tRAL     = (SG==0) ?  30.0 : (SG==1) ?  35.0 :  40.0; // col addr -> RAS high
  localparam real tCAL     = (SG==0) ?  30.0 : (SG==1) ?  35.0 :  40.0; // col addr -> CAS high
  localparam real tRCD_MIN =  20.0;                                     // RAS low -> CAS low
  localparam real tRCD_MAX = (SG==0) ?  45.0 : (SG==1) ?  52.0 :  60.0;
  localparam real tRPC     =   0.0;                                     // RAS high -> CAS low
  localparam real tRSH     = (SG==0) ?  15.0 : (SG==1) ?  18.0 :  20.0; // CAS low -> RAS high
  localparam real tRWD     = (SG==0) ?  85.0 : (SG==1) ?  98.0 : 110.0; // RAS low -> W low (R-M-W)

  // ---- refresh ------------------------------------------------------------
  localparam real tREF     = LOW_POWER ? 128000000.0 : 16000000.0;      // 128 ms / 16 ms
  localparam real tT_MIN   =   2.0;
  localparam real tT_MAX   =  30.0;

  localparam int  N_ROWS   = 1024;
  localparam int  N_COLS   = 1024;

  // Sentinel meaning "this edge has not happened yet".
  localparam real NEVER    = -1.0e12;
  // Slack for real-number comparisons (well below the 1ps precision).
  localparam real TOL      =  0.0005;

  //==========================================================================
  // Storage.  Associative so that a 1M-cell part costs only what the
  // testbench actually touches, and so that never-written cells read X.
  //==========================================================================
  logic [3:0] mem [0:(N_ROWS*N_COLS)-1];  // X until written, like a real cell
  realtime    row_last_ref [0:N_ROWS-1];  // per-row refresh timestamp
  bit         row_decayed  [0:N_ROWS-1];

  //==========================================================================
  // Cycle state
  //==========================================================================
  typedef enum int {
    C_IDLE,      // RAS high
    C_ACTIVE,    // normal row active (read / write / page mode)
    C_ROR,       // RAS-only refresh (no CAS fall seen yet)
    C_CBR,       // CAS-before-RAS refresh (incl. hidden refresh)
    C_SELF,      // self refresh (P devices)
    C_TEST_ENTRY // WCBR test-mode entry cycle
  } cyc_e;

  cyc_e       cyc;                 // what the current RAS-low period is doing
  logic [9:0] row_q;               // latched row address
  logic [9:0] col_t;               // transparent column address (RAS low, CAS high)
  logic [9:0] col_q;               // column address latched by CAS falling
  logic [9:0] cbr_cnt;             // internal CBR refresh counter
  bit         test_mode;           // WCBR test mode active
  bit         cas_seen_this_ras;   // a CAS fall occurred during this RAS-low period
  bit         page_access;         // at least one CAS precharge since RAS fall
  bit         early_write;         // W was low at the CAS falling edge
  bit         wrote_this_cas;      // a write already happened for this column
  bit         read_this_cas;       // this column started as a read
  bit         rmw_cycle;           // read-modify-write (late write after a read)
  bit         self_ref_exited;     // last RAS-low period was a self refresh

  int unsigned init_cycles;        // RAS cycles counted at power-up
  bit          pwr_ready;          // 200 us elapsed and >=8 init cycles w/ refresh
  bit          init_refresh_seen;

  int unsigned n_viol, n_warn;     // violation / warning counters
  int unsigned n_rd, n_wr, n_ref;  // activity counters

  //==========================================================================
  // Edge timestamps
  //==========================================================================
  realtime t_ras_fall, t_ras_rise;
  realtime t_cas_fall, t_cas_rise, t_cas_rise_in_ras;
  realtime t_w_fall,   t_w_rise;
  realtime t_oe_fall,  t_oe_rise;
  realtime t_addr_chg;             // any address change
  realtime t_col_chg;              // column address change while transparent
  realtime t_dq_chg;               // DQ input change
  realtime t_wr_strobe;            // instant a write latched data
  realtime t_ras_low_start_self;   // for self-refresh entry detection

  //==========================================================================
  // Read-access engine state (see the "read data path" section below)
  //==========================================================================
  bit         rd_armed;            // an access is valid / in flight
  bit         rd_done;             // access has landed
  realtime    rd_valid_at;         // absolute time data becomes valid
  logic [3:0] dq_o;                // value driven onto DQ
  bit         dq_valid;            // 0 => drive X (low-Z but not yet accessed)
  bit         dq_oe;               // output buffers in low-Z
  bit         out_armed;           // a read cycle has claimed the output buffers

  assign DQ = dq_oe ? (dq_valid ? dq_o : 4'bxxxx) : 4'bzzzz;

  //==========================================================================
  // Reporting helpers
  //==========================================================================
  function automatic string dev_name();
    return $sformatf("TMS%s400%s-%0d", LVOLT ? "46" : "44",
                     LOW_POWER ? "P" : "", SPEED);
  endfunction

  task automatic viol(input string msg);
    n_viol++;
    $display("%0t ps | %m | TIMING VIOLATION: %s", $time, msg);
    if (STOP_ON_VIOLATION) $stop;
  endtask

  task automatic warn(input string msg);
    n_warn++;
    $display("%0t ps | %m | WARNING: %s", $time, msg);
  endtask

  task automatic note(input string msg);
    if (VERBOSE) $display("%0t ps | %m | %s", $time, msg);
  endtask

  // Minimum-time check: `nm` must have elapsed since `t0`.
  task automatic chk_min(input string nm, input realtime t0, input real lim);
    if (TIMING_CHECKS && (t0 > NEVER) && ((($realtime - t0) + TOL) < lim))
      viol($sformatf("%s = %0.3f ns, minimum %0.3f ns", nm, $realtime - t0, lim));
  endtask

  // Maximum-time check for the "specified only to ensure access time" params.
  task automatic chk_max_acc(input string nm, input realtime t0, input real lim);
    if (TIMING_CHECKS && CHECK_ACCESS_MAX && (t0 > NEVER) &&
        (($realtime - t0) > (lim + TOL)))
      warn($sformatf("%s = %0.3f ns exceeds the %0.3f ns maximum; access is no longer tRAC-limited",
                     nm, $realtime - t0, lim));
  endtask

  // Hard maximum (a real functional limit, e.g. tRAS max).
  task automatic chk_max(input string nm, input realtime t0, input real lim);
    if (TIMING_CHECKS && (t0 > NEVER) && (($realtime - t0) > (lim + TOL)))
      viol($sformatf("%s = %0.3f ns, maximum %0.3f ns", nm, $realtime - t0, lim));
  endtask

  //==========================================================================
  // Memory access primitives
  //==========================================================================
  function automatic int addr_of(input logic [9:0] r, input logic [9:0] c);
    return int'({r, c});
  endfunction

  function automatic logic [3:0] cell_rd(input logic [9:0] r, input logic [9:0] c);
    cell_rd = mem[addr_of(r, c)];
  endfunction

  task automatic cell_wr(input logic [9:0] r, input logic [9:0] c, input logic [3:0] d);
    mem[addr_of(r, c)] = d;
  endtask

  // Test mode pairs two columns (differing in A0) behind one 512K x 8 address.
  function automatic logic [9:0] col_even(input logic [9:0] c);
    return {c[9:1], 1'b0};
  endfunction
  function automatic logic [9:0] col_odd(input logic [9:0] c);
    return {c[9:1], 1'b1};
  endfunction

  // Read as the part presents it: normal, or test-mode 2-bit compare.
  function automatic logic [3:0] read_word(input logic [9:0] r, input logic [9:0] c);
    logic [3:0] a, b, res;
    if (!test_mode) return cell_rd(r, c);
    a = cell_rd(r, col_even(c));
    b = cell_rd(r, col_odd(c));
    for (int i = 0; i < 4; i++) res[i] = (a[i] === b[i]) ? 1'b1 : 1'b0;
    return res;
  endfunction

  task automatic write_word(input logic [9:0] r, input logic [9:0] c, input logic [3:0] d);
    if (!test_mode) begin
      cell_wr(r, c, d);
    end else begin
      cell_wr(r, col_even(c), d);   // both internal bits take the DQ value
      cell_wr(r, col_odd(c),  d);
    end
  endtask

  // Testbench back doors (bypass all timing).
  task automatic poke(input logic [9:0] r, input logic [9:0] c, input logic [3:0] d);
    mem[addr_of(r, c)] = d;
  endtask
  function automatic logic [3:0] peek(input logic [9:0] r, input logic [9:0] c);
    peek = mem[addr_of(r, c)];
  endfunction

  //==========================================================================
  // Refresh bookkeeping
  //==========================================================================
  task automatic refresh_row(input logic [9:0] r);
    row_last_ref[r] = $realtime;
    row_decayed[r]  = 1'b0;
    n_ref++;
    init_refresh_seen = 1'b1;
    note($sformatf("refresh row %0d", r));
  endtask

  // Charge is gone for good: wipe the row.  row_decayed also suppresses
  // repeated reports until the controller refreshes the row again.
  task automatic decay_row(input logic [9:0] r);
    row_decayed[r] = 1'b1;
    if (DECAY_ENABLE)
      for (int c = 0; c < N_COLS; c++) mem[addr_of(r, c[9:0])] = 4'bxxxx;
  endtask

  task automatic check_row_age(input logic [9:0] r);
    if (REFRESH_CHECKS && (cyc != C_SELF) && !row_decayed[r] &&
        (($realtime - row_last_ref[r]) > (tREF + TOL))) begin
      viol($sformatf("row %0d not refreshed for %0.3f us (tREF max %0.3f us)",
                     r, ($realtime - row_last_ref[r])/1000.0, tREF/1000.0));
      decay_row(r);
    end
  endtask

  //==========================================================================
  // Read data path
  //
  // Enhanced page mode means an access can be launched by any of five paths.
  // The data is valid at the LATEST of them, which is what rd_ready_time()
  // computes.  Every edge that contributes re-arms the engine, so pushing a
  // deadline out (or starting a new column) is handled uniformly.
  //==========================================================================
  function automatic real acc_rac();  return test_mode ? tTRAC : tRAC;  endfunction
  function automatic real acc_aa();   return test_mode ? tTAA  : tAA;   endfunction
  function automatic real acc_cpa();  return test_mode ? tTCPA : tCPA;  endfunction

  function automatic realtime rd_ready_time();
    realtime t;
    t = $realtime;
    if (t_ras_fall        > NEVER && (t_ras_fall + acc_rac()) > t) t = t_ras_fall + acc_rac();
    if (t_cas_fall        > NEVER && (t_cas_fall + tCAC)      > t) t = t_cas_fall + tCAC;
    if (t_col_chg         > NEVER && (t_col_chg  + acc_aa())  > t) t = t_col_chg  + acc_aa();
    if (t_oe_fall         > NEVER && (t_oe_fall  + tOEA)      > t) t = t_oe_fall  + tOEA;
    if (page_access && t_cas_rise_in_ras > NEVER &&
        (t_cas_rise_in_ras + acc_cpa()) > t)                       t = t_cas_rise_in_ras + acc_cpa();
    return t;
  endfunction

  // Start / re-target an access.
  task automatic arm_read();
    rd_valid_at = rd_ready_time();
    rd_done     = 1'b0;
    rd_armed    = 1'b1;
  endtask

  // Data becomes invalid (new column, or the access is abandoned).
  task automatic disarm_read();
    rd_armed = 1'b0;
    dq_valid = 1'b0;
  endtask

  // The access engine.  Level-triggered so that re-arming from any process
  // is race-free, and the sleep loop re-reads rd_valid_at so a later
  // deadline simply extends the wait.
  always begin : rd_engine
    wait (rd_armed && !rd_done);
    while (rd_armed && !rd_done && $realtime < rd_valid_at)
      #(rd_valid_at - $realtime);
    if (rd_armed && !rd_done) begin
      dq_o     = read_word(row_q, col_q);
      dq_valid = 1'b1;
      n_rd++;
      note($sformatf("read  row %0d col %0d -> %h", row_q, col_q, dq_o));
    end
    rd_done = 1'b1;
    wait (!rd_done);
  end

  //==========================================================================
  // Output buffer (low-Z / high-Z) control.
  //
  // Per SMHS562C: RAS and CAS must both be brought low for the buffers to
  // leave high-Z, and "CAS or OE going high returns the output to a
  // high-impedance state".  RAS rising deliberately does NOT - that is
  // exactly what makes a hidden refresh able to hold data at the pins while
  // RAS is cycled underneath it.  An early write keeps the outputs off for
  // the entire cycle.
  //
  // out_armed is claimed at the CAS falling edge of a read and released by
  // CAS rising or by a write.  OE only gates; it never releases the claim,
  // so the page-mode pattern of toggling OE between column accesses works.
  //==========================================================================
  wire buf_req = out_armed && (!CAS_N) && (!OE_N);

  function automatic real buf_off_delay();
    // Whichever of CAS or OE went high most recently owns the disable time.
    if (t_oe_rise >= t_cas_rise) buf_off_delay = tOEZ;
    else                         buf_off_delay = tOFF;
  endfunction

  // tCLZ (min 0) - the buffers may leave high-Z as soon as they are claimed.
  always @(posedge buf_req) dq_oe = 1'b1;

  // Turn-off is level-driven and re-checked after the delay, so a buffer
  // that is re-enabled inside the disable window never glitches off.
  always begin : buf_off_proc
    wait (!buf_req && dq_oe);
    #(buf_off_delay());
    if (!buf_req) begin
      dq_oe    = 1'b0;
      dq_valid = 1'b0;
    end
  end

  //==========================================================================
  // Write data path
  //==========================================================================
  // The write strobe is the LATER of CAS falling and W falling (Note 12).
  task automatic do_write(input string kind);
    chk_min("tDS", t_dq_chg, tDS);
    if (^DQ === 1'bx)
      warn($sformatf("%s write of X data to row %0d col %0d", kind, row_q, col_q));
    write_word(row_q, col_q, DQ);
    t_wr_strobe    = $realtime;
    wrote_this_cas = 1'b1;
    n_wr++;
    disarm_read();
    note($sformatf("%s write row %0d col %0d <- %h", kind, row_q, col_q, DQ));
  endtask

  //==========================================================================
  // RAS falling edge - cycle decode
  //==========================================================================
  always @(negedge RAS_N) begin
    // ---- precharge / cycle-time checks
    chk_min("tRP",  t_ras_rise,      self_ref_exited ? tRPS : tRP);
    chk_min("tRC",  t_ras_fall, rmw_cycle ? tRWC : tRC);
    chk_min("tCRP", t_cas_rise,      tCRP);
    chk_min("tASR", t_addr_chg,      tASR);

    t_ras_fall        = $realtime;
    t_cas_rise_in_ras = NEVER;
    cas_seen_this_ras = 1'b0;
    page_access       = 1'b0;
    early_write       = 1'b0;
    wrote_this_cas    = 1'b0;
    read_this_cas     = 1'b0;
    rmw_cycle         = 1'b0;
    self_ref_exited   = 1'b0;
    init_cycles++;

    if (!CAS_N) begin
      //---------------------------------------------------------------------
      // CAS was already low: CBR family (CBR refresh, hidden refresh,
      // self refresh, or WCBR test-mode entry).
      //---------------------------------------------------------------------
      chk_min("tCSR", t_cas_fall, tCSR);
      t_ras_low_start_self = $realtime;

      if (!W_N) begin
        // WCBR - test mode entry
        chk_min("tWTS", t_w_fall, tWTS);
        cyc       = C_TEST_ENTRY;
        test_mode = 1'b1;
        refresh_row(cbr_cnt);
        cbr_cnt   = cbr_cnt + 1'b1;
        $display("%0t ps | %m | NOTE: entering TEST MODE (WCBR); part behaves as 512K x 8", $time);
      end else begin
        // Ordinary CBR / hidden / self refresh
        chk_min("tWSR", t_w_rise, tWSR);
        cyc = C_CBR;
        refresh_row(cbr_cnt);
        cbr_cnt = cbr_cnt + 1'b1;
        if (test_mode) begin
          test_mode = 1'b0;
          $display("%0t ps | %m | NOTE: leaving TEST MODE (CBR with W high)", $time);
        end
      end
      // A hidden refresh must not disturb data already at the outputs, so
      // the read engine is deliberately left alone here.
    end else begin
      //---------------------------------------------------------------------
      // Normal row activation (or the start of a RAS-only refresh).
      //---------------------------------------------------------------------
      cyc   = C_ROR;                 // promoted to C_ACTIVE when CAS falls
      row_q = A;
      col_t = A;                     // column buffers are transparent from here
      t_col_chg = $realtime;
      if (^row_q === 1'bx)
        warn("row address is X at RAS falling edge");
      check_row_age(row_q);
      refresh_row(row_q);
      disarm_read();
      if (POWERUP_CHECKS && !pwr_ready && (init_cycles > 8) && !init_refresh_seen)
        warn("first 8 initialisation cycles must include at least one refresh cycle");
    end
  end

  //==========================================================================
  // RAS rising edge
  //==========================================================================
  always @(posedge RAS_N) begin
    if (cyc == C_SELF) begin
      // Exiting self refresh.  tCHS is a hold of CAS low after RAS high and
      // is negative, i.e. CAS may rise up to 50 ns before RAS.
      if (TIMING_CHECKS && !CAS_N) begin
        // CAS still low: fine.
      end else if (TIMING_CHECKS && (t_cas_rise > NEVER) &&
                   (($realtime - t_cas_rise) > -tCHS + TOL))
        viol($sformatf("tCHS = %0.3f ns, minimum %0.3f ns",
                       t_cas_rise - $realtime, tCHS));
      // The on-chip oscillator kept everything alive.
      for (int r = 0; r < N_ROWS; r++) begin
        row_last_ref[r] = $realtime;
        row_decayed[r]  = 1'b0;
      end
      self_ref_exited = 1'b1;
      $display("%0t ps | %m | NOTE: exiting SELF REFRESH; a burst refresh of all 1024 rows is required before normal operation", $time);
    end else begin
      chk_min("tRAS", t_ras_fall, page_access ? tRASP_MIN : tRAS_MIN);
      chk_max("tRAS", t_ras_fall, page_access ? tRASP_MAX : tRAS_MAX);
      if (cas_seen_this_ras) begin
        chk_min("tRSH", t_cas_fall, tRSH);
        chk_min("tRAL", t_col_chg,  tRAL);
      end
      if (cyc == C_ROR) begin
        // RAS-only refresh: also exits test mode.
        if (test_mode) begin
          test_mode = 1'b0;
          $display("%0t ps | %m | NOTE: leaving TEST MODE (RAS-only refresh)", $time);
        end
      end
      if (wrote_this_cas)
        chk_min("tRWL", t_w_fall, tRWL);
      if (read_this_cas && !wrote_this_cas)
        chk_min("tROH", t_oe_fall, tROH);
    end

    t_ras_rise = $realtime;
    cyc        = C_IDLE;
    // Data-out is unlatched but survives RAS high while CAS and OE stay low.
  end

  //==========================================================================
  // Self-refresh entry detection: CBR with RAS held low for tRASS.
  //==========================================================================
  always begin : self_ref_watch
    // Poll while a CBR-style cycle is holding RAS low.  A single sleeping
    // timer would either leak one thread per refresh cycle or miss a self
    // refresh that began while it was asleep; polling does neither.
    wait (!RAS_N && !CAS_N && ((cyc == C_CBR) || (cyc == C_TEST_ENTRY)));
    if (($realtime - t_ras_fall) >= (tRASS_MIN - TOL)) begin
      cyc = C_SELF;
      if (!LOW_POWER)
        warn("self refresh entered, but this device has no self-refresh option (non-P part)");
      $display("%0t ps | %m | NOTE: entering SELF REFRESH", $time);
      wait (RAS_N);                 // stay put until the self refresh ends
    end else begin
      #(tRASS_MIN / 20.0);          // 5 us granularity, exact at tRASS
    end
  end

  //==========================================================================
  // CAS falling edge
  //==========================================================================
  always @(negedge CAS_N) begin
    chk_min("tCP",  t_cas_rise,      tCP);
    chk_min("tRPC", t_ras_rise,      tRPC);
    chk_min("tASC", t_addr_chg,      tASC);

    if (!RAS_N && cyc != C_CBR && cyc != C_SELF && cyc != C_TEST_ENTRY) begin
      // tRCD and tRAD describe the first column access of a RAS-low period;
      // later page-mode accesses are bounded by tPC / tCPA instead.
      if (!cas_seen_this_ras) begin
        chk_min("tRCD", t_ras_fall, tRCD_MIN);
        chk_max_acc("tRCD", t_ras_fall, tRCD_MAX);
        chk_min("tRAD", t_ras_fall, tRAD_MIN);
        chk_max_acc("tRAD", t_ras_fall, tRAD_MAX);
      end

      if (cas_seen_this_ras)
        chk_min("tPC", t_cas_fall, rmw_cycle ? tPRWC : tPC);

      t_cas_fall      = $realtime;
      cyc             = C_ACTIVE;
      cas_seen_this_ras = 1'b1;
      wrote_this_cas  = 1'b0;
      read_this_cas   = 1'b0;

      // CAS falling latches the column address that has been flowing through.
      col_q = col_t;
      if (^col_q === 1'bx)
        warn("column address is X at CAS falling edge");

      if (!W_N) begin
        //------------------- EARLY WRITE -------------------
        chk_min("tWCS", t_w_fall, tWCS);
        early_write = 1'b1;
        out_armed   = 1'b0;            // outputs stay high-Z for the whole cycle
        dq_oe       = 1'b0;
        disarm_read();
        do_write("early");
      end else begin
        //------------------- READ (may become read-modify-write) ------------
        chk_min("tRCS", t_w_rise, tRCS);
        early_write   = 1'b0;
        read_this_cas = 1'b1;
        out_armed     = 1'b1;          // claim the output buffers (tCLZ min 0)
        arm_read();
      end
    end else if (!RAS_N) begin
      // CAS falling during a refresh cycle - nothing to do.
      t_cas_fall      = $realtime;
    end else begin
      // CAS falling with RAS high: the setup phase of a CBR cycle.
      t_cas_fall      = $realtime;
    end
  end

  //==========================================================================
  // CAS rising edge
  //==========================================================================
  always @(posedge CAS_N) begin
    if (cas_seen_this_ras && (cyc == C_ACTIVE)) begin
      chk_min("tCAS", t_cas_fall, tCAS_MIN);
      chk_max("tCAS", t_cas_fall, tCAS_MAX);
      chk_min("tCSH", t_ras_fall, tCSH);
      chk_min("tCAL", t_col_chg,  tCAL);
      if (wrote_this_cas) chk_min("tCWL", t_w_fall, tCWL);
      if (read_this_cas && !wrote_this_cas) chk_min("tRCH", t_w_rise, tRCH);
    end
    if (cyc == C_CBR || cyc == C_TEST_ENTRY)
      chk_min("tCHR", t_ras_fall, tCHR);

    t_cas_rise = $realtime;
    if (!RAS_N) begin
      t_cas_rise_in_ras = $realtime;
      page_access       = 1'b1;
      // Column buffers become transparent again for the next page access,
      // but tAA/tRAL/tCAL still run from the last genuine address change.
      if (A !== col_t) begin
        col_t     = A;
        t_col_chg = $realtime;
      end
    end
    disarm_read();
    early_write = 1'b0;
    out_armed   = 1'b0;              // tOFF disable is handled by buf_off_proc
  end

  //==========================================================================
  // Write-enable edges
  //==========================================================================
  always @(negedge W_N) begin
    t_w_fall = $realtime;
    if (cyc == C_CBR)
      chk_min("tWHR", t_ras_fall, tWHR);   // W must stay high through a CBR
    if (!RAS_N && !CAS_N && (cyc == C_ACTIVE) && !wrote_this_cas) begin
      //------------------- LATE WRITE / READ-MODIFY-WRITE -------------------
      chk_min("tCWD", t_cas_fall, tCWD);
      chk_min("tRWD", t_ras_fall, tRWD);
      chk_min("tAWD", t_col_chg,  tAWD);
      rmw_cycle = read_this_cas;
      // OE must be off before data is applied (tOED) - the datasheet's
      // "bring OE high prior to applying data".
      if (!OE_N && dq_oe)
        warn("late write with OE still low: DQ bus contention (bring OE high first, see tOEZ/tOED)");
      out_armed = 1'b0;
      dq_oe     = 1'b0;
      do_write(rmw_cycle ? "read-modify-write" : "late");
    end
  end

  always @(posedge W_N) begin
    t_w_rise = $realtime;
    if (wrote_this_cas) chk_min("tWP", t_w_fall, tWP);
    if (!RAS_N && wrote_this_cas) begin
      chk_min("tWCH", t_cas_fall, tWCH);
      chk_min("tWCR", t_ras_fall, tWCR);
    end
    if (cyc == C_TEST_ENTRY)
      chk_min("tWTH", t_ras_fall, tWTH);   // W must stay low through WCBR entry
  end

  //==========================================================================
  // Output-enable edges
  //==========================================================================
  always @(negedge OE_N) begin
    t_oe_fall = $realtime;
    if (out_armed && !CAS_N) arm_read();   // access restarts from tOEA
  end

  always @(posedge OE_N) begin
    t_oe_rise = $realtime;
    chk_min("tOEH", t_oe_fall, tOEH);
    // buf_off_proc applies tOEZ.
  end

  //==========================================================================
  // Address monitor - transparent column latch and address hold checks
  //==========================================================================
  always @(A) begin
    // Row-address hold after RAS low.
    if (!RAS_N && (t_ras_fall > NEVER) && (($realtime - t_ras_fall) + TOL < tRAH) &&
        (cyc == C_ROR || cyc == C_ACTIVE))
      chk_min("tRAH", t_ras_fall, tRAH);

    // Column-address hold after CAS low / RAS low.
    if (!RAS_N && !CAS_N && cas_seen_this_ras && (cyc == C_ACTIVE)) begin
      chk_min("tCAH", t_cas_fall, tCAH);
      chk_min("tAR",  t_ras_fall, tAR);
    end

    t_addr_chg = $realtime;

    // Enhanced page mode: while RAS is low and CAS is high the column-address
    // buffers are transparent, so a new column starts an access immediately.
    if (!RAS_N && CAS_N && (cyc == C_ROR || cyc == C_ACTIVE)) begin
      if (($realtime - t_ras_fall) >= tRAH) begin
        col_t     = A;
        t_col_chg = $realtime;
        if (page_access && out_armed) arm_read();
      end
    end
  end

  //==========================================================================
  // DQ input monitor - data setup/hold around the write strobe
  //==========================================================================
  always @(DQ) begin
    if (TIMING_CHECKS && !dq_oe && wrote_this_cas && (t_wr_strobe > NEVER)) begin
      // tDH - data hold after the write strobe (later of CAS low / W low)
      if ((($realtime - t_wr_strobe) + TOL) < tDH)
        viol($sformatf("tDH = %0.3f ns, minimum %0.3f ns",
                       $realtime - t_wr_strobe, tDH));
      // tDHR - data hold referenced to RAS low
      if (!RAS_N && (t_ras_fall > NEVER) && ((($realtime - t_ras_fall) + TOL) < tDHR))
        viol($sformatf("tDHR = %0.3f ns, minimum %0.3f ns",
                       $realtime - t_ras_fall, tDHR));
    end
    t_dq_chg = $realtime;
  end

  //==========================================================================
  // Refresh interval surveillance
  //==========================================================================
  initial begin : refresh_scan
    if (REFRESH_CHECKS) begin
      forever begin
        #(tREF / 8.0);
        if (cyc != C_SELF)
          for (int r = 0; r < N_ROWS; r++)
            if (!row_decayed[r] && (($realtime - row_last_ref[r]) > tREF + TOL)) begin
              viol($sformatf("row %0d has not been refreshed for %0.3f ms (tREF %0.3f ms)",
                             r, ($realtime - row_last_ref[r])/1.0e6, tREF/1.0e6));
              decay_row(r[9:0]);
            end
      end
    end
  end

  //==========================================================================
  // Power-up sequence: 200 us pause then >= 8 initialisation cycles
  //==========================================================================
  initial begin : powerup
    pwr_ready = 1'b0;
    #200000;                       // 200 us
    wait (init_cycles >= 8);
    pwr_ready = 1'b1;
    note("power-up initialisation complete");
  end

  //==========================================================================
  // Reset / banner
  //==========================================================================
  initial begin
    cyc               = C_IDLE;
    row_q             = '0;
    col_t             = '0;
    col_q             = '0;
    cbr_cnt           = '0;
    test_mode         = 1'b0;
    cas_seen_this_ras = 1'b0;
    page_access       = 1'b0;
    early_write       = 1'b0;
    wrote_this_cas    = 1'b0;
    read_this_cas     = 1'b0;
    rmw_cycle         = 1'b0;
    self_ref_exited   = 1'b0;
    init_cycles       = 0;
    init_refresh_seen = 1'b0;
    n_viol = 0; n_warn = 0; n_rd = 0; n_wr = 0; n_ref = 0;

    rd_armed  = 1'b0;
    rd_done   = 1'b1;
    dq_oe     = 1'b0;
    dq_valid  = 1'b0;
    out_armed = 1'b0;
    dq_o      = 4'bxxxx;

    t_ras_fall = NEVER; t_ras_rise = NEVER;
    t_cas_fall = NEVER; t_cas_rise = NEVER;
    t_cas_rise_in_ras = NEVER;
    t_w_fall = NEVER; t_w_rise = NEVER;
    t_oe_fall = NEVER; t_oe_rise = NEVER;
    t_addr_chg = NEVER; t_col_chg = NEVER; t_dq_chg = NEVER;
    t_wr_strobe = NEVER; t_ras_low_start_self = NEVER;

    for (int r = 0; r < N_ROWS; r++) begin
      row_last_ref[r] = 0.0;
      row_decayed[r]  = 1'b0;
    end

    $display("%0t ps | %m | %s behavioural model: 1M x 4, tRAC=%0.0fns tCAC=%0.0fns tRC=%0.0fns tREF=%0.0fms",
             $time, dev_name(), tRAC, tCAC, tRC, tREF/1.0e6);
  end

  //==========================================================================
  // End-of-simulation summary
  //==========================================================================
  final begin
    $display("---- %s: %0d reads, %0d writes, %0d refreshes, %0d violations, %0d warnings",
             dev_name(), n_rd, n_wr, n_ref, n_viol, n_warn);
  end

endmodule
