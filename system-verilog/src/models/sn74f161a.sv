`timescale 1ns / 1ps
`default_nettype none

module sn74f161a #(
    // max propagation delay times in ns
    parameter real TPLH_CNT  =  7.5,
    parameter real TPHL_CNT  = 10.0,
    parameter real TPLH_LD   =  8.5,
    parameter real TPHL_LD   =  8.5,
    parameter real TPLH_RCO  = 14.0,
    parameter real TPHL_RCO  = 14.0,
    parameter real TPLH_ENT  =  7.5,
    parameter real TPHL_ENT  =  7.5,
    parameter real TPHL_CLR  = 12.0,
    parameter real TPHL_CLRR = 10.5,

    // timing requirements in ns
    parameter real TSU_D     =  5.0,
    parameter real TSU_LD_H  = 11.0,
    parameter real TSU_LD_L  =  8.5,
    parameter real TSU_EN_H  = 11.0,
    parameter real TSU_EN_L  =  5.0,
    parameter real TH_D      =  2.0,
    parameter real TH_LD_H   =  2.0,
    parameter real TH_LD_L   =  0.0,
    parameter real TH_EN     =  0.0,
    parameter real TREC      =  6.0,
    parameter real TW_CLK_H  =  5.0,
    parameter real TW_CLK_L  =  6.0,
    parameter real TW_CLR    =  5.0
) (
    input  wire       CLR_n,
    input  wire       LOAD_n,
    input  wire       ENP,
    input  wire       ENT,
    input  wire       CLK,
    input  wire [3:0] D,
    output wire [3:0] Q,
    output wire       RCO
);

    logic [3:0] q_int;
    reg         notifier;

    always @(posedge CLK or negedge CLR_n) begin
        if (!CLR_n)
            q_int <= 4'b0;
        else if (!LOAD_n)
            q_int <= D;
        else if (ENP && ENT)
            q_int <= q_int + 4'b1;
    end

    always @(notifier) q_int <= 4'bx;

    wire rco_int = ENT && (q_int == 4'hF);

    assign Q   = q_int;
    assign RCO = rco_int;

    specify
        specparam tplh_cnt  = TPLH_CNT;
        specparam tphl_cnt  = TPHL_CNT;
        specparam tplh_ld   = TPLH_LD;
        specparam tphl_ld   = TPHL_LD;
        specparam tplh_rco  = TPLH_RCO;
        specparam tphl_rco  = TPHL_RCO;
        specparam tplh_ent  = TPLH_ENT;
        specparam tphl_ent  = TPHL_ENT;
        specparam tphl_clr  = TPHL_CLR;
        specparam tphl_clrr = TPHL_CLRR;
        specparam tsu_d     = TSU_D;
        specparam tsu_ld_h  = TSU_LD_H;
        specparam tsu_ld_l  = TSU_LD_L;
        specparam tsu_en_h  = TSU_EN_H;
        specparam tsu_en_l  = TSU_EN_L;
        specparam th_d      = TH_D;
        specparam th_ld_h   = TH_LD_H;
        specparam th_ld_l   = TH_LD_L;
        specparam th_en     = TH_EN;
        specparam trec      = TREC;
        specparam tw_clk_h  = TW_CLK_H;
        specparam tw_clk_l  = TW_CLK_L;
        specparam tw_clr    = TW_CLR;

        if ( LOAD_n) (posedge CLK *> Q) = (tplh_cnt, tphl_cnt);
        if (!LOAD_n) (posedge CLK *> Q) = (tplh_ld,  tphl_ld);

        (posedge CLK => RCO) = (tplh_rco, tphl_rco);

        (ENT => RCO) = (tplh_ent, tphl_ent);

        (CLR_n *> Q)   = tphl_clr;
        (CLR_n => RCO) = tphl_clrr;

        $setuphold(posedge CLK, D, tsu_d, th_d, notifier);

        $setuphold(posedge CLK, posedge LOAD_n, tsu_ld_h, th_ld_h, notifier);
        $setuphold(posedge CLK, negedge LOAD_n, tsu_ld_l, th_ld_l, notifier);

        $setuphold(posedge CLK, posedge ENP, tsu_en_h, th_en, notifier);
        $setuphold(posedge CLK, negedge ENP, tsu_en_l, th_en, notifier);
        $setuphold(posedge CLK, posedge ENT, tsu_en_h, th_en, notifier);
        $setuphold(posedge CLK, negedge ENT, tsu_en_l, th_en, notifier);

        $recovery(posedge CLR_n, posedge CLK, trec, notifier);

        $width(posedge CLK,   tw_clk_h, 0, notifier);
        $width(negedge CLK,   tw_clk_l, 0, notifier);
        $width(negedge CLR_n, tw_clr,   0, notifier);
    endspecify

endmodule

`default_nettype wire
