`timescale 1ns / 1ps

module tb_sn74hct574;
    reg OE_n, CLK, D;
    wire Q;
    integer errors = 0;

    sn74hct574 dut(.OE_n(OE_n), .CLK(CLK), .D(D), .Q(Q));

    task check;
        input exp;
        input string name;
        begin
            if (Q !== exp) begin
                $display("FAIL %s Q=%b want=%b", name, Q, exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        OE_n = 0; CLK = 0; D = 0;
        #100;

        D = 1; #50; CLK = 1; #50; CLK = 0; #100; check(1'b1, "load 1");
        D = 0; #50; CLK = 1; #50; CLK = 0; #100; check(1'b0, "load 0");

        OE_n = 1; #100; check(1'bz, "tristate off");
        OE_n = 0; #100; check(1'b0, "tristate on");

        if (errors == 0) $display("PASS tb_sn74hct574");
        else $fatal(1, "FAIL tb_sn74hct574: %0d errors", errors);
    end
endmodule
