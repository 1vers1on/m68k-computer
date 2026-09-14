`timescale 1ns / 1ps
`default_nettype none

module sn74hct125_tb;

    logic OE_n;
    logic A;
    wire  Y;
    integer failures;

    sn74hct125 dut (
        .OE_n(OE_n),
        .A(A),
        .Y(Y)
    );

    task automatic check;
        input logic expected;
        begin
            #1;

            if (Y !== expected) begin
                $display("FAIL OE_n=%b A=%b Y=%b expected=%b", OE_n, A, Y, expected);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        OE_n = 1'b1;
        A = 1'b0;
`ifndef VERILATOR
        check(1'bz);
`endif

        A = 1'b1;
`ifndef VERILATOR
        check(1'bz);
`endif

        OE_n = 1'b0;
        check(1'b1);

        A = 1'b0;
        check(1'b0);

        OE_n = 1'b1;
`ifndef VERILATOR
        check(1'bz);
`endif

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74hct125_tb");
        $finish;
    end

endmodule

`default_nettype wire
