`timescale 1ns / 1ps

module tb_cd74act157;
    reg G_n, SEL, A, B;
    wire Y;
    integer errors = 0;

    cd74act157 dut(.G_n(G_n), .SEL(SEL), .A(A), .B(B), .Y(Y));

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            G_n = i[3];
            SEL = i[2];
            A = i[1];
            B = i[0];
            #100;
            if (Y !== (G_n ? 1'b0 : (SEL ? B : A))) begin
                $display("FAIL G_n=%b SEL=%b A=%b B=%b got=%b want=%b",
                         G_n, SEL, A, B, Y, G_n ? 1'b0 : (SEL ? B : A));
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS tb_cd74act157");
        else $fatal(1, "FAIL tb_cd74act157: %0d errors", errors);
    end
endmodule
