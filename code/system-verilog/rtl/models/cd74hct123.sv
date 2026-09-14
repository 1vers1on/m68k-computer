`timescale 1ns / 1ps
`default_nettype none

module cd74hct123 #(
    // output pulse width in ns
    parameter real TW = 45000.0,

    // max propagation delay times in ns
    parameter real TPLH_TRIG = 90.0,
    parameter real TPHL_TRIG = 102.0,
    parameter real TPLH_CLR  = 72.0,
    parameter real TPHL_CLR  = 72.0,

    // timing requirements in ns
    parameter real TW_A   = 30.0,
    parameter real TW_B   = 30.0,
    parameter real TW_CLR = 30.0
) (
    input  wire A_n,
    input  wire B,
    input  wire CLR_n,
    output wire Q,
    output wire Q_n
);

    logic   q_int;
    integer generation;
    reg     notifier;

    task automatic trigger_pulse;
        integer token;
        begin
            generation = generation + 1;
            token = generation;
            q_int <= 1'b1;

            fork
                begin
                    #(TW);
                    if (generation == token && CLR_n) q_int <= 1'b0;
                end
            join_none
        end
    endtask

    initial generation = 0;

    always @(negedge A_n) begin
        if (B && CLR_n) trigger_pulse();
    end

    always @(posedge B) begin
        if (!A_n && CLR_n) trigger_pulse();
    end

    always @(posedge CLR_n) begin
        if (!A_n && B) trigger_pulse();
    end

    always @(negedge CLR_n) begin
        generation = generation + 1;
        q_int <= 1'b0;
    end

    always @(notifier) begin
        generation = generation + 1;
        q_int <= 1'bx;
    end

    assign Q   = q_int;
    assign Q_n = ~q_int;

    specify
        specparam tplh_trig = TPLH_TRIG;
        specparam tphl_trig = TPHL_TRIG;
        specparam tplh_clr  = TPLH_CLR;
        specparam tphl_clr  = TPHL_CLR;
        specparam tw_a      = TW_A;
        specparam tw_b      = TW_B;
        specparam tw_clr    = TW_CLR;

        (A_n => Q)     = (tplh_trig, tphl_trig);
        (A_n => Q_n)   = (tplh_trig, tphl_trig);
        (B => Q)       = (tplh_trig, tphl_trig);
        (B => Q_n)     = (tplh_trig, tphl_trig);
        (CLR_n => Q)   = (tplh_clr, tphl_clr);
        (CLR_n => Q_n) = (tplh_clr, tphl_clr);

        $width(negedge A_n, tw_a, 0, notifier);
        $width(posedge B, tw_b, 0, notifier);
        $width(negedge CLR_n, tw_clr, 0, notifier);
    endspecify

endmodule

`default_nettype wire
