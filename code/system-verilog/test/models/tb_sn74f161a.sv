`timescale 1ns / 1ps

module tb_sn74f161a;
    reg CLR_n, LOAD_n, ENP, ENT, CLK;
    reg [3:0] D;
    wire [3:0] Q;
    wire RCO;
    integer errors = 0;

    sn74f161a dut(.CLR_n(CLR_n), .LOAD_n(LOAD_n), .ENP(ENP), .ENT(ENT),
                  .CLK(CLK), .D(D), .Q(Q), .RCO(RCO));

    task check;
        input [3:0] exp_q;
        input exp_rco;
        input string name;
        begin
            if (Q !== exp_q || RCO !== exp_rco) begin
                $display("FAIL %s Q=%h RCO=%b want Q=%h RCO=%b", name, Q, RCO, exp_q, exp_rco);
                errors = errors + 1;
            end
        end
    endtask

    task clk_pulse;
        begin
            CLK = 0; #50; CLK = 1; #50; CLK = 0; #50;
        end
    endtask

    initial begin
        CLR_n = 1; LOAD_n = 1; ENP = 0; ENT = 0; CLK = 0; D = 0;
        #100;

        CLR_n = 0; #50; check(4'h0, 1'b0, "clear");
        CLR_n = 1; #100;

        D = 4'hA; LOAD_n = 0; clk_pulse; check(4'hA, 1'b0, "load");
        LOAD_n = 1; #50;

        ENP = 1; ENT = 1; #50;
        clk_pulse; check(4'hB, 1'b0, "count B");
        clk_pulse; check(4'hC, 1'b0, "count C");
        clk_pulse; check(4'hD, 1'b0, "count D");
        clk_pulse; check(4'hE, 1'b0, "count E");
        clk_pulse; check(4'hF, 1'b1, "count F rco");
        clk_pulse; check(4'h0, 1'b0, "wrap");

        ENT = 0; #50; check(4'h0, 1'b0, "ent low rco");

        if (errors == 0) $display("PASS tb_sn74f161a");
        else $fatal(1, "FAIL tb_sn74f161a: %0d errors", errors);
    end
endmodule
