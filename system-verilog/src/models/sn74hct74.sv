`timescale 1ns / 1ps
`default_nettype none

module sn74hct74 #(
    // max propagation delay times in ns
    parameter real TPLH     = 28.0,
    parameter real TPHL     = 28.0,
    parameter real TPLH_ASY = 35.0,
    parameter real TPHL_ASY = 35.0,

    // timing requirements in ns
    parameter real TSU      = 12.0,
    parameter real TH       =  0.0,
    parameter real TREC     =  0.0,
    parameter real TW_CLK   = 18.0,
    parameter real TW_ASY   = 16.0
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
        specparam tsu      = TSU;
        specparam th       = TH;
        specparam trec     = TREC;
        specparam tw_clk   = TW_CLK;
        specparam tw_asy   = TW_ASY;

        (posedge CLK => (Q   +: D)) = (tplh, tphl);
        (posedge CLK => (Q_n -: D)) = (tplh, tphl);

        (PRE_n => Q)   = (tplh_asy, tphl_asy);
        (PRE_n => Q_n) = (tplh_asy, tphl_asy);
        (CLR_n => Q)   = (tplh_asy, tphl_asy);
        (CLR_n => Q_n) = (tplh_asy, tphl_asy);

        $setuphold(posedge CLK, D, tsu, th, notifier);

        $recovery(posedge PRE_n, posedge CLK, trec, notifier);
        $recovery(posedge CLR_n, posedge CLK, trec, notifier);

        $width(posedge CLK,   tw_clk, 0, notifier);
        $width(negedge CLK,   tw_clk, 0, notifier);
        $width(negedge PRE_n, tw_asy, 0, notifier);
        $width(negedge CLR_n, tw_asy, 0, notifier);
    endspecify

endmodule

`default_nettype wire
