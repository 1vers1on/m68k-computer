`timescale 1ns / 1ps
`default_nettype none

// Fairchild 74F191 4-bit synchronous up/down counter,
// asynchronous transparent parallel load.
module fairchild_74f191 #(
    // max propagation delay times in ns
    parameter real TPLH_Q     =  8.0,
    parameter real TPHL_Q     =  9.0,
    parameter real TPLH_TC    = 10.0,
    parameter real TPHL_TC    = 12.0,
    parameter real TPLH_RC    =  7.0,
    parameter real TPHL_RC    =  7.0,
    parameter real TPLH_CE_RC =  6.0,
    parameter real TPHL_CE_RC =  6.0,
    parameter real TPLH_UD_RC = 16.0,
    parameter real TPHL_UD_RC = 12.0,
    parameter real TPLH_UD_TC =  9.0,
    parameter real TPHL_UD_TC =  9.0,
    parameter real TPLH_P     =  6.0,
    parameter real TPHL_P     = 10.0,
    parameter real TPLH_PL    =  9.0,
    parameter real TPHL_PL    = 10.0,

    // timing requirements in ns
    parameter real TSU_P      =  5.0,
    parameter real TH_P       =  3.0,
    parameter real TSU_CE     = 10.0,
    parameter real TH_CE      =  0.0,
    parameter real TREC       =  6.0,
    parameter real TW_PL      =  5.0,
    parameter real TW_CP      =  5.5
) (
    input  wire       PL_n,
    input  wire       CE_n,
    input  wire       UD_n,
    input  wire       CP,
    input  wire [3:0] P,
    output wire [3:0] Q,
    output wire       TC,
    output wire       RC_n
);

    logic [3:0] q_int;
    reg         notifier;

    always @(posedge CP or negedge PL_n) begin
        if (!PL_n)
            q_int <= P;
        else if (!CE_n)
            q_int <= UD_n ? q_int - 4'b1 : q_int + 4'b1;
    end

    always @(P) begin
        if (!PL_n)
            q_int <= P;
    end

    always @(notifier) q_int <= 4'bx;

    wire tc_int = UD_n ? (q_int == 4'h0) : (q_int == 4'hF);
    wire rc_int = ~(tc_int && !CE_n && !CP);

    assign Q    = q_int;
    assign TC   = tc_int;
    assign RC_n = rc_int;

    specify
        specparam tplh_q     = TPLH_Q;
        specparam tphl_q     = TPHL_Q;
        specparam tplh_tc    = TPLH_TC;
        specparam tphl_tc    = TPHL_TC;
        specparam tplh_rc    = TPLH_RC;
        specparam tphl_rc    = TPHL_RC;
        specparam tplh_ce_rc = TPLH_CE_RC;
        specparam tphl_ce_rc = TPHL_CE_RC;
        specparam tplh_ud_rc = TPLH_UD_RC;
        specparam tphl_ud_rc = TPHL_UD_RC;
        specparam tplh_ud_tc = TPLH_UD_TC;
        specparam tphl_ud_tc = TPHL_UD_TC;
        specparam tplh_p     = TPLH_P;
        specparam tphl_p     = TPHL_P;
        specparam tplh_pl    = TPLH_PL;
        specparam tphl_pl    = TPHL_PL;
        specparam tsu_p      = TSU_P;
        specparam th_p       = TH_P;
        specparam tsu_ce     = TSU_CE;
        specparam th_ce      = TH_CE;
        specparam trec       = TREC;
        specparam tw_pl      = TW_PL;
        specparam tw_cp      = TW_CP;

        (posedge CP *> Q)  = (tplh_q,  tphl_q);
        (posedge CP => TC) = (tplh_tc, tphl_tc);

        (CP   => RC_n) = (tplh_rc,    tphl_rc);
        (CE_n => RC_n) = (tplh_ce_rc, tphl_ce_rc);
        (UD_n => RC_n) = (tplh_ud_rc, tphl_ud_rc);
        (UD_n => TC)   = (tplh_ud_tc, tphl_ud_tc);

        if (!PL_n) (P *> Q) = (tplh_p, tphl_p);
        ifnone     (P *> Q) = (tplh_p, tphl_p);
        (PL_n *> Q) = (tplh_pl, tphl_pl);

        $setuphold(posedge PL_n, P, tsu_p, th_p, notifier);

        $setuphold(posedge CP, CE_n, tsu_ce, th_ce, notifier);

        $recovery(posedge PL_n, posedge CP, trec, notifier);

        $width(negedge PL_n, tw_pl, 0, notifier);
        $width(posedge CP,   tw_cp, 0, notifier);
        $width(negedge CP,   tw_cp, 0, notifier);
    endspecify

endmodule

`default_nettype wire
