`timescale 1ns / 1ps

module tb_fairchild_74f191;
    reg PL_n, CE_n, UD_n, CP;
    reg [3:0] P;
    wire [3:0] Q;
    wire TC, RC_n;
    integer errors = 0;

    fairchild_74f191 dut(.PL_n(PL_n), .CE_n(CE_n), .UD_n(UD_n), .CP(CP),
                         .P(P), .Q(Q), .TC(TC), .RC_n(RC_n));

    task check;
        input [3:0] exp_q;
        input exp_tc;
        input string name;
        begin
            if (Q !== exp_q || TC !== exp_tc) begin
                $display("FAIL %s Q=%h TC=%b want Q=%h TC=%b", name, Q, TC, exp_q, exp_tc);
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
        PL_n = 1; CE_n = 1; UD_n = 0; CP = 0; P = 0;
        #100;

        PL_n = 0; P = 4'h3; #50; check(4'h3, 1'b0, "transparent load");
        P = 4'h5; #50; check(4'h5, 1'b0, "transparent load update");
        PL_n = 1; #100;

        CE_n = 0; UD_n = 0;
        cp_pulse; check(4'h6, 1'b0, "count up 6");
        cp_pulse; check(4'h7, 1'b0, "count up 7");

        PL_n = 0; P = 4'hF; #50; check(4'hF, 1'b1, "load F tc up");
        PL_n = 1; #50;
        if (RC_n !== 1'b0) begin
            $display("FAIL rc_n up F CP low: got=%b want=0", RC_n);
            errors = errors + 1;
        end
        cp_pulse; check(4'h0, 1'b0, "wrap up");

        PL_n = 0; P = 4'h0; #50; check(4'h0, 1'b0, "load 0");
        PL_n = 1; #50;
        UD_n = 1; #50; check(4'h0, 1'b1, "tc down at 0");
        cp_pulse; check(4'hF, 1'b0, "wrap down");

        if (errors == 0) $display("PASS tb_fairchild_74f191");
        else $fatal(1, "FAIL tb_fairchild_74f191: %0d errors", errors);
    end
endmodule
