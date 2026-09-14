`timescale 1ns / 1ps
`default_nettype none

module sn74ls14_tb;

    logic A;
    wire  Y;
    integer failures;

    sn74ls14 dut (
        .A(A),
        .Y(Y)
    );

    task automatic check;
        input logic a;
        input logic expected;
        begin
            A = a;
            #1;

            if (Y !== expected) begin
                $display("FAIL A=%b Y=%b expected=%b", A, Y, expected);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;

        check(1'b0, 1'b1);
        check(1'b1, 1'b0);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ls14_tb");
        $finish;
    end

endmodule

`default_nettype wire
