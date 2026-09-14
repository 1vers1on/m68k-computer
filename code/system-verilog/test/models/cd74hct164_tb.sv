`timescale 1ns / 1ps
`default_nettype none

module cd74hct164_tb;

    logic       A;
    logic       B;
    logic       CP;
    logic       MR_n;
    wire  [7:0] Q;
    integer failures;

    cd74hct164 dut (
        .A(A),
        .B(B),
        .CP(CP),
        .MR_n(MR_n),
        .Q(Q)
    );

    task automatic clock;
        begin
            CP = 1'b0;
            #1;
            CP = 1'b1;
            #1;
            CP = 1'b0;
            #1;
        end
    endtask

    task automatic check;
        input logic [7:0] expected;
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
        A = 1'b0;
        B = 1'b0;
        CP = 1'b0;
        MR_n = 1'b0;
        check(8'h00);

        MR_n = 1'b1;
        A = 1'b1;
        B = 1'b1;
        clock();
        check(8'h01);

        B = 1'b0;
        clock();
        check(8'h02);

        B = 1'b1;
        clock();
        check(8'h05);

        A = 1'b0;
        clock();
        check(8'h0a);

        MR_n = 1'b0;
        check(8'h00);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS cd74hct164_tb");
        $finish;
    end

endmodule

`default_nettype wire
