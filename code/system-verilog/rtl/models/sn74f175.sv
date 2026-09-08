`timescale 1ns / 1ps
`default_nettype none

module sn74f175 #(
    // max propagation delay times in ns
    parameter real TPLH     = 6.5,
    parameter real TPHL     = 8.5,
    parameter real TPLH_CLR = 8.5,
    parameter real TPHL_CLR = 11.5,

    // timing requirements in ns
    parameter real TSU      = 3.0,
    parameter real TH       = 1.0,
    parameter real TREC     = 5.0,
    parameter real TW_CLK_H = 4.0,
    parameter real TW_CLK_L = 5.0,
    parameter real TW_CLR   = 5.0
) (
    input  wire CLR_n,
    input  wire CLK,
    input  wire D,
    output wire Q,
    output wire Q_n
);

    logic q_int;
    reg   notifier;

    always @(posedge CLK or negedge CLR_n) begin
        if (!CLR_n)
            q_int <= 1'b0;
        else
            q_int <= D;
    end

    always @(notifier) q_int <= 1'bx;

    assign Q   =  q_int;
    assign Q_n = ~q_int;

    specify
        specparam tplh     = TPLH;
        specparam tphl     = TPHL;
        specparam tplh_clr = TPLH_CLR;
        specparam tphl_clr = TPHL_CLR;
        specparam tsu      = TSU;
        specparam th       = TH;
        specparam trec     = TREC;
        specparam tw_clk_h = TW_CLK_H;
        specparam tw_clk_l = TW_CLK_L;
        specparam tw_clr   = TW_CLR;

        (posedge CLK => (Q   +: D)) = (tplh, tphl);
        (posedge CLK => (Q_n -: D)) = (tplh, tphl);

        (CLR_n => Q)   = tphl_clr;
        (CLR_n => Q_n) = tplh_clr;

        $setuphold(posedge CLK, D, tsu, th, notifier);

        $recovery(posedge CLR_n, posedge CLK, trec, notifier);

        $width(posedge CLK,   tw_clk_h, 0, notifier);
        $width(negedge CLK,   tw_clk_l, 0, notifier);
        $width(negedge CLR_n, tw_clr,   0, notifier);
    endspecify

endmodule

`default_nettype wire
