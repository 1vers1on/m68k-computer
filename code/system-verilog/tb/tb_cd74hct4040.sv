`timescale 1ns / 1ps

module tb_cd74hct4040;
    reg CP, MR;
    wire [12:1] Q;
    integer errors = 0;

    cd74hct4040 dut(.CP(CP), .MR(MR), .Q(Q));

    task check;
        input [11:0] exp;
        input string name;
        begin
            if (Q !== exp) begin
                $display("FAIL %s Q=%h want=%h", name, Q, exp);
                errors = errors + 1;
            end
        end
    endtask

    task cp_pulse;
        begin
            CP = 0; #100; CP = 1; #100; CP = 0; #100;
        end
    endtask

    initial begin
        CP = 0; MR = 1;
        #100;
        MR = 0; #100; check(12'h000, "reset");

        repeat (1) cp_pulse; #400; check(12'h001, "count 1");
        repeat (7) cp_pulse; #400; check(12'h008, "count 8");
        repeat (8) cp_pulse; #400; check(12'h010, "count 16");

        MR = 1; #100; check(12'h000, "async reset");
        MR = 0; #100;

        if (errors == 0) $display("PASS tb_cd74hct4040");
        else $fatal(1, "FAIL tb_cd74hct4040: %0d errors", errors);
    end
endmodule
