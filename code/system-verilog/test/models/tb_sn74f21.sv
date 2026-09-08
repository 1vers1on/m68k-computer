`timescale 1ns / 1ps

module tb_sn74f21;
    reg A, B, C, D;
    wire Y;
    integer errors = 0;

    sn74f21 dut(.A(A), .B(B), .C(C), .D(D), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            A = i[3];
            B = i[2];
            C = i[1];
            D = i[0];
            #100;
            if (Y !== (A & B & C & D)) begin
                $display("FAIL A=%b B=%b C=%b D=%b got=%b want=%b", A, B, C, D, Y, A & B & C & D);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74f21");
        else $fatal(1, "FAIL tb_sn74f21: %0d errors", errors);
    end
endmodule
