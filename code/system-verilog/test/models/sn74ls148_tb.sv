`timescale 1ns / 1ps
`default_nettype none

module sn74ls148_tb;

    logic [7:0] I_n;
    logic       EI_n;
    wire  [2:0] A_n;
    wire        GS_n;
    wire        EO_n;
    integer i;
    integer failures;

    sn74ls148 dut (
        .I_n(I_n),
        .EI_n(EI_n),
        .A_n(A_n),
        .GS_n(GS_n),
        .EO_n(EO_n)
    );

    task automatic check;
        input logic [2:0] expected_a;
        input logic       expected_gs;
        input logic       expected_eo;
        begin
            #1;

            if (A_n !== expected_a || GS_n !== expected_gs || EO_n !== expected_eo) begin
                $display("FAIL I_n=%b EI_n=%b outputs=%b/%b/%b expected=%b/%b/%b",
                    I_n, EI_n, A_n, GS_n, EO_n, expected_a, expected_gs, expected_eo);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        failures = 0;
        EI_n = 1'b0;
        I_n = 8'hff;
        check(3'b111, 1'b1, 1'b0);

        for (i = 0; i < 8; i = i + 1) begin
            I_n = ~(8'b1 << i);
            check(~i[2:0], 1'b0, 1'b1);
        end

        I_n = 8'b01110111;
        check(3'b000, 1'b0, 1'b1);

        EI_n = 1'b1;
        I_n = 8'h00;
        check(3'b111, 1'b1, 1'b1);

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ls148_tb");
        $finish;
    end

endmodule

`default_nettype wire
