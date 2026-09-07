`timescale 1ns / 1ps
`default_nettype none

module sn74f74 #(
    // max propagation delay times in ns
    parameter real TPLH     = 6.8,
    parameter real TPHL     = 8.0,
    parameter real TPLH_ASY = 6.1,
    parameter real TPHL_ASY = 9.0,

    // timing requirements in ns
    parameter real TSU_H    = 2.0,
    parameter real TSU_L    = 3.0,
    parameter real TH       = 1.0,
    parameter real TREC     = 2.0,
    parameter real TW_CLK_H = 4.0,
    parameter real TW_CLK_L = 5.0,
    parameter real TW_ASY   = 4.0
) (
    input  wire PRE_n,
    input  wire CLR_n,
    input  wire CLK,
    input  wire D,
    output wire Q,
    output wire Q_n
);

    logic q_int;
    logic qn_int;
    reg   notifier;

    always @(posedge CLK or negedge PRE_n or negedge CLR_n) begin
        if (!PRE_n && !CLR_n) begin
            q_int  <= 1'b1;
            qn_int <= 1'b1;
        end else if (!PRE_n) begin
            q_int  <= 1'b1;
            qn_int <= 1'b0;
        end else if (!CLR_n) begin
            q_int  <= 1'b0;
            qn_int <= 1'b1;
        end else begin
            q_int  <= D;
            qn_int <= ~D;
        end
    end

    always @(posedge PRE_n or posedge CLR_n) begin
        if (PRE_n && !CLR_n) begin
            q_int  <= 1'b0;
            qn_int <= 1'b1;
        end else if (!PRE_n && CLR_n) begin
            q_int  <= 1'b1;
            qn_int <= 1'b0;
        end
    end

    always @(notifier) begin
        q_int  <= 1'bx;
        qn_int <= 1'bx;
    end

    assign Q   = q_int;
    assign Q_n = qn_int;

    specify
        specparam tplh     = TPLH;
        specparam tphl     = TPHL;
        specparam tplh_asy = TPLH_ASY;
        specparam tphl_asy = TPHL_ASY;
        specparam tsu_h    = TSU_H;
        specparam tsu_l    = TSU_L;
        specparam th       = TH;
        specparam trec     = TREC;
        specparam tw_clk_h = TW_CLK_H;
        specparam tw_clk_l = TW_CLK_L;
        specparam tw_asy   = TW_ASY;

        (posedge CLK => (Q   +: D)) = (tplh, tphl);
        (posedge CLK => (Q_n -: D)) = (tplh, tphl);

        (PRE_n => Q)   = (tplh_asy, tphl_asy);
        (PRE_n => Q_n) = (tplh_asy, tphl_asy);
        (CLR_n => Q)   = (tplh_asy, tphl_asy);
        (CLR_n => Q_n) = (tplh_asy, tphl_asy);

        $setuphold(posedge CLK, posedge D, tsu_h, th, notifier);
        $setuphold(posedge CLK, negedge D, tsu_l, th, notifier);

        $recovery(posedge PRE_n, posedge CLK, trec, notifier);
        $recovery(posedge CLR_n, posedge CLK, trec, notifier);

        $width(posedge CLK,   tw_clk_h, 0, notifier);
        $width(negedge CLK,   tw_clk_l, 0, notifier);
        $width(negedge PRE_n, tw_asy,   0, notifier);
        $width(negedge CLR_n, tw_asy,   0, notifier);
    endspecify

endmodule

`default_nettype wire
