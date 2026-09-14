`timescale 1ns / 1ps
`default_nettype none

module sn74ls148 #(
    // max propagation delay times in ns
    parameter real TPLH_A_I  = 36.0,
    parameter real TPHL_A_I  = 29.0,
    parameter real TPLH_EO_I = 18.0,
    parameter real TPHL_EO_I = 40.0,
    parameter real TPLH_GS_I = 55.0,
    parameter real TPHL_GS_I = 21.0,
    parameter real TPLH_A_EI = 25.0,
    parameter real TPHL_A_EI = 25.0,
    parameter real TPLH_EO_EI = 21.0,
    parameter real TPHL_EO_EI = 35.0,
    parameter real TPLH_GS_EI = 17.0,
    parameter real TPHL_GS_EI = 36.0
) (
    input  wire [7:0] I_n,
    input  wire       EI_n,
    output wire [2:0] A_n,
    output wire       GS_n,
    output wire       EO_n
);

    logic [2:0] a_int;
    logic       gs_int;
    logic       eo_int;

    always @* begin
        if (EI_n) begin
            a_int  = 3'b111;
            gs_int = 1'b1;
            eo_int = 1'b1;
        end else begin
            gs_int = &I_n;
            eo_int = ~&I_n;

            casez (I_n)
                8'b0???????: a_int = 3'b000;
                8'b10??????: a_int = 3'b001;
                8'b110?????: a_int = 3'b010;
                8'b1110????: a_int = 3'b011;
                8'b11110???: a_int = 3'b100;
                8'b111110??: a_int = 3'b101;
                8'b1111110?: a_int = 3'b110;
                default:     a_int = 3'b111;
            endcase
        end
    end

    assign A_n  = a_int;
    assign GS_n = gs_int;
    assign EO_n = eo_int;

    specify
        specparam tplh_a_i   = TPLH_A_I;
        specparam tphl_a_i   = TPHL_A_I;
        specparam tplh_eo_i  = TPLH_EO_I;
        specparam tphl_eo_i  = TPHL_EO_I;
        specparam tplh_gs_i  = TPLH_GS_I;
        specparam tphl_gs_i  = TPHL_GS_I;
        specparam tplh_a_ei  = TPLH_A_EI;
        specparam tphl_a_ei  = TPHL_A_EI;
        specparam tplh_eo_ei = TPLH_EO_EI;
        specparam tphl_eo_ei = TPHL_EO_EI;
        specparam tplh_gs_ei = TPLH_GS_EI;
        specparam tphl_gs_ei = TPHL_GS_EI;

        (I_n *> A_n)  = (tplh_a_i, tphl_a_i);
        (I_n *> EO_n) = (tplh_eo_i, tphl_eo_i);
        (I_n *> GS_n) = (tplh_gs_i, tphl_gs_i);
        (EI_n *> A_n)  = (tplh_a_ei, tphl_a_ei);
        (EI_n => EO_n) = (tplh_eo_ei, tphl_eo_ei);
        (EI_n => GS_n) = (tplh_gs_ei, tphl_gs_ei);
    endspecify

endmodule

`default_nettype wire
