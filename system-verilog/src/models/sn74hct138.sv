`timescale 1ns / 1ps
`default_nettype none

module sn74hct138 #(
    // max propagation delay times in ns
    parameter real TPLH    = 36.0,
    parameter real TPHL    = 36.0,
    parameter real TPLH_EN = 33.0,
    parameter real TPHL_EN = 33.0
) (
    input  wire       G1,
    input  wire       G2A_n,
    input  wire       G2B_n,
    input  wire [2:0] A,
    output wire [7:0] Y
);

    wire enable = G1 & ~G2A_n & ~G2B_n;

    assign Y = enable ? ~(8'b1 << A) : 8'hFF;

    specify
        specparam tplh    = TPLH;
        specparam tphl    = TPHL;
        specparam tplh_en = TPLH_EN;
        specparam tphl_en = TPHL_EN;

        if (enable) (A *> Y) = (tplh, tphl);
        ifnone      (A *> Y) = (tplh, tphl);
        
        (G1    *> Y) = (tplh_en, tphl_en);
        (G2A_n *> Y) = (tplh_en, tphl_en);
        (G2B_n *> Y) = (tplh_en, tphl_en);
    endspecify

endmodule

`default_nettype wire
