`timescale 1ns / 1ps

module tb_sn74hct74;
    reg PRE_n, CLR_n, CLK, D;
    wire Q, Q_n;
    integer errors = 0;

    sn74hct74 dut(.PRE_n(PRE_n), .CLR_n(CLR_n), .CLK(CLK), .D(D), .Q(Q), .Q_n(Q_n));

    task check;
        input exp_q, exp_qn;
        input string name;
        begin
            if (Q !== exp_q || Q_n !== exp_qn) begin
                $display("FAIL %s Q=%b Q_n=%b want Q=%b Q_n=%b", name, Q, Q_n, exp_q, exp_qn);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        PRE_n = 1; CLR_n = 1; CLK = 0; D = 0;
        #100;

        PRE_n = 0; #100; check(1'b1, 1'b0, "preset");
        PRE_n = 1; #100;

        CLR_n = 0; #100; check(1'b0, 1'b1, "clear");
        CLR_n = 1; #100;

        PRE_n = 0; CLR_n = 0; #100; check(1'b1, 1'b1, "both low");
        PRE_n = 1; CLR_n = 1; #100;

        D = 1; #50; CLK = 1; #50; CLK = 0; #100; check(1'b1, 1'b0, "load 1");
        D = 0; #50; CLK = 1; #50; CLK = 0; #100; check(1'b0, 1'b1, "load 0");
        D = 1; #50; CLK = 1; #50; CLK = 0; #100; check(1'b1, 1'b0, "load 1 again");

        if (errors == 0) $display("PASS tb_sn74hct74");
        else $fatal(1, "FAIL tb_sn74hct74: %0d errors", errors);
    end
endmodule
