`timescale 1ns / 1ps
`default_nettype none

module sn74ls174_tb;

    logic CLR_n;
    logic CLK;
    logic D;
    wire  Q;
    integer failures;

    sn74ls174 dut (
        .CLR_n(CLR_n),
        .CLK(CLK),
        .D(D),
        .Q(Q)
    );

    task automatic clock;
        begin
            CLK = 1'b0;
            #1;
            CLK = 1'b1;
            #1;
            CLK = 1'b0;
            #1;
        end
    endtask

    task automatic check;
        input logic expected;
        begin
            #1;

            if (Q !== expected) begin
                $display("FAIL Q=%b expected=%b", Q, expected);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        CLR_n = 1'b0;
        CLK = 1'b0;
        D = 1'b0;
        check(1'b0);

        CLR_n = 1'b1;
        D = 1'b1;
        clock();
        check(1'b1);

        D = 1'b0;
        check(1'b1);
        clock();
        check(1'b0);

        D = 1'b1;
        clock();
        CLR_n = 1'b0;
        check(1'b0);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ls174_tb");
        $finish;
    end

endmodule

`default_nettype wire
