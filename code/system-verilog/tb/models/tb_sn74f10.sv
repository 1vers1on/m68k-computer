`timescale 1ns / 1ps

module tb_sn74f10;
    reg A, B, C;
    wire Y;
    integer errors = 0;

    sn74f10 dut(.A(A), .B(B), .C(C), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            A = i[2];
            B = i[1];
            C = i[0];
            #100;
            if (Y !== ~(A & B & C)) begin
                $display("FAIL A=%b B=%b C=%b got=%b want=%b", A, B, C, Y, ~(A & B & C));
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74f10");
        else $fatal(1, "FAIL tb_sn74f10: %0d errors", errors);
    end
endmodule
