`timescale 1ns / 1ps
`default_nettype none

module sn74ahct74_tb;

    logic PRE_n;
    logic CLR_n;
    logic CLK;
    logic D;
    wire  Q;
    wire  Q_n;
    integer failures;

    sn74ahct74 dut (
        .PRE_n(PRE_n),
        .CLR_n(CLR_n),
        .CLK(CLK),
        .D(D),
        .Q(Q),
        .Q_n(Q_n)
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
        input logic expected_q;
        input logic expected_q_n;
        begin
            #1;

            if (Q !== expected_q || Q_n !== expected_q_n) begin
                $display("FAIL Q=%b Q_n=%b expected=%b/%b", Q, Q_n, expected_q, expected_q_n);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        PRE_n = 1'b1;
        CLR_n = 1'b1;
        CLK = 1'b0;
        D = 1'b0;
        #1;
        CLR_n = 1'b0;
        check(1'b0, 1'b1);

        CLR_n = 1'b1;
        PRE_n = 1'b0;
        check(1'b1, 1'b0);

        PRE_n = 1'b1;
        D = 1'b0;
        clock();
        check(1'b0, 1'b1);

        D = 1'b1;
        clock();
        check(1'b1, 1'b0);

        PRE_n = 1'b0;
        CLR_n = 1'b0;
        check(1'b1, 1'b1);

        PRE_n = 1'b1;
        CLR_n = 1'b1;
        D = 1'b0;
        clock();
        check(1'b0, 1'b1);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ahct74_tb");
        $finish;
    end

endmodule

`default_nettype wire
