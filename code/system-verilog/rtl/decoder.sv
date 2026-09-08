`timescale 1ns / 1ps
`default_nettype none

module decoder (
    // CPU bus inputs
    input  wire [23:0] A,
    input  wire [2:0]  FC,
    input  wire        AS_n,
    input  wire        UDS_n,
    input  wire        LDS_n,
    input  wire        R_W,
    input  wire        CLK,
    input  wire        RESET_n,
    input  wire [7:0]  D,

    // Subsystem completion responses (active low)
    input  wire DRAM_DTACK_n,
    input  wire ROM_DTACK_n,
    input  wire MFP_DTACK_n,
    input  wire FDC_DTACK_n,
    input  wire OPL3_DTACK_n,
    input  wire VGA_DTACK_n,
    input  wire MIDI_DTACK_n,
    input  wire RTC_DTACK_n,
    input  wire EXP_DTACK_n,
    input  wire INT_BERR_n,

    // CPU-facing outputs
    output wire DTACK_n,
    output wire BERR_n,

    // Subsystem request / select outputs (active low)
    output wire RAM0_REQ_n,
    output wire RAM1_REQ_n,
    output wire VGA_MEM_n,
    output wire EXP_MEM2_n,
    output wire EXP_MEM3_n,
    output wire EXP_MEM5_n,
    output wire EXP_MEM6_n,
    output wire [15:0] IO_n,
    output wire [7:0]  SYSREG_n,
    output wire ROM_CYCLE_n,
    output wire ROM0_UDS_n,
    output wire ROM0_LDS_n,
    output wire ROM1_UDS_n,
    output wire ROM1_LDS_n,
    output wire READ_n,

    // Debug display and overlay state
    output wire [7:0] DEBUG_Q,
    output wire OVERLAY_EN,
    output wire OVERLAY_n
);

    // CPU space detection (U_AND)
    wire CPU_SPACE_STAGE1;
    wire CPU_SPACE;

    // Normal-cycle qualification
    wire NORMAL_CYCLE_n;
    wire NORMAL_MEM_n;
    wire NORMAL_EXP_n;
    wire NORMAL_MISC_n;

    // Primary region decode (U_PRIMARY)
    wire [7:0] region_n;

    // Top-I/O qualification
    wire TOP_IO_n;

    // System-register write qualification
    wire OVERLAY_WRITE_n;
    wire DEBUG_WRITE_n;
    wire DEBUG_CLK;
    wire SYSREG_ACK_STAGE_n;
    wire SYSREG_DTACK_n;

    // Low-128-KiB and boot-overlay alias
    wire [7:0] low128_y;
    wire LOW128_n;
    wire ROM_ALIAS_ADDR_n;
    wire ROM_ALIAS_n;

    // DRAM bank 0 overlay suppression
    wire ALIAS_ACTIVE;
    wire RAM0_BASE_n;

    // Firmware ROM bank and byte-lane selection
    wire A16_n;
    wire ROM_BANK0_n;
    wire ROM_BANK1_n;

    // DTACK combination tree
    wire DTACK_GROUP0_n;
    wire DTACK_GROUP1_n;
    wire DTACK_GROUP2_n;
    wire DTACK_RAW_n;

    // Bus timeout
    wire [12:1] timeout_q;
    wire TIMEOUT_ACTIVE;
    wire TIMEOUT_BERR_n;

    // ---------------------------------------------------------------------
    // CPU space detection: U_AND (SN74HCT08), gates 1 and 2
    // ---------------------------------------------------------------------
    sn74hct08 u_and_g1 (
        .A  (FC[2]),
        .B  (FC[1]),
        .Y  (CPU_SPACE_STAGE1)
    );

    sn74hct08 u_and_g2 (
        .A  (CPU_SPACE_STAGE1),
        .B  (FC[0]),
        .Y  (CPU_SPACE)
    );

    // ---------------------------------------------------------------------
    // Normal-cycle qualification and distribution
    // ---------------------------------------------------------------------
    sn74hct32 u_or1_g1 (
        .A  (AS_n),
        .B  (CPU_SPACE),
        .Y  (NORMAL_CYCLE_n)
    );

    // U_NORMAL_BUF (SN74HCT244): three buffered copies, output enable tied low
    sn74hct244 u_normal_buf_mem (
        .OE_n (1'b0),
        .A    (NORMAL_CYCLE_n),
        .Y    (NORMAL_MEM_n)
    );

    sn74hct244 u_normal_buf_exp (
        .OE_n (1'b0),
        .A    (NORMAL_CYCLE_n),
        .Y    (NORMAL_EXP_n)
    );

    sn74hct244 u_normal_buf_misc (
        .OE_n (1'b0),
        .A    (NORMAL_CYCLE_n),
        .Y    (NORMAL_MISC_n)
    );

    // ---------------------------------------------------------------------
    // Primary address decoder: U_PRIMARY (SN74HCT138)
    // ---------------------------------------------------------------------
    sn74hct138 u_primary (
        .G1    (1'b1),
        .G2A_n (1'b0),
        .G2B_n (1'b0),
        .A     ({A[23], A[22], A[21]}),
        .Y     (region_n)
    );

    // ---------------------------------------------------------------------
    // Qualified region requests: U_OR1 (gates 2-4) and U_OR5
    // ---------------------------------------------------------------------
    sn74hct32 u_or1_g2 (
        .A  (region_n[1]),
        .B  (NORMAL_MEM_n),
        .Y  (RAM1_REQ_n)
    );

    sn74hct32 u_or1_g3 (
        .A  (region_n[4]),
        .B  (NORMAL_MEM_n),
        .Y  (VGA_MEM_n)
    );

    sn74hct32 u_or1_g4 (
        .A  (region_n[7]),
        .B  (NORMAL_MEM_n),
        .Y  (TOP_IO_n)
    );

    sn74hct32 u_or5_g1 (
        .A  (region_n[2]),
        .B  (NORMAL_EXP_n),
        .Y  (EXP_MEM2_n)
    );

    sn74hct32 u_or5_g2 (
        .A  (region_n[3]),
        .B  (NORMAL_EXP_n),
        .Y  (EXP_MEM3_n)
    );

    sn74hct32 u_or5_g3 (
        .A  (region_n[5]),
        .B  (NORMAL_EXP_n),
        .Y  (EXP_MEM5_n)
    );

    sn74hct32 u_or5_g4 (
        .A  (region_n[6]),
        .B  (NORMAL_EXP_n),
        .Y  (EXP_MEM6_n)
    );

    // ---------------------------------------------------------------------
    // Top I/O slot decoders: U_IO_LOW and U_IO_HIGH (SN74HCT138)
    // ---------------------------------------------------------------------
    sn74hct138 u_io_low (
        .G1    (1'b1),
        .G2A_n (TOP_IO_n),
        .G2B_n (A[20]),
        .A     ({A[19], A[18], A[17]}),
        .Y     (IO_n[7:0])
    );

    sn74hct138 u_io_high (
        .G1    (A[20]),
        .G2A_n (TOP_IO_n),
        .G2B_n (1'b0),
        .A     ({A[19], A[18], A[17]}),
        .Y     (IO_n[15:8])
    );

    // ---------------------------------------------------------------------
    // System register decoder: U_SYSREG (SN74HCT138)
    // ---------------------------------------------------------------------
    sn74hct138 u_sysreg (
        .G1    (1'b1),
        .G2A_n (IO_n[4]),
        .G2B_n (LDS_n),
        .A     ({A[3], A[2], A[1]}),
        .Y     (SYSREG_n)
    );

    // ---------------------------------------------------------------------
    // System register write qualification: U_OR2 (gates 1-2) and U_OR6
    // ---------------------------------------------------------------------
    sn74hct32 u_or2_g1 (
        .A  (SYSREG_n[0]),
        .B  (R_W),
        .Y  (OVERLAY_WRITE_n)
    );

    sn74hct32 u_or2_g2 (
        .A  (SYSREG_n[1]),
        .B  (R_W),
        .Y  (DEBUG_WRITE_n)
    );

    sn74hct32 u_or6_g1 (
        .A  (IO_n[4]),
        .B  (LDS_n),
        .Y  (SYSREG_ACK_STAGE_n)
    );

    sn74hct32 u_or6_g2 (
        .A  (SYSREG_ACK_STAGE_n),
        .B  (R_W),
        .Y  (SYSREG_DTACK_n)
    );

    // ---------------------------------------------------------------------
    // Low-128-KiB decoder: U_LOW128 (SN74HCT138)
    // ---------------------------------------------------------------------
    sn74hct138 u_low128 (
        .G1    (1'b1),
        .G2A_n (region_n[0]),
        .G2B_n (A[17]),
        .A     ({A[20], A[19], A[18]}),
        .Y     (low128_y)
    );

    assign LOW128_n = low128_y[0];

    // ---------------------------------------------------------------------
    // Boot overlay state: U_OVERLAY (SN74HCT74)
    // ---------------------------------------------------------------------
    sn74hct74 u_overlay (
        .PRE_n (RESET_n),
        .CLR_n (OVERLAY_WRITE_n),
        .CLK   (1'b0),
        .D     (1'b0),
        .Q     (OVERLAY_EN),
        .Q_n   (OVERLAY_n)
    );

    // ---------------------------------------------------------------------
    // Boot ROM alias generation: U_OR2 (gates 3-4)
    // ---------------------------------------------------------------------
    sn74hct32 u_or2_g3 (
        .A  (LOW128_n),
        .B  (OVERLAY_n),
        .Y  (ROM_ALIAS_ADDR_n)
    );

    sn74hct32 u_or2_g4 (
        .A  (ROM_ALIAS_ADDR_n),
        .B  (NORMAL_MISC_n),
        .Y  (ROM_ALIAS_n)
    );

    // ---------------------------------------------------------------------
    // Firmware ROM cycle selection: U_AND gate 3
    // ---------------------------------------------------------------------
    sn74hct08 u_and_g3 (
        .A  (IO_n[15]),
        .B  (ROM_ALIAS_n),
        .Y  (ROM_CYCLE_n)
    );

    // ---------------------------------------------------------------------
    // Firmware ROM bank and byte-lane selection: U_INVERT gate 1,
    // U_OR3 (gates 3-4), U_OR4
    // ---------------------------------------------------------------------
    sn74hct04 u_invert_g1 (
        .A  (A[16]),
        .Y  (A16_n)
    );

    sn74hct04 u_invert_g2 (
        .A  (R_W),
        .Y  (READ_n)
    );

    sn74hct32 u_or3_g3 (
        .A  (ROM_CYCLE_n),
        .B  (A[16]),
        .Y  (ROM_BANK0_n)
    );

    sn74hct32 u_or3_g4 (
        .A  (ROM_CYCLE_n),
        .B  (A16_n),
        .Y  (ROM_BANK1_n)
    );

    sn74hct32 u_or4_g1 (
        .A  (ROM_BANK0_n),
        .B  (UDS_n),
        .Y  (ROM0_UDS_n)
    );

    sn74hct32 u_or4_g2 (
        .A  (ROM_BANK0_n),
        .B  (LDS_n),
        .Y  (ROM0_LDS_n)
    );

    sn74hct32 u_or4_g3 (
        .A  (ROM_BANK1_n),
        .B  (UDS_n),
        .Y  (ROM1_UDS_n)
    );

    sn74hct32 u_or4_g4 (
        .A  (ROM_BANK1_n),
        .B  (LDS_n),
        .Y  (ROM1_LDS_n)
    );

    // ---------------------------------------------------------------------
    // DRAM bank 0 overlay suppression: U_INVERT gate 3, U_OR3 (gates 1-2)
    // ---------------------------------------------------------------------
    sn74hct04 u_invert_g3 (
        .A  (ROM_ALIAS_ADDR_n),
        .Y  (ALIAS_ACTIVE)
    );

    sn74hct32 u_or3_g1 (
        .A  (region_n[0]),
        .B  (NORMAL_MEM_n),
        .Y  (RAM0_BASE_n)
    );

    sn74hct32 u_or3_g2 (
        .A  (RAM0_BASE_n),
        .B  (ALIAS_ACTIVE),
        .Y  (RAM0_REQ_n)
    );

    // ---------------------------------------------------------------------
    // Debug byte storage: U_DEBUG (SN74HCT574), and U_INVERT gate 5
    // ---------------------------------------------------------------------
    sn74hct04 u_invert_g5 (
        .A  (DEBUG_WRITE_n),
        .Y  (DEBUG_CLK)
    );

    genvar di;
    generate
        for (di = 0; di < 8; di = di + 1) begin : gen_debug
            sn74hct574 u_debug_bit (
                .OE_n (1'b0),
                .CLK  (DEBUG_CLK),
                .D    (D[di]),
                .Q    (DEBUG_Q[di])
            );
        end
    endgenerate

    // ---------------------------------------------------------------------
    // DTACK combination tree: U_DTACK_A / U_DTACK_B (SN74F21)
    // ---------------------------------------------------------------------
    sn74f21 u_dtack_a_g1 (
        .A  (DRAM_DTACK_n),
        .B  (ROM_DTACK_n),
        .C  (SYSREG_DTACK_n),
        .D  (MFP_DTACK_n),
        .Y  (DTACK_GROUP0_n)
    );

    sn74f21 u_dtack_a_g2 (
        .A  (FDC_DTACK_n),
        .B  (OPL3_DTACK_n),
        .C  (VGA_DTACK_n),
        .D  (MIDI_DTACK_n),
        .Y  (DTACK_GROUP1_n)
    );

    sn74f21 u_dtack_b_g1 (
        .A  (RTC_DTACK_n),
        .B  (EXP_DTACK_n),
        .C  (1'b1),
        .D  (1'b1),
        .Y  (DTACK_GROUP2_n)
    );

    sn74f21 u_dtack_b_g2 (
        .A  (DTACK_GROUP0_n),
        .B  (DTACK_GROUP1_n),
        .C  (DTACK_GROUP2_n),
        .D  (1'b1),
        .Y  (DTACK_RAW_n)
    );

    // ---------------------------------------------------------------------
    // Bus timeout: U_TIMEOUT (CD74HCT4040), U_INVERT gate 4, U_AND gate 4
    // ---------------------------------------------------------------------
    cd74hct4040 u_timeout (
        .CP (CLK),
        .MR (NORMAL_MISC_n),
        .Q  (timeout_q)
    );

    assign TIMEOUT_ACTIVE = timeout_q[10];

    sn74hct04 u_invert_g4 (
        .A  (TIMEOUT_ACTIVE),
        .Y  (TIMEOUT_BERR_n)
    );

    sn74hct08 u_and_g4 (
        .A  (TIMEOUT_BERR_n),
        .B  (INT_BERR_n),
        .Y  (BERR_n)
    );

    // ---------------------------------------------------------------------
    // Final DTACK mask: U_OR_DTACK (SN74F32)
    // ---------------------------------------------------------------------
    sn74f32 u_or_dtack (
        .A  (DTACK_RAW_n),
        .B  (TIMEOUT_ACTIVE),
        .Y  (DTACK_n)
    );

endmodule

`default_nettype wire
