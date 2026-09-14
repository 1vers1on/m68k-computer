`timescale 1ns / 1ps
`default_nettype none

module sn74hct245 #(
    // max propagation delay times in ns
    parameter real TPLH = 28.0,
    parameter real TPHL = 28.0,
    parameter real TPZH = 58.0,
    parameter real TPZL = 58.0,
    parameter real TPHZ = 50.0,
    parameter real TPLZ = 50.0
) (
    input  wire OE_n,
    input  wire DIR,
    inout  wire A,
    inout  wire B
);

    wire drive_a_to_b;
    wire drive_b_to_a;

    assign drive_a_to_b = !OE_n && DIR;
    assign drive_b_to_a = !OE_n && !DIR;

    assign B = drive_a_to_b ? A : 1'bz;
    assign A = drive_b_to_a ? B : 1'bz;

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;
        specparam tpzh = TPZH;
        specparam tpzl = TPZL;
        specparam tphz = TPHZ;
        specparam tplz = TPLZ;

        if (!OE_n &&  DIR) (A => B) = (tplh, tphl);
        if (!OE_n && !DIR) (B => A) = (tplh, tphl);

        (OE_n => A) = (tplh, tphl, tplz, tpzh, tphz, tpzl);
        (OE_n => B) = (tplh, tphl, tplz, tpzh, tphz, tpzl);
        (DIR => A)  = (tplh, tphl, tplz, tpzh, tphz, tpzl);
        (DIR => B)  = (tplh, tphl, tplz, tpzh, tphz, tpzl);
    endspecify

endmodule

`default_nettype wire
