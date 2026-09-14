`timescale 1ns / 1ps
`default_nettype none

module sn74ls390_tb;

    logic       CLKA;
    logic       CLKB;
    logic       CLR;
    wire  [3:0] Q;
    logic       decade_clka;
    logic       decade_clr;
    wire        decade_clkb;
    wire  [3:0] decade_q;
    integer i;
    integer failures;

    assign decade_clkb = decade_q[0];

    sn74ls390 dut (
        .CLKA(CLKA),
        .CLKB(CLKB),
        .CLR(CLR),
        .Q(Q)
    );

    sn74ls390 dut_decade (
        .CLKA(decade_clka),
        .CLKB(decade_clkb),
        .CLR(decade_clr),
        .Q(decade_q)
    );

    task automatic pulse_a;
        begin
            CLKA = 1'b1;
            #1;
            CLKA = 1'b0;
            #1;
        end
    endtask

    task automatic pulse_b;
        begin
            CLKB = 1'b1;
            #1;
            CLKB = 1'b0;
            #1;
        end
    endtask

    task automatic pulse_decade;
        begin
            decade_clka = 1'b1;
            #1;
            decade_clka = 1'b0;
            #1;
        end
    endtask

    task automatic check;
        input logic [3:0] actual;
        input integer expected;
        begin
            #1;

            if (actual !== expected[3:0]) begin
                $display("FAIL actual=%b expected=%b", actual, expected[3:0]);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        CLKA = 1'b0;
        CLKB = 1'b0;
        CLR = 1'b1;
        decade_clka = 1'b0;
        decade_clr = 1'b1;
        #1;
        CLR = 1'b0;
        decade_clr = 1'b0;
        check(Q, 0);
        check(decade_q, 0);

        pulse_a();
        check(Q, 1);
        pulse_a();
        check(Q, 0);

        for (i = 1; i <= 5; i = i + 1) begin
            pulse_b();
            check(Q, (i % 5) << 1);
        end

        for (i = 1; i <= 10; i = i + 1) begin
            pulse_decade();
            check(decade_q, i % 10);
        end

        CLR = 1'b1;
        decade_clr = 1'b1;
        check(Q, 0);
        check(decade_q, 0);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ls390_tb");
        $finish;
    end

endmodule

`default_nettype wire
