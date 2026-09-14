`timescale 1ns / 1ps
`default_nettype none

module sn74ls390 #(
    // max propagation delay times in ns
    parameter real TPD_CLKA = 28.0,
    parameter real TPD_CLKB = 63.0,
    parameter real TPD_CLR  = 35.0,

    // timing requirements in ns
    parameter real TW_CLKA = 15.0,
    parameter real TW_CLKB = 15.0,
    parameter real TW_CLR  = 15.0,
    parameter real TREC    = 25.0
) (
    input  wire       CLKA,
    input  wire       CLKB,
    input  wire       CLR,
    output wire [3:0] Q
);

    logic       q_a;
    logic [2:0] q_bcd;
    reg         notifier;

    always @(negedge CLKA or posedge CLR) begin
        if (CLR) q_a <= 1'b0;
        else     q_a <= ~q_a;
    end

    always @(negedge CLKB or posedge CLR) begin
        if (CLR) begin
            q_bcd <= 3'b000;
        end else if (q_bcd == 3'd4) begin
            q_bcd <= 3'b000;
        end else begin
            q_bcd <= q_bcd + 3'd1;
        end
    end

    always @(notifier) begin
        q_a   <= 1'bx;
        q_bcd <= 3'bx;
    end

    assign Q = {q_bcd, q_a};

    specify
        specparam tpd_clka = TPD_CLKA;
        specparam tpd_clkb = TPD_CLKB;
        specparam tpd_clr  = TPD_CLR;
        specparam tw_clka  = TW_CLKA;
        specparam tw_clkb  = TW_CLKB;
        specparam tw_clr   = TW_CLR;
        specparam trec     = TREC;

        (CLKA => Q[0]) = tpd_clka;
        (CLKB *> Q[3:1]) = tpd_clkb;
        (CLR *> Q) = tpd_clr;

        $width(posedge CLKA, tw_clka, 0, notifier);
        $width(negedge CLKA, tw_clka, 0, notifier);
        $width(posedge CLKB, tw_clkb, 0, notifier);
        $width(negedge CLKB, tw_clkb, 0, notifier);
        $width(posedge CLR, tw_clr, 0, notifier);
        $recovery(negedge CLR, negedge CLKA, trec, notifier);
        $recovery(negedge CLR, negedge CLKB, trec, notifier);
    endspecify

endmodule

`default_nettype wire
