`timescale 1ns / 1ps
`default_nettype none

module sn74ls174 #(
    // max propagation delay times in ns
    parameter real TPLH_CLK = 25.0,
    parameter real TPHL_CLK = 25.0,
    parameter real TPHL_CLR = 27.0,

    // timing requirements in ns
    parameter real TW_CLK = 25.0,
    parameter real TW_CLR = 20.0,
    parameter real TSU_D  = 20.0,
    parameter real TH_D   = 5.0,
    parameter real TREC   = 5.0
) (
    input  wire CLR_n,
    input  wire CLK,
    input  wire D,
    output wire Q
);

    logic q_int;
    reg   notifier;

    always @(posedge CLK or negedge CLR_n) begin
        if (!CLR_n) q_int <= 1'b0;
        else        q_int <= D;
    end

    always @(notifier) q_int <= 1'bx;

    assign Q = q_int;

    specify
        specparam tplh_clk = TPLH_CLK;
        specparam tphl_clk = TPHL_CLK;
        specparam tphl_clr = TPHL_CLR;
        specparam tw_clk   = TW_CLK;
        specparam tw_clr   = TW_CLR;
        specparam tsu_d    = TSU_D;
        specparam th_d     = TH_D;
        specparam trec     = TREC;

        (CLK => Q)   = (tplh_clk, tphl_clk);
        (CLR_n => Q) = (tphl_clr, tphl_clr);

        $width(posedge CLK, tw_clk, 0, notifier);
        $width(negedge CLK, tw_clk, 0, notifier);
        $width(negedge CLR_n, tw_clr, 0, notifier);
        $setuphold(posedge CLK, D, tsu_d, th_d, notifier);
        $recovery(posedge CLR_n, posedge CLK, trec, notifier);
    endspecify

endmodule

`default_nettype wire
