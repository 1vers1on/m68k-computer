`timescale 1ns / 1ps
`default_nettype none

module cd74hct4040 #(
    // max propagation delay times in ns
    parameter real TPD_CP = 40.0,
    parameter real TPD_Q  = 15.0,
    parameter real TPD_MR = 40.0,

    // timing requirements in ns
    parameter real TW_CP  = 20.0,
    parameter real TW_MR  = 20.0,
    parameter real TREC   = 10.0
) (
    input  wire        CP,
    input  wire        MR,
    output wire [12:1] Q
);

    logic [12:1] q_int;
    wire  [12:1] clk;
    reg          notifier;

    assign clk[1]    = CP;
    assign clk[12:2] = q_int[11:1];

    genvar i;
    generate
        for (i = 1; i <= 12; i = i + 1) begin : stage
            always @(negedge clk[i] or posedge MR) begin
                if (MR) q_int[i] <= 1'b0;
                else    q_int[i] <= ~q_int[i];
            end
        end
    endgenerate

    always @(notifier) q_int <= 12'bx;

    assign Q = q_int;

    specify
        specparam tpd_q  = TPD_CP + 11 * TPD_Q;
        specparam tpd_mr = TPD_MR;
        specparam tw_cp  = TW_CP;
        specparam tw_mr  = TW_MR;
        specparam trec   = TREC;

        (CP *> Q) = tpd_q;

        (MR *> Q) = tpd_mr;

        $width(posedge CP, tw_cp, 0, notifier);
        $width(negedge CP, tw_cp, 0, notifier);
        $width(posedge MR, tw_mr, 0, notifier);

        $recovery(negedge MR, negedge CP, trec, notifier);
    endspecify

endmodule

`default_nettype wire
