`timescale 1ns / 1ps
`default_nettype none

module sn74ls07_tb;

    logic A;
    tri   Y;
    wire  Y_raw;
    integer failures;

    pullup u_pullup (Y);

    sn74ls07 dut (
        .A(A),
        .Y(Y)
    );

    sn74ls07 dut_raw (
        .A(A),
        .Y(Y_raw)
    );

    initial begin
        failures = 0;

        A = 1'b0;
        #1;

        if (Y !== 1'b0 || Y_raw !== 1'b0) begin
            $display("FAIL low drive Y=%b Y_raw=%b", Y, Y_raw);
            failures = failures + 1;
        end

        A = 1'b1;
        #1;

`ifdef VERILATOR
        if (Y !== 1'b1) begin
            $display("FAIL release Y=%b", Y);
            failures = failures + 1;
        end
`else
        if (Y !== 1'b1 || Y_raw !== 1'bz) begin
            $display("FAIL release Y=%b Y_raw=%b", Y, Y_raw);
            failures = failures + 1;
        end
`endif

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ls07_tb");
        $finish;
    end

endmodule

`default_nettype wire
