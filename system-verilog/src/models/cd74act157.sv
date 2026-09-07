`timescale 1ns / 1ps
`default_nettype none

module cd74act157 #(
    // max propagation delay times in ns
    parameter real TPLH_D = 8.6,
    parameter real TPHL_D = 8.6,
    parameter real TPLH_S = 13.2,
    parameter real TPHL_S = 13.2,
    parameter real TPLH_G = 12.3,
    parameter real TPHL_G = 12.3
) (
    input  wire G_n,
    input  wire SEL,
    input  wire A,
    input  wire B,
    output wire Y
);

    assign Y = G_n ? 1'b0 : (SEL ? B : A);

    specify
        specparam tplh_d = TPLH_D;
        specparam tphl_d = TPHL_D;
        specparam tplh_s = TPLH_S;
        specparam tphl_s = TPHL_S;
        specparam tplh_g = TPLH_G;
        specparam tphl_g = TPHL_G;

        if (!G_n && !SEL) (A => Y) = (tplh_d, tphl_d);
        if (!G_n &&  SEL) (B => Y) = (tplh_d, tphl_d);
        ifnone            (A => Y) = (tplh_d, tphl_d);
        ifnone            (B => Y) = (tplh_d, tphl_d);

        if (!G_n) (SEL => Y) = (tplh_s, tphl_s);
        ifnone    (SEL => Y) = (tplh_s, tphl_s);

        (G_n => Y) = (tplh_g, tphl_g);
    endspecify

endmodule

`default_nettype wire
