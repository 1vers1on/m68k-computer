`timescale 1ns / 1ps
`default_nettype none

module cd74hct164 #(
    // max propagation delay times in ns
    parameter real TPD_CP = 54.0,
    parameter real TPD_MR = 57.0,

    // timing requirements in ns
    parameter real TW_CP = 27.0,
    parameter real TW_MR = 27.0,
    parameter real TSU   = 18.0,
    parameter real TH    = 4.0,
    parameter real TREC  = 24.0
) (
    input  wire       A,
    input  wire       B,
    input  wire       CP,
    input  wire       MR_n,
    output wire [7:0] Q
);

    logic [7:0] q_int;
    reg         notifier;

    always @(posedge CP or negedge MR_n) begin
        if (!MR_n) q_int <= 8'b0;
        else       q_int <= {q_int[6:0], A & B};
    end

    always @(notifier) q_int <= 8'bx;

    assign Q = q_int;

    specify
        specparam tpd_cp = TPD_CP;
        specparam tpd_mr = TPD_MR;
        specparam tw_cp  = TW_CP;
        specparam tw_mr  = TW_MR;
        specparam tsu    = TSU;
        specparam th     = TH;
        specparam trec   = TREC;

        (CP *> Q)   = tpd_cp;
        (MR_n *> Q) = tpd_mr;

        $width(posedge CP, tw_cp, 0, notifier);
        $width(negedge CP, tw_cp, 0, notifier);
        $width(negedge MR_n, tw_mr, 0, notifier);
        $setuphold(posedge CP, A, tsu, th, notifier);
        $setuphold(posedge CP, B, tsu, th, notifier);
        $recovery(posedge MR_n, posedge CP, trec, notifier);
    endspecify

endmodule

`default_nettype wire
