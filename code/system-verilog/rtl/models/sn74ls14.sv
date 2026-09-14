`timescale 1ns / 1ps
`default_nettype none

module sn74ls14 #(
    // max propagation delay times in ns
    parameter real TPLH = 22.0,
    parameter real TPHL = 22.0
) (
    input  wire A,
    output wire Y
);

    assign Y = ~A;

    specify
        specparam tplh = TPLH;
        specparam tphl = TPHL;

        (A => Y) = (tplh, tphl);
    endspecify

endmodule

`default_nettype wire
