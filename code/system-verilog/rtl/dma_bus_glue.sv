`timescale 1ns / 1ps
`default_nettype none

// Corrected arbitration, expansion data enables, and CPU register completion.
// Scalar instances describe gate channels; see dma.html and expansion.html
// for package allocation. This module does not model the MC68450 itself.
module dma_bus_glue (
    input wire RESET_n, CPU_CLK_10,
    input wire DMA_BR_n, OWN_n, AS_n, UDS_n, LDS_n,
    input wire EXP1_RW, EXP2_RW, ACK2_n, ACK3_n,
    input wire EXP1_CYCLE_n, EXP2_CYCLE_n,
    input wire DMAC_CS_n, DMAC_DTACK_RAW_n,
    output wire CPU_BR_n,
    output wire EXP1_LOW_DIR, EXP2_LOW_DIR,
    output wire EXP1_LOW_OE_n, EXP2_LOW_OE_n,
    output wire EXP1_HIGH_OE_n, EXP2_HIGH_OE_n,
    output wire DMAC_DTACK_n
);
    wire OWN_ACTIVE, DS_INACTIVE, CYCLE_END;
    wire [1:0] SLOT_MASK, SLOT_DMA_n;
    wire REG_CLEAR_n, REG_RESET, REG_END, REG_INVALID;
    wire REG_ARM1, REG_ARM2, REG_ARM2_n, REG_MASKED_ACK;

    // The EC000 has BR/BG arbitration. Hold BR until the DMAC releases OWN,
    // including the interval after it has negated its own BR output.
    sn74f08 U_DMA_BR_HOLD (.A(DMA_BR_n), .B(OWN_n), .Y(CPU_BR_n));
    sn74hct04 U_OWNER_INV (.A(OWN_n), .Y(OWN_ACTIVE));
    sn74f08 U_DS_INACTIVE (.A(UDS_n), .B(LDS_n), .Y(DS_INACTIVE));
    sn74f32 U_CYCLE_END (.A(AS_n), .B(DS_INACTIVE), .Y(CYCLE_END));

    sn74f86 U_EXP_DMA_DIR_1 (.A(EXP1_RW), .B(OWN_ACTIVE), .Y(EXP1_LOW_DIR));
    sn74f86 U_EXP_DMA_DIR_2 (.A(EXP2_RW), .B(OWN_ACTIVE), .Y(EXP2_LOW_DIR));
    sn74f32 U_SLOT_MASK_1 (.A(ACK2_n), .B(OWN_n), .Y(SLOT_MASK[0]));
    sn74f32 U_SLOT_MASK_2 (.A(ACK3_n), .B(OWN_n), .Y(SLOT_MASK[1]));
    sn74f32 U_SLOT_DMA_1 (.A(SLOT_MASK[0]), .B(CYCLE_END), .Y(SLOT_DMA_n[0]));
    sn74f32 U_SLOT_DMA_2 (.A(SLOT_MASK[1]), .B(CYCLE_END), .Y(SLOT_DMA_n[1]));
    sn74f08 U_SLOT_OE_1 (.A(EXP1_CYCLE_n), .B(SLOT_DMA_n[0]), .Y(EXP1_LOW_OE_n));
    sn74f08 U_SLOT_OE_2 (.A(EXP2_CYCLE_n), .B(SLOT_DMA_n[1]), .Y(EXP2_LOW_OE_n));
    assign EXP1_HIGH_OE_n = EXP1_CYCLE_n;
    assign EXP2_HIGH_OE_n = EXP2_CYCLE_n;

    // Raw strobes clear the two-stage arm circuit between CPU cycles. Its
    // minimum one-clock assertion delay prevents the preceding register ACK
    // from acknowledging a new cycle during the source's slow release.
    sn74f04 U_REG_RESET (.A(RESET_n), .Y(REG_RESET));
    sn74f32 U_REG_END (.A(DMAC_CS_n), .B(CYCLE_END), .Y(REG_END));
    sn74f32 U_REG_INVALID (.A(REG_END), .B(REG_RESET), .Y(REG_INVALID));
    sn74f04 U_REG_CLEAR (.A(REG_INVALID), .Y(REG_CLEAR_n));
    sn74f74 U_REG_ARM_1 (.PRE_n(1'b1), .CLR_n(REG_CLEAR_n),
        .CLK(CPU_CLK_10), .D(1'b1), .Q(REG_ARM1), .Q_n());
    sn74f74 U_REG_ARM_2 (.PRE_n(1'b1), .CLR_n(REG_CLEAR_n),
        .CLK(CPU_CLK_10), .D(REG_ARM1), .Q(REG_ARM2), .Q_n(REG_ARM2_n));
    sn74f32 U_REG_MASK (.A(DMAC_DTACK_RAW_n), .B(REG_ARM2_n), .Y(REG_MASKED_ACK));
    sn74f32 U_REG_RELEASE (.A(REG_MASKED_ACK), .B(REG_INVALID), .Y(DMAC_DTACK_n));
endmodule

`default_nettype wire
