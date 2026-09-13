`timescale 1ns / 1ps

module tms4x400 #(
    parameter int SPEED             = 60,
    parameter bit LOW_POWER         = 1'b0,
    parameter bit LVOLT             = 1'b0,

    parameter bit TIMING_CHECKS     = 1'b1,
    parameter bit CHECK_ACCESS_MAX  = 1'b0,
    parameter bit REFRESH_CHECKS    = 1'b1,
    parameter bit DECAY_ENABLE      = 1'b0,
    parameter bit POWERUP_CHECKS    = 1'b1,
    parameter bit STOP_ON_VIOLATION = 1'b0,
    parameter bit VERBOSE           = 1'b0
) (
    input  wire [9:0] A,
    input  wire       RAS_N,
    input  wire       CAS_N,
    input  wire       W_N,
    input  wire       OE_N,
    inout  wire [3:0] DQ
);

    localparam int SG = (SPEED <= 60) ? 0 : (SPEED <= 70) ? 1 : 2;

    localparam real tAA   = (SG == 0) ?  30.0 : (SG == 1) ?  35.0 :  40.0;
    localparam real tCAC  = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tCPA  = (SG == 0) ?  35.0 : (SG == 1) ?  40.0 :  45.0;
    localparam real tRAC  = (SG == 0) ?  60.0 : (SG == 1) ?  70.0 :  80.0;
    localparam real tOEA  = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tCLZ  =   0.0;
    localparam real tOFF  = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tOEZ  = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;

    localparam real tTAA  = (SG == 0) ?  35.0 : (SG == 1) ?  40.0 :  45.0;
    localparam real tTCPA = (SG == 0) ?  40.0 : (SG == 1) ?  45.0 :  50.0;
    localparam real tTRAC = (SG == 0) ?  65.0 : (SG == 1) ?  75.0 :  85.0;

    localparam real tRC   = (SG == 0) ? 110.0 : (SG == 1) ? 130.0 : 150.0;
    localparam real tRWC  = (SG == 0) ? 155.0 : (SG == 1) ? 181.0 : 205.0;
    localparam real tPC   = (SG == 0) ?  40.0 : (SG == 1) ?  45.0 :  50.0;
    localparam real tPRWC = (SG == 0) ?  85.0 : (SG == 1) ?  96.0 : 105.0;

    localparam real tRASP_MIN = (SG == 0) ?  60.0 : (SG == 1) ?  70.0 :  80.0;
    localparam real tRASP_MAX = 100000.0;
    localparam real tRAS_MIN  = (SG == 0) ?  60.0 : (SG == 1) ?  70.0 :  80.0;
    localparam real tRAS_MAX  =  10000.0;
    localparam real tRASS_MIN = 100000.0;

    localparam real tCAS_MIN  = (SG == 0) ?  10.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tCAS_MAX  =  10000.0;
    localparam real tCP       =  10.0;
    localparam real tRP       = (SG == 0) ?  40.0 : (SG == 1) ?  50.0 :  60.0;
    localparam real tRPS      = (SG == 0) ? 110.0 : (SG == 1) ? 130.0 : 150.0;
    localparam real tWP       =  10.0;

    localparam real tASC =   0.0;
    localparam real tASR =   0.0;
    localparam real tDS  =   0.0;
    localparam real tRCS =   0.0;
    localparam real tCWL = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tRWL = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tWCS =   0.0;
    localparam real tWSR =  10.0;
    localparam real tWTS =  10.0;

    localparam real tCAH = (SG == 0) ?  10.0 : (SG == 1) ?  15.0 :  15.0;
    localparam real tDHR = (SG == 0) ?  50.0 : (SG == 1) ?  55.0 :  60.0;
    localparam real tDH  = (SG == 0) ?  10.0 : (SG == 1) ?  15.0 :  15.0;
    localparam real tAR  = (SG == 0) ?  50.0 : (SG == 1) ?  55.0 :  60.0;
    localparam real tRAH =  10.0;
    localparam real tRCH =   0.0;
    localparam real tRRH =   0.0;
    localparam real tWCH = (SG == 0) ?  10.0 : (SG == 1) ?  15.0 :  15.0;
    localparam real tWCR = (SG == 0) ?  50.0 : (SG == 1) ?  55.0 :  60.0;
    localparam real tWHR =  10.0;
    localparam real tWTH =  10.0;
    localparam real tCHS = -50.0;
    localparam real tOEH = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tOED = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tROH =  10.0;

    localparam real tAWD     = (SG == 0) ?  55.0 : (SG == 1) ?  63.0 :  70.0;
    localparam real tCHR     =  10.0;
    localparam real tCRP     =   0.0;
    localparam real tCSH     = (SG == 0) ?  60.0 : (SG == 1) ?  70.0 :  80.0;
    localparam real tCSR     =   5.0;
    localparam real tCWD     = (SG == 0) ?  40.0 : (SG == 1) ?  46.0 :  50.0;
    localparam real tRAD_MIN =  15.0;
    localparam real tRAD_MAX = (SG == 0) ?  30.0 : (SG == 1) ?  35.0 :  40.0;
    localparam real tRAL     = (SG == 0) ?  30.0 : (SG == 1) ?  35.0 :  40.0;
    localparam real tCAL     = (SG == 0) ?  30.0 : (SG == 1) ?  35.0 :  40.0;
    localparam real tRCD_MIN =  20.0;
    localparam real tRCD_MAX = (SG == 0) ?  45.0 : (SG == 1) ?  52.0 :  60.0;
    localparam real tRPC     =   0.0;
    localparam real tRSH     = (SG == 0) ?  15.0 : (SG == 1) ?  18.0 :  20.0;
    localparam real tRWD     = (SG == 0) ?  85.0 : (SG == 1) ?  98.0 : 110.0;

    localparam real tREF     = LOW_POWER ? 128000000.0 : 16000000.0;

    /* verilator lint_off UNUSEDPARAM */
    localparam real tT_MIN   =   2.0;
    localparam real tT_MAX   =  30.0;
    /* verilator lint_on UNUSEDPARAM */

    localparam int  N_ROWS   = 1024;
    localparam int  N_COLS   = 1024;

    localparam real NEVER    = -1.0e12;

    localparam real TOL      =  0.0005;

    logic [3:0] mem [0:(N_ROWS*N_COLS)-1];
    realtime    row_last_ref [0:N_ROWS-1];
    bit         row_decayed  [0:N_ROWS-1];

    typedef enum int {
        C_IDLE,
        C_ACTIVE,
        C_ROR,
        C_CBR,
        C_SELF,
        C_TEST_ENTRY
    } cyc_e;

    cyc_e       cyc;
    logic [9:0] row_q;
    logic [9:0] col_t;
    logic [9:0] col_q;
    logic [9:0] cbr_cnt;
    bit         test_mode;
    bit         cas_seen_this_ras;
    bit         col_moved;
    bit         page_access;
    bit         wrote_this_cas;
    bit         read_this_cas;
    bit         rmw_cycle;
    bit         self_ref_exited;

    int unsigned init_cycles;
    bit          pwr_ready;
    bit          init_refresh_seen;

    int unsigned n_viol;
    int unsigned n_viol_expected;
    int unsigned n_warn;

    bit          viol_quiet;
    /* verilator lint_off UNUSEDSIGNAL */
    string       last_viol;
    /* verilator lint_on UNUSEDSIGNAL */
    int unsigned n_rd, n_wr, n_ref;

    realtime t_ras_fall, t_ras_rise;
    realtime t_cas_fall, t_cas_rise, t_cas_rise_in_ras;
    realtime t_w_fall,   t_w_rise;
    realtime t_oe_fall,  t_oe_rise;
    realtime t_addr_chg;
    realtime t_col_chg;
    realtime t_dq_chg;
    realtime t_wr_strobe;

    bit         rd_armed;
    bit         rd_done;
    realtime    rd_valid_at;
    logic [3:0] dq_o;
    bit         dq_valid;
    bit         dq_oe;
    bit         out_armed;

    assign DQ = dq_oe ? (dq_valid ? dq_o : 4'bxxxx) : 4'bzzzz;

    function automatic string dev_name();
        return $sformatf("TMS%s400%s-%0d", LVOLT ? "46" : "44",
            LOW_POWER ? "P" : "", SPEED);
    endfunction

    /* verilator lint_off UNUSEDSIGNAL */
    string watch_param;
    bit    watch_hit;
    /* verilator lint_on UNUSEDSIGNAL */

    task automatic viol(input string pname, input string msg);
        last_viol = pname;
        if (pname == watch_param) watch_hit = 1'b1;
        if (viol_quiet) begin
            n_viol_expected++;
            if (VERBOSE) $display("%0t ps | %m | (expected) %s", $time, msg);
        end else begin
            n_viol++;
            $display("%0t ps | %m | TIMING VIOLATION: %s", $time, msg);
            if (STOP_ON_VIOLATION) $stop;
        end
    endtask

    task automatic warn(input string msg);
        n_warn++;
        if (!viol_quiet) $display("%0t ps | %m | WARNING: %s", $time, msg);
    endtask

    task automatic note(input string msg);
        if (VERBOSE) $display("%0t ps | %m | %s", $time, msg);
    endtask

    task automatic chk_min(input string nm, input realtime t0, input real lim);
        if (TIMING_CHECKS && (t0 > NEVER) && ((($realtime - t0) + TOL) < lim))
            viol(nm, $sformatf("%s = %0.3f ns, minimum %0.3f ns", nm, $realtime - t0, lim));
    endtask

    task automatic chk_span_min(input string nm, input realtime t0,
        input realtime t1, input real lim);
        if (TIMING_CHECKS && (t0 > NEVER) && (t1 > NEVER) && (((t1 - t0) + TOL) < lim))
            viol(nm, $sformatf("%s = %0.3f ns, minimum %0.3f ns", nm, t1 - t0, lim));
    endtask

    task automatic chk_span_max_acc(input string nm, input realtime t0,
        input realtime t1, input real lim);
        if (TIMING_CHECKS && CHECK_ACCESS_MAX && (t0 > NEVER) && (t1 > NEVER) &&
            ((t1 - t0) > (lim + TOL)))
            warn($sformatf("%s = %0.3f ns exceeds the %0.3f ns maximum; access is no longer tRAC-limited",
                nm, t1 - t0, lim));
    endtask

    task automatic chk_max_acc(input string nm, input realtime t0, input real lim);
        if (TIMING_CHECKS && CHECK_ACCESS_MAX && (t0 > NEVER) &&
            (($realtime - t0) > (lim + TOL)))
            warn($sformatf("%s = %0.3f ns exceeds the %0.3f ns maximum; access is no longer tRAC-limited",
                nm, $realtime - t0, lim));
    endtask

    task automatic chk_max(input string nm, input realtime t0, input real lim);
        if (TIMING_CHECKS && (t0 > NEVER) && (($realtime - t0) > (lim + TOL)))
            viol(nm, $sformatf("%s = %0.3f ns, maximum %0.3f ns", nm, $realtime - t0, lim));
    endtask

    function automatic int addr_of(input logic [9:0] r, input logic [9:0] c);
        return int'({r, c});
    endfunction

    function automatic logic [3:0] cell_rd(input logic [9:0] r, input logic [9:0] c);
        cell_rd = mem[addr_of(r, c)];
    endfunction

    task automatic cell_wr(input logic [9:0] r, input logic [9:0] c, input logic [3:0] d);
        mem[addr_of(r, c)] = d;
    endtask

    /* verilator lint_off UNUSEDSIGNAL */
    function automatic logic [9:0] col_even(input logic [9:0] c);
        return {c[9:1], 1'b0};
    endfunction
    function automatic logic [9:0] col_odd(input logic [9:0] c);
        return {c[9:1], 1'b1};
    endfunction
    /* verilator lint_on UNUSEDSIGNAL */

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
            cell_wr(r, col_even(c), d);
            cell_wr(r, col_odd(c),  d);
        end
    endtask

    task automatic poke(input logic [9:0] r, input logic [9:0] c, input logic [3:0] d);
        mem[addr_of(r, c)] = d;
    endtask
    function automatic logic [3:0] peek(input logic [9:0] r, input logic [9:0] c);
        peek = mem[addr_of(r, c)];
    endfunction

    task automatic refresh_row(input logic [9:0] r);
        row_last_ref[r] = $realtime;
        row_decayed[r]  = 1'b0;
        n_ref++;
        init_refresh_seen = 1'b1;
        note($sformatf("refresh row %0d", r));
    endtask

    task automatic decay_row(input logic [9:0] r);
        row_decayed[r] = 1'b1;
        if (DECAY_ENABLE)
            for (int c = 0; c < N_COLS; c++) mem[addr_of(r, c[9:0])] = 4'bxxxx;
    endtask

    task automatic check_row_age(input logic [9:0] r);
        if (REFRESH_CHECKS && (cyc != C_SELF) && !row_decayed[r] &&
            (($realtime - row_last_ref[r]) > (tREF + TOL))) begin
            viol("tREF", $sformatf("row %0d not refreshed for %0.3f us (tREF max %0.3f us)",
                r, ($realtime - row_last_ref[r])/1000.0, tREF/1000.0));
            decay_row(r);
        end
    endtask

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

    task automatic arm_read();
        rd_valid_at = rd_ready_time();
        rd_done     = 1'b0;
        rd_armed    = 1'b1;
    endtask

    task automatic disarm_read();
        rd_armed = 1'b0;
        dq_valid = 1'b0;
    endtask

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

    wire buf_req = out_armed && (!CAS_N) && (!OE_N);

    function automatic real buf_off_delay();

        if (t_oe_rise >= t_cas_rise) buf_off_delay = tOEZ;
        else                         buf_off_delay = tOFF;
    endfunction

    always begin : buf_on_proc
        wait (buf_req && !dq_oe);
        if (tCLZ > 0.0) #(tCLZ);
        if (buf_req) dq_oe = 1'b1;
    end

    always begin : buf_off_proc
        wait (!buf_req && dq_oe);
        #(buf_off_delay());
        if (!buf_req) begin
            dq_oe    = 1'b0;
            dq_valid = 1'b0;
        end
    end

    task automatic do_write(input string kind);
        chk_min("tDS", t_dq_chg, tDS);

        chk_span_min("tOED", t_oe_rise, t_dq_chg, tOED);
        if (^DQ === 1'bx)
            warn($sformatf("%s write of X data to row %0d col %0d", kind, row_q, col_q));
        write_word(row_q, col_q, DQ);
        t_wr_strobe    = $realtime;
        wrote_this_cas = 1'b1;
        n_wr++;
        disarm_read();
        note($sformatf("%s write row %0d col %0d <- %h", kind, row_q, col_q, DQ));
    endtask

    always @(negedge RAS_N) begin
        chk_min(self_ref_exited ? "tRPS" : "tRP", t_ras_rise,
            self_ref_exited ? tRPS  :  tRP);
        chk_min(rmw_cycle ? "tRWC" : "tRC", t_ras_fall,
            rmw_cycle ?  tRWC  :  tRC);
        chk_min("tCRP", t_cas_rise,      tCRP);
        chk_min("tASR", t_addr_chg,      tASR);

        t_ras_fall        = $realtime;
        t_cas_rise_in_ras = NEVER;
        cas_seen_this_ras = 1'b0;
        col_moved         = 1'b0;
        page_access       = 1'b0;
        wrote_this_cas    = 1'b0;
        read_this_cas     = 1'b0;
        rmw_cycle         = 1'b0;
        self_ref_exited   = 1'b0;
        init_cycles++;

        if (!CAS_N) begin
            chk_min("tCSR", t_cas_fall, tCSR);

            if (!W_N) begin
                chk_min("tWTS", t_w_fall, tWTS);
                cyc       = C_TEST_ENTRY;
                test_mode = 1'b1;
                refresh_row(cbr_cnt);
                cbr_cnt   = cbr_cnt + 1'b1;
                $display("%0t ps | %m | NOTE: entering TEST MODE (WCBR); part behaves as 512K x 8", $time);
            end else begin
                chk_min("tWSR", t_w_rise, tWSR);
                cyc = C_CBR;
                refresh_row(cbr_cnt);
                cbr_cnt = cbr_cnt + 1'b1;
                if (test_mode) begin
                    test_mode = 1'b0;
                    $display("%0t ps | %m | NOTE: leaving TEST MODE (CBR with W high)", $time);
                end
            end
        end else begin
            cyc   = C_ROR;
            row_q = A;
            col_t = A;
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

    always @(posedge RAS_N) begin
        if (cyc == C_SELF) begin
            if (TIMING_CHECKS && !CAS_N) begin
            end else if (TIMING_CHECKS && (t_cas_rise > NEVER) &&
                (($realtime - t_cas_rise) > -tCHS + TOL))
                viol("tCHS", $sformatf("tCHS = %0.3f ns, minimum %0.3f ns",
                    t_cas_rise - $realtime, tCHS));

            for (int r = 0; r < N_ROWS; r++) begin
                row_last_ref[r] = $realtime;
                row_decayed[r]  = 1'b0;
            end
            self_ref_exited = 1'b1;
            $display("%0t ps | %m | NOTE: exiting SELF REFRESH; a burst refresh of all 1024 rows is required before normal operation", $time);
        end else begin
            chk_min(page_access ? "tRASP" : "tRAS", t_ras_fall,
                page_access ?  tRASP_MIN : tRAS_MIN);
            chk_max(page_access ? "tRASP" : "tRAS", t_ras_fall,
                page_access ?  tRASP_MAX : tRAS_MAX);
            if (cas_seen_this_ras) begin
                chk_min("tRSH", t_cas_fall, tRSH);
                chk_min("tRAL", t_col_chg,  tRAL);
            end
            if (cyc == C_ROR) begin
                if (test_mode) begin
                    test_mode = 1'b0;
                    $display("%0t ps | %m | NOTE: leaving TEST MODE (RAS-only refresh)", $time);
                end
            end
            if (wrote_this_cas)
                chk_min("tRWL", t_w_fall, tRWL);
            if (read_this_cas && !wrote_this_cas) begin
                chk_min("tROH", t_oe_fall, tROH);
                chk_min("tRRH", t_w_rise,  tRRH);
            end
        end

        t_ras_rise = $realtime;
        cyc        = C_IDLE;
    end

    always begin : self_ref_watch

        wait (!RAS_N && !CAS_N && ((cyc == C_CBR) || (cyc == C_TEST_ENTRY)));
        if (($realtime - t_ras_fall) >= (tRASS_MIN - TOL)) begin
            cyc = C_SELF;
            if (!LOW_POWER)
                warn("self refresh entered, but this device has no self-refresh option (non-P part)");
            $display("%0t ps | %m | NOTE: entering SELF REFRESH", $time);
            wait (RAS_N);
        end else begin
            #(tRASS_MIN / 20.0);
        end
    end

    always @(negedge CAS_N) begin
        chk_min("tCP",  t_cas_rise,      tCP);
        chk_min("tRPC", t_ras_rise,      tRPC);
        chk_min("tASC", t_addr_chg,      tASC);

        if (!RAS_N && cyc != C_CBR && cyc != C_SELF && cyc != C_TEST_ENTRY) begin
            if (!cas_seen_this_ras) begin
                chk_min("tRCD", t_ras_fall, tRCD_MIN);
                chk_max_acc("tRCD", t_ras_fall, tRCD_MAX);

                if (col_moved) begin
                    chk_span_min("tRAD", t_ras_fall, t_col_chg, tRAD_MIN);
                    chk_span_max_acc("tRAD", t_ras_fall, t_col_chg, tRAD_MAX);
                end
            end

            if (cas_seen_this_ras)
                chk_min(rmw_cycle ? "tPRWC" : "tPC", t_cas_fall,
                    rmw_cycle ?  tPRWC  :  tPC);

            t_cas_fall      = $realtime;
            cyc             = C_ACTIVE;
            cas_seen_this_ras = 1'b1;
            wrote_this_cas  = 1'b0;
            read_this_cas   = 1'b0;

            col_q = col_t;
            if (^col_q === 1'bx)
                warn("column address is X at CAS falling edge");

            if (!W_N) begin
                chk_min("tWCS", t_w_fall, tWCS);
                out_armed   = 1'b0;
                dq_oe       = 1'b0;
                disarm_read();
                do_write("early");
            end else begin
                chk_min("tRCS", t_w_rise, tRCS);
                read_this_cas = 1'b1;
                out_armed     = 1'b1;
                arm_read();
            end
        end else if (!RAS_N) begin
            t_cas_fall      = $realtime;
        end else begin
            t_cas_fall      = $realtime;
        end
    end

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

            if (A !== col_t) begin
                col_t     = A;
                col_moved = 1'b1;
                t_col_chg = $realtime;
            end
        end
        disarm_read();
        out_armed   = 1'b0;
    end

    always @(negedge W_N) begin
        t_w_fall = $realtime;
        if (cyc == C_CBR)
            chk_min("tWHR", t_ras_fall, tWHR);
        if (!RAS_N && !CAS_N && (cyc == C_ACTIVE) && !wrote_this_cas) begin
            chk_min("tCWD", t_cas_fall, tCWD);
            chk_min("tRWD", t_ras_fall, tRWD);
            chk_min("tAWD", t_col_chg,  tAWD);
            rmw_cycle = read_this_cas;

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
            chk_min("tWTH", t_ras_fall, tWTH);
    end

    always @(negedge OE_N) begin
        t_oe_fall = $realtime;
        if (out_armed && !CAS_N) arm_read();
    end

    always @(posedge OE_N) begin
        t_oe_rise = $realtime;
        chk_min("tOEH", t_oe_fall, tOEH);
    end

    always @(A) begin
        if (!RAS_N && (t_ras_fall > NEVER) && (($realtime - t_ras_fall) + TOL < tRAH) &&
            (cyc == C_ROR || cyc == C_ACTIVE))
            chk_min("tRAH", t_ras_fall, tRAH);

        if (!RAS_N && !CAS_N && cas_seen_this_ras && (cyc == C_ACTIVE)) begin
            chk_min("tCAH", t_cas_fall, tCAH);
            chk_min("tAR",  t_ras_fall, tAR);
        end

        t_addr_chg = $realtime;

        if (!RAS_N && CAS_N && (cyc == C_ROR || cyc == C_ACTIVE)) begin
            if (($realtime - t_ras_fall) >= tRAH) begin
                col_t     = A;
                col_moved = 1'b1;
                t_col_chg = $realtime;
                if (page_access && out_armed) arm_read();
            end
        end
    end

    always @(DQ) begin
        if (TIMING_CHECKS && !dq_oe && wrote_this_cas && (t_wr_strobe > NEVER)) begin
            if ((($realtime - t_wr_strobe) + TOL) < tDH)
                viol("tDH", $sformatf("tDH = %0.3f ns, minimum %0.3f ns",
                    $realtime - t_wr_strobe, tDH));

            if (!RAS_N && (t_ras_fall > NEVER) && ((($realtime - t_ras_fall) + TOL) < tDHR))
                viol("tDHR", $sformatf("tDHR = %0.3f ns, minimum %0.3f ns",
                    $realtime - t_ras_fall, tDHR));
        end
        t_dq_chg = $realtime;
    end

    initial begin : refresh_scan
        if (REFRESH_CHECKS) begin
            forever begin
                #(tREF / 8.0);
                if (cyc != C_SELF)
                    for (int r = 0; r < N_ROWS; r++)
                        if (!row_decayed[r] && (($realtime - row_last_ref[r]) > tREF + TOL)) begin
                            viol("tREF", $sformatf("row %0d has not been refreshed for %0.3f ms (tREF %0.3f ms)",
                                r, ($realtime - row_last_ref[r])/1.0e6, tREF/1.0e6));
                            decay_row(r[9:0]);
                        end
            end
        end
    end

    initial begin : powerup
        pwr_ready = 1'b0;
        #200000;
        wait (init_cycles >= 8);
        pwr_ready = 1'b1;
        note("power-up initialisation complete");
    end

    initial begin
        cyc               = C_IDLE;
        row_q             = '0;
        col_t             = '0;
        col_q             = '0;
        cbr_cnt           = '0;
        test_mode         = 1'b0;
        cas_seen_this_ras = 1'b0;
        col_moved         = 1'b0;
        page_access       = 1'b0;
        wrote_this_cas    = 1'b0;
        read_this_cas     = 1'b0;
        rmw_cycle         = 1'b0;
        self_ref_exited   = 1'b0;
        init_cycles       = 0;
        init_refresh_seen = 1'b0;
        n_viol = 0; n_viol_expected = 0; n_warn = 0;
        n_rd = 0; n_wr = 0; n_ref = 0; viol_quiet = 1'b0;
        last_viol = ""; watch_param = ""; watch_hit = 1'b0;

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
        t_wr_strobe = NEVER;

        for (int r = 0; r < N_ROWS; r++) begin
            row_last_ref[r] = 0.0;
            row_decayed[r]  = 1'b0;
        end

        $display("%0t ps | %m | %s behavioural model: 1M x 4, tRAC=%0.0fns tCAC=%0.0fns tRC=%0.0fns tREF=%0.0fms",
            $time, dev_name(), tRAC, tCAC, tRC, tREF/1.0e6);
    end

    final begin
        $display("---- %s: %0d reads, %0d writes, %0d refreshes | timing: %0d unexpected, %0d expected, %0d advisory",
            dev_name(), n_rd, n_wr, n_ref, n_viol, n_viol_expected, n_warn);
    end

endmodule
