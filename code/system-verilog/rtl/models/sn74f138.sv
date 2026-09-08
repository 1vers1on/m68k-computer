`timescale 1ns / 1ps
`default_nettype none

module sn74f138 #(
    // max propagation delay times in ns
    parameter real TPLH_A  = 8.5,
    parameter real TPHL_A  = 9.0,
    parameter real TPLH_G2 = 8.0,
    parameter real TPHL_G2 = 7.5,
    parameter real TPLH_G1 = 9.0,
    parameter real TPHL_G1 = 8.5
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
        specparam tplh_a  = TPLH_A;
        specparam tphl_a  = TPHL_A;
        specparam tplh_g2 = TPLH_G2;
        specparam tphl_g2 = TPHL_G2;
        specparam tplh_g1 = TPLH_G1;
        specparam tphl_g1 = TPHL_G1;

        if (enable) (A *> Y) = (tplh_a, tphl_a);
        ifnone      (A *> Y) = (tplh_a, tphl_a);

        (G2A_n *> Y) = (tplh_g2, tphl_g2);
        (G2B_n *> Y) = (tplh_g2, tphl_g2);
        (G1    *> Y) = (tplh_g1, tphl_g1);
    endspecify

endmodule

`default_nettype wire
