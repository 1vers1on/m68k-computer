`timescale 1ns / 1ps
`default_nettype none

module cd74hct123_tb;

    logic A_n;
    logic B;
    logic CLR_n;
    wire  Q;
    wire  Q_n;
    integer failures;

    cd74hct123 #(
        .TW(20.0)
    ) dut (
        .A_n(A_n),
        .B(B),
        .CLR_n(CLR_n),
        .Q(Q),
        .Q_n(Q_n)
    );

    task automatic check;
        input logic expected_q;
        begin
            #1;

            if (Q !== expected_q || Q_n !== ~expected_q) begin
                $display("FAIL Q=%b Q_n=%b expected=%b/%b", Q, Q_n, expected_q, ~expected_q);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        A_n = 1'b1;
        B = 1'b0;
        CLR_n = 1'b1;
        #1;
        CLR_n = 1'b0;
        check(1'b0);

        CLR_n = 1'b1;
        B = 1'b1;
        #1;
        A_n = 1'b0;
        check(1'b1);

        #8;
        A_n = 1'b1;
        #1;
        A_n = 1'b0;
        check(1'b1);

        #17;
        check(1'b1);
        #2;
        check(1'b0);

        A_n = 1'b1;
        B = 1'b0;
        #1;
        B = 1'b1;
        #1;
        A_n = 1'b0;
        check(1'b1);

        CLR_n = 1'b0;
        check(1'b0);
        #25;
        check(1'b0);

        CLR_n = 1'b1;
        check(1'b1);
        #18;
        check(1'b1);
        #2;
        check(1'b0);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS cd74hct123_tb");
        $finish;
    end

endmodule

`default_nettype wire
