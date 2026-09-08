`timescale 1ns / 1ps

module tb_sn74f00;
    reg A, B;
    wire Y;
    integer errors = 0;

    sn74f00 dut(.A(A), .B(B), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            A = i[1];
            B = i[0];
            #100;
            if (Y !== ~(A & B)) begin
                $display("FAIL A=%b B=%b got=%b want=%b", A, B, Y, ~(A & B));
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74f00");
        else $fatal(1, "FAIL tb_sn74f00: %0d errors", errors);
    end
endmodule
