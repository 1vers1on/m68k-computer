`timescale 1ns / 1ps
`default_nettype none

module cd74hct21_tb;

    logic A;
    logic B;
    logic C;
    logic D;
    wire  Y;
    integer i;
    integer failures;

    cd74hct21 dut (
        .A(A),
        .B(B),
        .C(C),
        .D(D),
        .Y(Y)
    );

    initial begin
        failures = 0;

        for (i = 0; i < 16; i = i + 1) begin
            {A, B, C, D} = i[3:0];
            #1;

            if (Y !== &i[3:0]) begin
                $display("FAIL inputs=%b Y=%b expected=%b", i[3:0], Y, &i[3:0]);
                failures = failures + 1;
            end
        end

        if (failures != 0) $fatal(1, "%0d checks failed", failures);

        $display("PASS cd74hct21_tb");
        $finish;
    end

endmodule

`default_nettype wire
