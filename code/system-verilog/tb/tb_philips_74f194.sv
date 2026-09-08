`timescale 1ns / 1ps

module tb_philips_74f194;
    reg MR_n, CP, S0, S1, DSR, DSL;
    reg [3:0] D;
    wire [3:0] Q;
    integer errors = 0;

    philips_74f194 dut(.MR_n(MR_n), .CP(CP), .S0(S0), .S1(S1),
                       .DSR(DSR), .DSL(DSL), .D(D), .Q(Q));

    task check;
        input [3:0] exp;
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
            CP = 0; #50; CP = 1; #50; CP = 0; #50;
        end
    endtask

    initial begin
        MR_n = 1; CP = 0; S0 = 0; S1 = 0; DSR = 0; DSL = 0; D = 0;
        #100;

        MR_n = 0; #50; check(4'h0, "reset");
        MR_n = 1; #100;

        D = 4'h9; S1 = 1; S0 = 1; #50; cp_pulse; check(4'h9, "load");
        S1 = 0; S0 = 0; #50;

        DSR = 1; S1 = 0; S0 = 1; #50; cp_pulse; check(4'h3, "s0s1=01 dsr=1");
        DSR = 0; cp_pulse; check(4'h6, "s0s1=01 dsr=0");
        S1 = 0; S0 = 0; #50;

        DSL = 1; S1 = 1; S0 = 0; #50; cp_pulse; check(4'hB, "s0s1=10 dsl=1");
        DSL = 0; cp_pulse; check(4'h5, "s0s1=10 dsl=0");

        S1 = 0; S0 = 0; cp_pulse; check(4'h5, "hold");

        if (errors == 0) $display("PASS tb_philips_74f194");
        else $fatal(1, "FAIL tb_philips_74f194: %0d errors", errors);
    end
endmodule
