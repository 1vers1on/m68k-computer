`timescale 1ns / 1ps

module tb_sn74f30;
    reg A, B, C, D, E, F, G, H;
    wire Y;
    integer errors = 0;

    sn74f30 dut(.A(A), .B(B), .C(C), .D(D), .E(E), .F(F), .G(G), .H(H), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            A = i[7];
            B = i[6];
            C = i[5];
            D = i[4];
            E = i[3];
            F = i[2];
            G = i[1];
            H = i[0];
            #100;
            if (Y !== ~(A & B & C & D & E & F & G & H)) begin
                $display("FAIL i=%0d got=%b want=%b", i, Y, ~(A & B & C & D & E & F & G & H));
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74f30");
        else $fatal(1, "FAIL tb_sn74f30: %0d errors", errors);
    end
endmodule
