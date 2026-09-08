`timescale 1ns / 1ps

module tb_sn74f138;
    reg G1, G2A_n, G2B_n;
    reg [2:0] A;
    wire [7:0] Y;
    integer errors = 0;

    sn74f138 dut(.G1(G1), .G2A_n(G2A_n), .G2B_n(G2B_n), .A(A), .Y(Y));

    integer i;
    reg [5:0] stim;
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            stim = i;
            G1 = stim[5];
            G2A_n = stim[4];
            G2B_n = stim[3];
            A = stim[2:0];
            #100;
            if (Y !== ((G1 & ~G2A_n & ~G2B_n) ? ~(8'b1 << A) : 8'hFF)) begin
                $display("FAIL i=%0d Y=%b", i, Y);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74f138");
        else $fatal(1, "FAIL tb_sn74f138: %0d errors", errors);
    end
endmodule
