`timescale 1ns / 1ps
`default_nettype none

// Philips/NXP 74F194 4-bit bidirectional universal shift register.
module philips_74f194 #(
    // max propagation delay times in ns
    parameter real TPLH    =  7.0,
    parameter real TPHL    =  7.0,
    parameter real TPHL_MR = 12.0,

    // timing requirements in ns
    parameter real TSU_D   =  4.0,
    parameter real TSU_S   =  8.0,
    parameter real TH_D    =  0.0,
    parameter real TH_S    =  0.0,
    parameter real TREC    =  7.0,
    parameter real TW_CP   =  5.0,
    parameter real TW_MR   =  5.0
) (
    input  wire       MR_n,
    input  wire       CP,
    input  wire       S0,
    input  wire       S1,
    input  wire       DSR,
    input  wire       DSL,
    input  wire [3:0] D,
    output wire [3:0] Q
);

    logic [3:0] q_int;
    reg         notifier;

    always @(posedge CP or negedge MR_n) begin
        if (!MR_n)
            q_int <= 4'b0;
        else
            case ({S1, S0})
                2'b01:   q_int <= {q_int[2:0], DSR};
                2'b10:   q_int <= {DSL, q_int[3:1]};
                2'b11:   q_int <= D;
                default: ;
            endcase
    end

    always @(notifier) q_int <= 4'bx;

    assign Q = q_int;

    specify
        specparam tplh    = TPLH;
        specparam tphl    = TPHL;
        specparam tphl_mr = TPHL_MR;
        specparam tsu_d   = TSU_D;
        specparam tsu_s   = TSU_S;
        specparam th_d    = TH_D;
        specparam th_s    = TH_S;
        specparam trec    = TREC;
        specparam tw_cp   = TW_CP;
        specparam tw_mr   = TW_MR;

        (posedge CP *> Q) = (tplh, tphl);

        (MR_n *> Q) = tphl_mr;

        $setuphold(posedge CP, D,   tsu_d, th_d, notifier);
        $setuphold(posedge CP, DSR, tsu_d, th_d, notifier);
        $setuphold(posedge CP, DSL, tsu_d, th_d, notifier);
        $setuphold(posedge CP, S0,  tsu_s, th_s, notifier);
        $setuphold(posedge CP, S1,  tsu_s, th_s, notifier);

        $recovery(posedge MR_n, posedge CP, trec, notifier);

        $width(posedge CP,   tw_cp, 0, notifier);
        $width(negedge CP,   tw_cp, 0, notifier);
        $width(negedge MR_n, tw_mr, 0, notifier);
    endspecify

endmodule

`default_nettype wire
