`timescale 1ns / 1ps

module tb_sn74f04;
    reg A;
    wire Y;
    integer errors = 0;

    sn74f04 dut(.A(A), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 2; i = i + 1) begin
            A = i[0];
            #100;
            if (Y !== ~A) begin
                $display("FAIL A=%b got=%b want=%b", A, Y, ~A);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74f04");
        else $fatal(1, "FAIL tb_sn74f04: %0d errors", errors);
    end
endmodule
