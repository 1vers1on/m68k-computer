`timescale 1ns / 1ps
`default_nettype none

module cd74act373 #(
    // max propagation delay times in ns
    parameter real TPLH_D = 10.4,
    parameter real TPHL_D = 10.4,
    parameter real TPLH_LE = 12.5,
    parameter real TPHL_LE = 12.5,
    parameter real TPZH = 13.5,
    parameter real TPZL = 13.5,
    parameter real TPHZ = 12.5,
    parameter real TPLZ = 12.5,

    // timing requirements in ns
    parameter real TW_LE = 4.0,
    parameter real TSU_D = 2.0,
    parameter real TH_D  = 3.0
) (
    input  wire OE_n,
    input  wire LE,
    input  wire D,
    output wire Q
);

    logic q_int;
    reg   notifier;

    always @(D or LE) begin
        if (LE) q_int <= D;
    end

    always @(notifier) q_int <= 1'bx;

    bufif0 u_buf (Q, q_int, OE_n);

    specify
        specparam tplh_d  = TPLH_D;
        specparam tphl_d  = TPHL_D;
        specparam tplh_le = TPLH_LE;
        specparam tphl_le = TPHL_LE;
        specparam tpzh    = TPZH;
        specparam tpzl    = TPZL;
        specparam tphz    = TPHZ;
        specparam tplz    = TPLZ;
        specparam tw_le   = TW_LE;
        specparam tsu_d   = TSU_D;
        specparam th_d    = TH_D;

        if (LE && !OE_n) (D => Q) = (tplh_d, tphl_d);
        if (!OE_n) (LE => Q) = (tplh_le, tphl_le);
        (OE_n => Q) = (tplh_d, tphl_d, tplz, tpzh, tphz, tpzl);

        $width(posedge LE, tw_le, 0, notifier);
        $setuphold(negedge LE, D, tsu_d, th_d, notifier);
    endspecify

endmodule

`default_nettype wire
