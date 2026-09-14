`timescale 1ns / 1ps
`default_nettype none

module sn74ahct74 #(
    // max propagation delay times in ns
    parameter real TPLH_CLK = 10.0,
    parameter real TPHL_CLK = 10.0,
    parameter real TPLH_CTL = 13.0,
    parameter real TPHL_CTL = 13.0,

    // timing requirements in ns
    parameter real TW_CLK   = 5.0,
    parameter real TW_PRE   = 5.0,
    parameter real TW_CLR   = 5.0,
    parameter real TSU_D    = 5.0,
    parameter real TH_D     = 0.0,
    parameter real TREC     = 3.5
) (
    input  wire PRE_n,
    input  wire CLR_n,
    input  wire CLK,
    input  wire D,
    output wire Q,
    output wire Q_n
);

    logic q_int;
    logic q_n_int;
    reg   notifier;

    always @(posedge CLK or negedge PRE_n or negedge CLR_n) begin
        if (!PRE_n && !CLR_n) begin
            q_int   <= 1'b1;
            q_n_int <= 1'b1;
        end else if (!CLR_n) begin
            q_int   <= 1'b0;
            q_n_int <= 1'b1;
        end else if (!PRE_n) begin
            q_int   <= 1'b1;
            q_n_int <= 1'b0;
        end else begin
            q_int   <= D;
            q_n_int <= ~D;
        end
    end

    always @(notifier) begin
        q_int   <= 1'bx;
        q_n_int <= 1'bx;
    end

    assign Q   = q_int;
    assign Q_n = q_n_int;

    specify
        specparam tplh_clk = TPLH_CLK;
        specparam tphl_clk = TPHL_CLK;
        specparam tplh_ctl = TPLH_CTL;
        specparam tphl_ctl = TPHL_CTL;
        specparam tw_clk   = TW_CLK;
        specparam tw_pre   = TW_PRE;
        specparam tw_clr   = TW_CLR;
        specparam tsu_d    = TSU_D;
        specparam th_d     = TH_D;
        specparam trec     = TREC;

        (CLK => Q)     = (tplh_clk, tphl_clk);
        (CLK => Q_n)   = (tplh_clk, tphl_clk);
        (PRE_n => Q)   = (tplh_ctl, tphl_ctl);
        (PRE_n => Q_n) = (tplh_ctl, tphl_ctl);
        (CLR_n => Q)   = (tplh_ctl, tphl_ctl);
        (CLR_n => Q_n) = (tplh_ctl, tphl_ctl);

        $width(posedge CLK, tw_clk, 0, notifier);
        $width(negedge CLK, tw_clk, 0, notifier);
        $width(negedge PRE_n, tw_pre, 0, notifier);
        $width(negedge CLR_n, tw_clr, 0, notifier);
        $setuphold(posedge CLK, D, tsu_d, th_d, notifier);
        $recovery(posedge PRE_n, posedge CLK, trec, notifier);
        $recovery(posedge CLR_n, posedge CLK, trec, notifier);
    endspecify

endmodule

`default_nettype wire
