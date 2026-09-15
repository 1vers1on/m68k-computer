`timescale 1ns / 1ps
`default_nettype none

module tb_clock_reset;

    logic MASTER_CLK_40 = 0;
    logic RESET_RAW_n    = 0;
    logic cpu_reset_drive = 0;
    logic cpu_halt_drive  = 0;

    wire CPU_RESET_n;
    wire CPU_HALT_n;
    wire CPU_CLK_DIV2;
    wire CPU_CLK_10;
    wire RESET_n;
    wire PIT_CLK;
    wire TIMEOUT_CLK;
    wire PERIPH_RESET_n;

    // 40 MHz master clock (25 ns period).
    always #12.5 MASTER_CLK_40 = ~MASTER_CLK_40;

    // CPU open-drain /RESET and /HALT outputs. Asserting a drive signal pulls
    // the corresponding bidirectional pin low, leaving the DUT's open-collector
    // LS07 channels and pull-ups free to drive it otherwise.
    assign CPU_RESET_n = cpu_reset_drive ? 1'b0 : 1'bz;
    assign CPU_HALT_n  = cpu_halt_drive  ? 1'b0 : 1'bz;

    clock_reset dut (
        .MASTER_CLK_40(MASTER_CLK_40),
        .RESET_RAW_n(RESET_RAW_n),
        .CPU_RESET_n(CPU_RESET_n),
        .CPU_HALT_n(CPU_HALT_n),
        .CPU_CLK_DIV2(CPU_CLK_DIV2),
        .CPU_CLK_10(CPU_CLK_10),
        .RESET_n(RESET_n),
        .PIT_CLK(PIT_CLK),
        .TIMEOUT_CLK(TIMEOUT_CLK),
        .PERIPH_RESET_n(PERIPH_RESET_n)
    );

    integer errors = 0;

    task automatic check(input bit condition, input string message);
        if (!condition) begin
            $display("FAIL %s", message);
            errors = errors + 1;
        end
    endtask

    realtime t0, t1;

    // The divider has no reset input, so the SN74F74 model powers up with its
    // internal state at x and, in a Q_n-to-D toggle, never escapes it. Give
    // both stages a defined (unspecified, but real) power-up state so the
    // free-running divider leaves x immediately, as the physical part does.
    initial begin
        force dut.U_CPU_CLK_STAGE1.q_int  = 1'b0;
        force dut.U_CPU_CLK_STAGE1.qn_int = 1'b1;
        force dut.U_CPU_CLK_STAGE2.q_int  = 1'b0;
        force dut.U_CPU_CLK_STAGE2.qn_int = 1'b1;
        #1;
        release dut.U_CPU_CLK_STAGE1.q_int;
        release dut.U_CPU_CLK_STAGE1.qn_int;
        release dut.U_CPU_CLK_STAGE2.q_int;
        release dut.U_CPU_CLK_STAGE2.qn_int;
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile(".build/clock_reset.vcd");
            $dumpvars(1, tb_clock_reset);
        end
        #1000000;
        $fatal(1, "tb_clock_reset: watchdog expired");
    end

    initial begin
        #1000;
        // Power-up: the raw reset is held low while the clock free-runs. Both
        // conditioner stages and all three LS07 channels reproduce the reset
        // onto every reset domain.
        check(RESET_n === 1'b0, "RESET_RAW_n low asserts RESET_n");
        check(CPU_RESET_n === 1'b0, "board reset asserts CPU_RESET_n");
        check(CPU_HALT_n === 1'b0, "board reset asserts CPU_HALT_n");
        check(PERIPH_RESET_n === 1'b0, "board reset asserts PERIPH_RESET_n");

        // The divider is never gated or reset, so the clocks run during reset.
        @(posedge CPU_CLK_DIV2);
        t0 = $realtime;
        @(posedge CPU_CLK_DIV2);
        t1 = $realtime;
        check((t1 - t0) > 45.0 && (t1 - t0) < 55.0, "CPU_CLK_DIV2 period is 50 ns");

        @(posedge CPU_CLK_10);
        t0 = $realtime;
        @(posedge CPU_CLK_10);
        t1 = $realtime;
        check((t1 - t0) > 95.0 && (t1 - t0) < 105.0, "CPU_CLK_10 period is 100 ns");

        // Release the raw reset; every net recovers to a driven/pulled high.
        RESET_RAW_n = 1'b1;
        #500;
        check(RESET_n === 1'b1, "RESET_RAW_n high releases RESET_n");
        check(CPU_RESET_n === 1'b1, "CPU_RESET_n released high");
        check(CPU_HALT_n === 1'b1, "CPU_HALT_n released high");
        check(PERIPH_RESET_n === 1'b1, "PERIPH_RESET_n released high");

        // The I/O clock buffer carries CPU_CLK_10 to PIT_CLK and TIMEOUT_CLK.
        @(posedge PIT_CLK);
        t0 = $realtime;
        @(posedge PIT_CLK);
        t1 = $realtime;
        check((t1 - t0) > 95.0 && (t1 - t0) < 105.0, "PIT_CLK period is 100 ns");

        @(posedge TIMEOUT_CLK);
        t0 = $realtime;
        @(posedge TIMEOUT_CLK);
        t1 = $realtime;
        check((t1 - t0) > 95.0 && (t1 - t0) < 105.0, "TIMEOUT_CLK period is 100 ns");

        // Both buffered clocks follow CPU_CLK_10 a couple of buffer delays later.
        @(posedge CPU_CLK_10);
        #40;
        check(PIT_CLK === 1'b1 && TIMEOUT_CLK === 1'b1, "I/O clocks high mid-period");
        @(negedge CPU_CLK_10);
        #40;
        check(PIT_CLK === 1'b0 && TIMEOUT_CLK === 1'b0, "I/O clocks low mid-period");

        // A CPU RESET instruction drives /RESET low without a board reset. It
        // propagates into the peripheral domain but must not reassert RESET_n.
        cpu_reset_drive = 1'b1;
        #300;
        check(CPU_RESET_n === 1'b0, "CPU RESET instruction asserts CPU_RESET_n");
        check(PERIPH_RESET_n === 1'b0, "peripheral reset follows CPU_RESET_n");
        check(RESET_n === 1'b1, "CPU reset does not feed back into RESET_n");
        check(CPU_HALT_n === 1'b1, "CPU reset leaves CPU_HALT_n released");

        // A halt condition asserts only /HALT.
        cpu_reset_drive = 1'b0;
        cpu_halt_drive  = 1'b1;
        #300;
        check(CPU_HALT_n === 1'b0, "CPU halt asserts CPU_HALT_n");
        check(CPU_RESET_n === 1'b1, "halt leaves CPU_RESET_n released");
        check(PERIPH_RESET_n === 1'b1, "halt leaves PERIPH_RESET_n released");
        check(RESET_n === 1'b1, "halt does not feed back into RESET_n");

        // A later board reset reasserts both processor pins regardless of the
        // CPU's own open-drain state.
        cpu_reset_drive = 1'b1;
        RESET_RAW_n = 1'b0;
        #500;
        check(RESET_n === 1'b0, "reapplied raw reset asserts RESET_n");
        check(CPU_RESET_n === 1'b0 && CPU_HALT_n === 1'b0,
            "board reset overrides both processor pins");
        check(PERIPH_RESET_n === 1'b0, "board reset reasserts PERIPH_RESET_n");

        RESET_RAW_n = 1'b1;
        cpu_reset_drive = 1'b0;
        cpu_halt_drive  = 1'b0;
        #500;
        check(CPU_RESET_n === 1'b1 && CPU_HALT_n === 1'b1,
            "release after board reset returns processor pins high");

        if (errors == 0) $display("PASS tb_clock_reset");
        else $fatal(1, "FAIL tb_clock_reset: %0d errors", errors);
        $finish;
    end

endmodule

`default_nettype wire