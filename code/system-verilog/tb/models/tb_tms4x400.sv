//============================================================================
//  tb_tms4x400.sv - self-checking testbench for the TMS4x400 model.
//
//  Every stimulus sequence below is hand-timed against the -60 columns of
//  SMHS562C so that a passing run means two things at once: the data path is
//  right, and the model's own timing checkers stay silent on legal traffic.
//  The last section then deliberately breaks five parameters to prove the
//  checkers actually fire.
//============================================================================
`timescale 1ns / 1ps

module tb_tms4x400;

  // -------------------------------------------------------------- signals
  logic [9:0] A;
  logic       RAS_N, CAS_N, W_N, OE_N;
  logic [3:0] dq_drv;
  logic       dq_en;
  wire  [3:0] DQ = dq_en ? dq_drv : 4'bzzzz;

  int errors;
  int viol_mark, exp_mark;

  tms4x400 #(
    .SPEED            (60),
    .LOW_POWER        (1),     // TMS44400P: self refresh available
    .TIMING_CHECKS    (1),
    .CHECK_ACCESS_MAX (1),
    .REFRESH_CHECKS   (1),
    .POWERUP_CHECKS   (1),
    .VERBOSE          (0)
  ) dut (
    .A(A), .RAS_N(RAS_N), .CAS_N(CAS_N), .W_N(W_N), .OE_N(OE_N), .DQ(DQ)
  );

  // ------------------------------------------------------------- checkers
  task automatic check(input string what, input logic [3:0] got, input logic [3:0] exp);
    if (got !== exp) begin
      errors++;
      $display("  FAIL  %-46s got %b expected %b", what, got, exp);
    end else
      $display("  pass  %-46s %b", what, got);
  endtask

  task automatic check_true(input string what, input bit cond);
    if (!cond) begin
      errors++;
      $display("  FAIL  %s", what);
    end else
      $display("  pass  %s", what);
  endtask

  task automatic mark();
    viol_mark = dut.n_viol;
    exp_mark  = dut.n_viol_expected;
  endtask

  // Section 10 provokes violations on purpose.  Announcing that to the model
  // keeps them out of the printed log (and out of any CI grep for the word
  // "violation") while still counting them and still setting watch_hit.
  task automatic expect_failures(input bit on);
    dut.viol_quiet = on;
  endtask
  task automatic expect_clean(input string what);
    if (dut.n_viol != viol_mark) begin
      errors++;
      $display("  FAIL  %-46s %0d unexpected timing violation(s)",
               what, dut.n_viol - viol_mark);
    end else
      $display("  pass  %-46s timing clean", what);
  endtask
  task automatic expect_viol(input string what);
    if (dut.n_viol_expected == exp_mark) begin
      errors++;
      $display("  FAIL  %-46s checker did NOT fire", what);
    end else
      $display("  pass  %-46s checker fired (%0d)", what,
               dut.n_viol_expected - exp_mark);
  endtask

  // ================================================================ cycles
  // All delays below are the -60 numbers; see SMHS562C pp.9-10.

  // Random read cycle, Figure 4 ordering (RAS rises before CAS).
  task automatic rd_cycle(input logic [9:0] row, input logic [9:0] col,
                          output logic [3:0] d);
    A = row;  #2;
    RAS_N = 1'b0;                       // T+0
    #18; A = col;                       // T+18  tRAH=18, tRAD=18 (15..30)
    #7;  CAS_N = 1'b0; OE_N = 1'b0;     // T+25  tRCD=25 (20..45), tASC=7
    #45; d = DQ;                        // T+70  clears tRAC=60 and tTRAC=65
    #7;  RAS_N = 1'b1;                  // T+77  tRAS=77, tRSH=52, tRAL=59
    #4;  CAS_N = 1'b1; OE_N = 1'b1;     // T+81  tCAS=56, tCSH=81, tCAL=63
    #45;                                // T+126 tRP=49, tRC=128
  endtask

  // Early-write cycle, Figure 5 (W low before CAS falls; DQ stays high-Z).
  task automatic wr_cycle(input logic [9:0] row, input logic [9:0] col,
                          input logic [3:0] d);
    A = row;  #2;
    RAS_N = 1'b0;                       // T+0
    #18; A = col; W_N = 1'b0;
         dq_drv = d; dq_en = 1'b1;      // T+18  tWCS=7
    #7;  CAS_N = 1'b0;                  // T+25  write strobe
    #47; RAS_N = 1'b1;                  // T+72  tRAS=72, tRWL=54
    #4;  CAS_N = 1'b1; W_N = 1'b1;
         dq_en = 1'b0;                  // T+76  tWCH=51 tWCR=76 tCWL=58 tDH=51 tDHR=76
    #45;
  endtask

  // Read-modify-write, Figure 7 (read first, then W falls late).
  task automatic rmw_cycle(input logic [9:0] row, input logic [9:0] col,
                           input logic [3:0] wd, output logic [3:0] rd);
    A = row;  #2;
    RAS_N = 1'b0;                       // T+0
    #18; A = col;                       // T+18
    #7;  CAS_N = 1'b0; OE_N = 1'b0;     // T+25
    #55; rd = DQ;                       // T+80  read data (tRAC=60)
    #2;  OE_N = 1'b1;                   // T+82  free the bus before driving
    #16; dq_drv = wd; dq_en = 1'b1;     // T+98  tOED=16
    #4;  W_N = 1'b0;                    // T+102 tRWD=102 tCWD=77 tAWD=84
    #20; RAS_N = 1'b1;                  // T+122 tRWL=20, tRAS=122
    #4;  CAS_N = 1'b1; W_N = 1'b1;
         dq_en = 1'b0;                  // T+126 tCWL=24 tWP=24 tDH=24 tDHR=126
    #50;                                // tRWC = 178 (min 155)
  endtask

  // RAS-only refresh, Figure 11.
  task automatic ras_only_refresh(input logic [9:0] row);
    A = row;  #2;
    RAS_N = 1'b0;
    #70; RAS_N = 1'b1;                  // tRAS=70
    #45;                                // tRP=45, tRC=117
  endtask

  // CAS-before-RAS refresh, Figure 12.
  task automatic cbr_refresh();
    CAS_N = 1'b0;
    #10; RAS_N = 1'b0;                  // tCSR=10 (min 5)
    #70; RAS_N = 1'b1;                  // tRAS=70
    #10; CAS_N = 1'b1;                  // tCHR=80 (min 10)
    #45;
  endtask

  // ============================================================= stimulus
  logic [3:0] d, d2, d3;
  int i;
  int         ref0;
  logic [9:0] cbr0;

  initial begin
    errors = 0;
    A = '0; RAS_N = 1'b1; CAS_N = 1'b1; W_N = 1'b1; OE_N = 1'b1;
    dq_drv = 4'h0; dq_en = 1'b0;

    //--------------------------------------------------------------------
    $display("\n=== 1. Power-up: 200 us pause then 8 initialisation cycles ===");
    #200000;
    for (i = 0; i < 8; i++) ras_only_refresh(i[9:0]);
    check_true("power-up sequence accepted", dut.pwr_ready === 1'b1);

    //--------------------------------------------------------------------
    $display("\n=== 2. Early write / read back ===");
    mark();
    wr_cycle(10'h123, 10'h0AB, 4'b1010);
    wr_cycle(10'h123, 10'h0AC, 4'b0101);
    wr_cycle(10'h1FF, 10'h3FF, 4'b1111);
    rd_cycle(10'h123, 10'h0AB, d);  check("read row 123 col 0AB", d, 4'b1010);
    rd_cycle(10'h123, 10'h0AC, d);  check("read row 123 col 0AC", d, 4'b0101);
    rd_cycle(10'h1FF, 10'h3FF, d);  check("read row 1FF col 3FF", d, 4'b1111);
    expect_clean("legal read/write traffic");

    $display("  -- an untouched cell must read X (DRAM powers up unknown)");
    rd_cycle(10'h004, 10'h004, d);  check("untouched cell reads X", d, 4'bxxxx);

    //--------------------------------------------------------------------
    $display("\n=== 3. Access time: data must appear at tRAC, not before ===");
    mark();
    A = 10'h123; #2;
    RAS_N = 1'b0;
    #18; A = 10'h0AB;
    #7;  CAS_N = 1'b0; OE_N = 1'b0;             // T+25
    #33; check_true("DQ still invalid at RAS+58 (tRAC=60)", DQ !== 4'b1010);
    #4;  check("DQ valid at RAS+62", DQ, 4'b1010);
    #6;  RAS_N = 1'b1;
    #4;  CAS_N = 1'b1; OE_N = 1'b1;
    #45;
    expect_clean("tRAC observation cycle");

    //--------------------------------------------------------------------
    $display("\n=== 4. Read-modify-write ===");
    mark();
    rmw_cycle(10'h123, 10'h0AB, 4'b0011, d);
    check("R-M-W returned the OLD data", d, 4'b1010);
    rd_cycle(10'h123, 10'h0AB, d2);
    check("R-M-W stored the NEW data",   d2, 4'b0011);
    expect_clean("read-modify-write cycle");

    //--------------------------------------------------------------------
    $display("\n=== 5. Enhanced page mode ===");
    mark();
    // ---- page write burst: one row activation, four columns
    A = 10'h200; #2;
    RAS_N = 1'b0;                                  // T+0
    #18;
    for (i = 0; i < 4; i++) begin
      A = 10'h100 + i[9:0];
      W_N = 1'b0; dq_drv = 4'b0001 << i[1:0]; dq_en = 1'b1;
      #7;  CAS_N = 1'b0;                           // strobe (tRCD=25 on i=0)
      #40; CAS_N = 1'b1;                           // tCAS=40, tCWL=47, tCSH=65
      #10; W_N = 1'b1; dq_en = 1'b0;               // tWCH=50, tDH=50, tDHR=75
      #23;                                         // tCP=33 ; tPC=80
    end
    RAS_N = 1'b1;
    #50;
    // ---- page read burst with an access-time observation on column 1
    A = 10'h200; #2;
    RAS_N = 1'b0;                                  // T+0
    #18; A = 10'h100;                              // T+18
    #7;  CAS_N = 1'b0; OE_N = 1'b0;                // T+25
    #45; check("page col 0", DQ, 4'b0001);         // T+70 (tRAC=60)
    #5;  CAS_N = 1'b1; OE_N = 1'b1;                // T+75
    #15; A = 10'h101;                              // T+90  transparent latch
    #5;  CAS_N = 1'b0; OE_N = 1'b0;                // T+95  tCP=20 tPC=70
    // access = max(tCPA 75+35, tAA 90+30, tCAC 95+15) = 120
    #23; check_true("page col 1 invalid at +118 (tAA=30 from A)", DQ !== 4'b0010);
    #4;  check("page col 1 valid at +122", DQ, 4'b0010);
    #4;  CAS_N = 1'b1; OE_N = 1'b1;                // T+126 tCAL=36 tCAS=31
    #4;  RAS_N = 1'b1;                             // T+130 tRAL=40 tRSH=35
    #50;
    rd_cycle(10'h200, 10'h102, d);  check("page col 2 retained", d, 4'b0100);
    rd_cycle(10'h200, 10'h103, d);  check("page col 3 retained", d, 4'b1000);
    expect_clean("enhanced page mode traffic");

    //--------------------------------------------------------------------
    $display("\n=== 6. Refresh: RAS-only and CAS-before-RAS ===");
    mark();
    ref0 = dut.n_ref;
    cbr0 = dut.cbr_cnt;
    for (i = 0; i < 4; i++) ras_only_refresh(10'h300 + i[9:0]);
    for (i = 0; i < 4; i++) cbr_refresh();
    check_true("8 refresh cycles counted",  dut.n_ref   == ref0 + 8);
    check_true("CBR counter advanced by 4", dut.cbr_cnt == cbr0 + 10'd4);
    expect_clean("refresh traffic");

    //--------------------------------------------------------------------
    $display("\n=== 7. Hidden refresh: data must survive RAS cycling ===");
    mark();
    A = 10'h123; #2;
    RAS_N = 1'b0;
    #18; A = 10'h0AC;
    #7;  CAS_N = 1'b0; OE_N = 1'b0;                // T+25
    #45; check("hidden-refresh read data", DQ, 4'b0101);
    #2;  RAS_N = 1'b1;                             // T+72 CAS stays LOW
    #50; RAS_N = 1'b0;                             // T+122 CBR (hidden) refresh
    #70; check("data still driven mid-refresh", DQ, 4'b0101);
         RAS_N = 1'b1;                             // T+192
    #10; check("data still driven after refresh", DQ, 4'b0101);
         CAS_N = 1'b1; OE_N = 1'b1;                // T+202
    #25; check_true("outputs high-Z after CAS rises", DQ === 4'bzzzz);
    #45;
    expect_clean("hidden refresh");

    //--------------------------------------------------------------------
    $display("\n=== 8. Self refresh (P device) ===");
    mark();
    CAS_N = 1'b0;
    #10; RAS_N = 1'b0;                             // CBR entry
    #150000;                                       // hold > tRASS (100 us)
    check_true("model entered self refresh", dut.cyc === dut.C_SELF);
    RAS_N = 1'b1;
    #10; CAS_N = 1'b1;                             // tCHS: CAS may lag RAS
    #120;                                          // tRPS = 110 min
    rd_cycle(10'h123, 10'h0AB, d);
    check("data survived self refresh", d, 4'b0011);
    expect_clean("self refresh entry/exit");

    //--------------------------------------------------------------------
    $display("\n=== 9. WCBR test mode (512K x 8, 2-bit compare per DQ) ===");
    mark();
    // entry: CAS low, then W low, then RAS low
    CAS_N = 1'b0;
    #5;  W_N  = 1'b0;                              // tWTS = 15
    #15; RAS_N = 1'b0;                             // tCSR = 20
    #12; W_N  = 1'b1;                              // tWTH = 12
    #58; RAS_N = 1'b1;                             // tRAS = 70
    #10; CAS_N = 1'b1;                             // tCHR = 80
    #45;
    check_true("test mode entered", dut.test_mode === 1'b1);

    // a test-mode write puts the same value in both internal bits
    wr_cycle(10'h050, 10'h0A4, 4'b1010);
    rd_cycle(10'h050, 10'h0A4, d);
    check("matching bit pairs read all-ones", d, 4'b1111);

    // force one internal bit of the pair to differ -> that DQ reports 0
    dut.poke(10'h050, 10'h0A5, 4'b1000);           // bit1 now differs
    rd_cycle(10'h050, 10'h0A4, d);
    check("mismatched pair pulls its DQ low", d, 4'b1101);

    // exit via a CBR refresh with W high
    cbr_refresh();
    check_true("test mode exited", dut.test_mode === 1'b0);
    expect_clean("test-mode entry, access and exit");

    //--------------------------------------------------------------------
    $display("\n=== 10. Negative tests: the checkers must fire ===");
    $display("  (reported quietly - these are expected, not defects)");
    expect_failures(1);

    $display("  -- tRP (precharge too short)");
    mark();
    A = 10'h001; #2; RAS_N = 1'b0; #70; RAS_N = 1'b1;
    #15;                                            // only 15 ns, tRP min 40
    A = 10'h002; RAS_N = 1'b0; #70; RAS_N = 1'b1; #60;
    expect_viol("tRP");

    $display("  -- tRCD (CAS falls too soon after RAS)");
    mark();
    A = 10'h003; #2; RAS_N = 1'b0;
    #12; A = 10'h004;                               // also short of tRAD min 15
    #2;  CAS_N = 1'b0; OE_N = 1'b0;                 // tRCD = 14, min 20
    #60; RAS_N = 1'b1; #4; CAS_N = 1'b1; OE_N = 1'b1; #60;
    expect_viol("tRCD");

    $display("  -- tRAS (RAS low pulse too short)");
    mark();
    A = 10'h005; #2; RAS_N = 1'b0;
    #40; RAS_N = 1'b1;                              // 40 ns, min 60
    #80;
    expect_viol("tRAS");

    $display("  -- tRAH (row address released too early)");
    mark();
    A = 10'h006; #2; RAS_N = 1'b0;
    #4;  A = 10'h007;                               // 4 ns, tRAH min 10
    #20; CAS_N = 1'b0; OE_N = 1'b0;
    #60; RAS_N = 1'b1; #4; CAS_N = 1'b1; OE_N = 1'b1; #60;
    expect_viol("tRAH");

    $display("  -- tCP (CAS high pulse too short in page mode)");
    mark();
    A = 10'h008; #2; RAS_N = 1'b0;
    #18; A = 10'h009;
    #7;  CAS_N = 1'b0; OE_N = 1'b0;
    #45; CAS_N = 1'b1;
    #4;  CAS_N = 1'b0;                              // 4 ns high, tCP min 10
    #45; CAS_N = 1'b1; OE_N = 1'b1;
    #4;  RAS_N = 1'b1;
    #60;
    expect_viol("tCP");

    expect_failures(0);

    //--------------------------------------------------------------------
    $display("\n=== 11. Control: legal traffic after the negative tests ===");
    mark();
    wr_cycle(10'h0AA, 10'h055, 4'b1100);
    rd_cycle(10'h0AA, 10'h055, d);
    check("write/read after negative tests", d, 4'b1100);
    expect_clean("control cycle");

    //--------------------------------------------------------------------
    $display("\n============================================================");
    if (errors == 0) begin
      $display("  PASS  tms4x400 - all checks good, %0d expected timing faults",
               dut.n_viol_expected);
      $display("============================================================\n");
      $finish;
    end else begin
      $display("  FAIL  tms4x400 - %0d check(s) did not pass", errors);
      $display("============================================================\n");
      $fatal(1, "tms4x400 testbench failed");
    end
  end

  initial begin
    #2000000;
    $display("TIMEOUT");
    $finish;
  end

endmodule