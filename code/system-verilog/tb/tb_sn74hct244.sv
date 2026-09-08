`timescale 1ns / 1ps

module tb_sn74hct244;
    reg OE_n, A;
    wire Y;
    integer errors = 0;

    sn74hct244 dut(.OE_n(OE_n), .A(A), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            OE_n = i[1];
            A = i[0];
            #100;
            if (Y !== (OE_n ? 1'bz : A)) begin
                $display("FAIL OE_n=%b A=%b got=%b want=%b", OE_n, A, Y, OE_n ? 1'bz : A);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_sn74hct244");
        else $fatal(1, "FAIL tb_sn74hct244: %0d errors", errors);
    end
endmodule
