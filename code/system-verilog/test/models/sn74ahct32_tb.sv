`timescale 1ns / 1ps
`default_nettype none

module sn74ahct32_tb;

    logic A;
    logic B;
    wire  Y;
    integer i;
    integer failures;

    sn74ahct32 dut (
        .A(A),
        .B(B),
        .Y(Y)
    );

    initial begin
        failures = 0;

        for (i = 0; i < 4; i = i + 1) begin
            {A, B} = i[1:0];
            #1;

            if (Y !== |i[1:0]) begin
                $display("FAIL inputs=%b Y=%b expected=%b", i[1:0], Y, |i[1:0]);
                failures = failures + 1;
            end
        end

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS sn74ahct32_tb");
        $finish;
    end

endmodule

`default_nettype wire
