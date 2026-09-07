`timescale 1ns / 1ps
`default_nettype none

module cd74act244 #(
    // max propagation delay times in ns
    parameter real TPLH = 8.7,
    parameter real TPHL = 8.7,
    parameter real TPZH = 12.2,
    parameter real TPZL = 12.2,
    parameter real TPHZ = 12.2,
    parameter real TPLZ = 12.2
) (
    input  wire OE_n,
    input  wire A,
    output wire Y
);

    bufif0 u_buf (Y, A, OE_n);

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;
        specparam tpzh = TPZH;
        specparam tpzl = TPZL;
        specparam tphz = TPHZ;
        specparam tplz = TPLZ;

        if (!OE_n) (A => Y) = (tplh, tphl);
        (OE_n => Y) = (tplh, tphl, tplz, tpzh, tphz, tpzl);
    endspecify

endmodule

`default_nettype wire
