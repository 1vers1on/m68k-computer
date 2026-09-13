`timescale 1ns / 1ps
`default_nettype none

// Discrete controller from docs/static/dram.html, sections 7 and 10-19.
// Structural simulation: sequential state, muxes, buffers, and glue use the
// existing device models and their specify delays (compile with -gspecify).
// Each scalar gate/flip-flop instance represents a channel, not a whole IC.
// Read registers retain data after the bounded DRAM cycle closes.
// D is the motherboard bus; DRAM_D is the isolated bus shared by both banks.
// The spare third U_DRAM_MODE bit remembers request end through precharge.
// This and ACK_REQUEST prevent stale ACK/re-arm failures at a 105 ns bus gap.
// INIT_LAST uses equivalent F08/F04 gates because no F20 model is available;
// this is not a package/pin-exact netlist or a board timing-closure result.
module dram_controller (
    input  wire [23:0] A,
    input  wire RAM0_REQ_n, RAM1_REQ_n,
    input  wire AS_n, UDS_n, LDS_n, R_W,
    input  wire CPU_CLK_DIV2, CPU_CLK_10, RESET_n,
    inout  wire [15:0] D, DRAM_D,
    output wire [9:0] DRAM_A,
    output wire RAS0_n, RAS1_n, CAS_U_n, CAS_L_n, W_n, OE_n,
    output wire DRAM_ADDR_COL, DRAM_DTACK_n, DRAM_INIT_DONE,
    output wire ROM_CLK, INT_CLK
);
    wire DRAM_CLK_ROOT, DRAM_CLK_A, DRAM_CLK_B, DRAM_CLK_C, DRAM_CLK_D;
    wire DRAM_CLK_10;
    wire [3:0] RESET_BRANCH_n;
    wire [11:0] MUX_Y;
    wire [12:1] STARTUP_Q, REFRESH_Q;
    wire REQ_SYNC1, REQ_SYNC2, INIT_SYNC1, INIT_DELAY_DONE;
    wire REF_SYNC1, REF_SYNC2, REF_SYNC3;
    wire [3:0] TX, PHASE_Q, INIT_COUNT, CREDIT_Q;
    wire [15:0] PHASE_n;
    wire CPU_BUSY, REFRESH_BUSY, CPU_REQUEST_ENDED, CPU_REQUEST_ENDED_n;
    wire [3:0] CTL_A, CTL_A_n, CTL_B, CTL_B_n;
    wire ACK_ACTIVE;
    wire PHASE_4, READ_CAPTURE_D, READ_CAPTURE, TX_READ;
    wire [1:0] READ_HOLD_OE_n, WRITE_BUF_OE_n;
    wire TX_BANK1 = TX[0];
    wire TX_UPPER = TX[1];
    wire TX_LOWER = TX[2];
    wire TX_WRITE = TX[3];
    wire ACK_ARM = CTL_B[3];
    assign DRAM_INIT_DONE = INIT_COUNT[3];

    // U_DRAM_CLK_BUF: root, four controller branches, and three 10 MHz paths.
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_ROOT
        (.OE_n(1'b0), .A(CPU_CLK_DIV2), .Y(DRAM_CLK_ROOT));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_A
        (.OE_n(1'b0), .A(DRAM_CLK_ROOT), .Y(DRAM_CLK_A));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_B
        (.OE_n(1'b0), .A(DRAM_CLK_ROOT), .Y(DRAM_CLK_B));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_C
        (.OE_n(1'b0), .A(DRAM_CLK_ROOT), .Y(DRAM_CLK_C));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_D
        (.OE_n(1'b0), .A(DRAM_CLK_ROOT), .Y(DRAM_CLK_D));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_10
        (.OE_n(1'b0), .A(CPU_CLK_10), .Y(DRAM_CLK_10));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_ROM
        (.OE_n(1'b0), .A(DRAM_CLK_10), .Y(ROM_CLK));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_CLK_BUF_INT
        (.OE_n(1'b0), .A(DRAM_CLK_10), .Y(INT_CLK));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_RESET_BUF_0
        (.OE_n(1'b0), .A(RESET_n), .Y(RESET_BRANCH_n[0]));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_RESET_BUF_1
        (.OE_n(1'b0), .A(RESET_n), .Y(RESET_BRANCH_n[1]));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_RESET_BUF_2
        (.OE_n(1'b0), .A(RESET_n), .Y(RESET_BRANCH_n[2]));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_RESET_BUF_3
        (.OE_n(1'b0), .A(RESET_n), .Y(RESET_BRANCH_n[3]));

    // Three quad ACT157s: ten used channels and two grounded spare channels.
    for (genvar m = 0; m < 12; m = m + 1) begin : address_mux
        if (m < 10) begin : used_channel
            cd74act157 U_MUX (.G_n(1'b0), .SEL(DRAM_ADDR_COL),
                .A(A[m+1]), .B(A[m+11]), .Y(MUX_Y[m]));
        end else begin : spare_channel
            cd74act157 U_MUX (.G_n(1'b0), .SEL(DRAM_ADDR_COL),
                .A(1'b0), .B(1'b0), .Y(MUX_Y[m]));
        end
    end
    assign DRAM_A = MUX_Y[9:0];

    // Combinational equations below are expanded into individual FAST gates.
    wire BANK0_ACTIVE;
    wire BANK1_ACTIVE;
    wire UPPER_REQ;
    wire LOWER_REQ;
    wire WRITE_REQ;
    wire RAM_SELECTED;
    wire BYTE_STROBE;
    wire DRAM_CPU_REQ;
    wire RUN;
    wire PHASE_QD_n;
    wire PHASE_5;
    wire REFRESH_DONE;
    wire PHASE_LOAD_n;
    wire PHASE_COUNT_ENABLE;
    wire VALID_CPU_REQUEST;
    wire INIT_START;
    wire REFRESH_SERVICE;
    wire CPU_START;
    wire START_REFRESH;
    wire CPU_REQUEST_ENDED_D;
    wire CPU_BUSY_D;
    wire INIT_LAST;
    wire REFRESH_BUSY_D;
    wire RAS0_ACTIVE_D;
    wire RAS1_ACTIVE_D;
    wire CAS_U_ACTIVE_D;
    wire CAS_L_ACTIVE_D;
    wire W_ACTIVE_D;
    wire OE_ACTIVE_D;
    wire DRAM_ADDR_COL_D;
    wire ACK_ARM_D;
    wire ACK_REQUEST;
    wire ACK_ARM_AS;
    wire ACK_D;
    wire STARTUP_COUNTER_RESET;
    wire REFRESH_TICK;
    wire CREDIT_CHANGE;
    wire CREDIT_CE_n;
    wire REFRESH_PENDING;
    wire INIT_CBR_DONE;
    wire IDLE;
    wire OE_n_PRE;
    wire REFRESH_COUNTER_RESET;
    wire AS_ACTIVE;
    wire BYTE_ACTIVE;
    wire CPU_RAS_WINDOW;
    wire CPU_COL_WINDOW;
    wire CPU_CAS_WINDOW;
    wire CBR_CAS_WINDOW;
    wire CBR_RAS_WINDOW;
    wire PHASE_LOAD_n_term15;
    wire PHASE_COUNT_ENABLE_term17;
    wire VALID_CPU_REQUEST_term19;
    wire INIT_START_term21;
    wire INIT_START_term22;
    wire REFRESH_SERVICE_term24;
    wire CPU_START_term26;
    wire CPU_START_term27;
    wire CPU_START_term28;
    wire CPU_REQUEST_ENDED_D_term31;
    wire CPU_REQUEST_ENDED_D_term32;
    wire CPU_BUSY_D_term34;
    wire CPU_BUSY_D_term35;
    wire CPU_BUSY_D_term36;
    wire INIT_LAST_term39;
    wire INIT_LAST_term40;
    wire INIT_LAST_term41;
    wire REFRESH_BUSY_D_term43;
    wire REFRESH_BUSY_D_term44;
    wire REFRESH_BUSY_D_term45;
    wire REFRESH_BUSY_D_term46;
    wire REFRESH_BUSY_D_term47;
    wire RAS0_ACTIVE_D_term49;
    wire RAS0_ACTIVE_D_term50;
    wire RAS0_ACTIVE_D_term51;
    wire RAS0_ACTIVE_D_term52;
    wire RAS1_ACTIVE_D_term54;
    wire RAS1_ACTIVE_D_term55;
    wire RAS1_ACTIVE_D_term56;
    wire CAS_U_ACTIVE_D_term58;
    wire CAS_U_ACTIVE_D_term59;
    wire CAS_U_ACTIVE_D_term60;
    wire CAS_L_ACTIVE_D_term62;
    wire CAS_L_ACTIVE_D_term63;
    wire CAS_L_ACTIVE_D_term64;
    wire W_ACTIVE_D_term66;
    wire OE_ACTIVE_D_term68;
    wire OE_ACTIVE_D_term69;
    wire ACK_ARM_D_term72;
    wire ACK_ARM_D_term74;
    wire ACK_ARM_D_term75;
    wire ACK_BYTE_REQUEST;
    wire REFRESH_TICK_term83;
    wire REFRESH_PENDING_term87;
    wire REFRESH_PENDING_term88;
    wire INIT_CBR_DONE_term90;

    // BANK0_ACTIVE = ~RAM0_REQ_n
    sn74f04 g_BANK0_ACTIVE (.A(RAM0_REQ_n), .Y(BANK0_ACTIVE));
    // BANK1_ACTIVE = ~RAM1_REQ_n
    sn74f04 g_BANK1_ACTIVE (.A(RAM1_REQ_n), .Y(BANK1_ACTIVE));
    // UPPER_REQ = ~UDS_n
    sn74f04 g_UPPER_REQ (.A(UDS_n), .Y(UPPER_REQ));
    // LOWER_REQ = ~LDS_n
    sn74f04 g_LOWER_REQ (.A(LDS_n), .Y(LOWER_REQ));
    // WRITE_REQ = ~R_W
    sn74f04 g_WRITE_REQ (.A(R_W), .Y(WRITE_REQ));
    // RAM_SELECTED = BANK0_ACTIVE | BANK1_ACTIVE
    sn74f32 g_RAM_SELECTED (.A(BANK0_ACTIVE), .B(BANK1_ACTIVE), .Y(RAM_SELECTED));
    // BYTE_STROBE = UPPER_REQ | LOWER_REQ
    sn74f32 g_BYTE_STROBE (.A(UPPER_REQ), .B(LOWER_REQ), .Y(BYTE_STROBE));
    // DRAM_CPU_REQ = RAM_SELECTED & BYTE_STROBE
    sn74f08 g_DRAM_CPU_REQ (.A(RAM_SELECTED), .B(BYTE_STROBE), .Y(DRAM_CPU_REQ));
    // RUN = CPU_BUSY | REFRESH_BUSY
    sn74f32 g_RUN (.A(CPU_BUSY), .B(REFRESH_BUSY), .Y(RUN));
    // PHASE_QD_n = ~PHASE_Q[3]
    sn74f04 g_PHASE_QD_n (.A(PHASE_Q[3]), .Y(PHASE_QD_n));
    sn74f04 g_PHASE_4 (.A(PHASE_n[4]), .Y(PHASE_4));
    sn74f08 g_READ_CAPTURE (.A(CPU_BUSY), .B(PHASE_4), .Y(READ_CAPTURE_D));
    // PHASE_5 = ~PHASE_n[5]
    sn74f04 g_PHASE_5 (.A(PHASE_n[5]), .Y(PHASE_5));
    // REFRESH_DONE = REFRESH_BUSY & PHASE_5
    sn74f08 g_REFRESH_DONE (.A(REFRESH_BUSY), .B(PHASE_5), .Y(REFRESH_DONE));
    // PHASE_LOAD_n = RUN & ~REFRESH_DONE
    sn74f04 g_PHASE_LOAD_n_term15 (.A(REFRESH_DONE), .Y(PHASE_LOAD_n_term15));
    sn74f08 g_PHASE_LOAD_n (.A(RUN), .B(PHASE_LOAD_n_term15), .Y(PHASE_LOAD_n));
    // PHASE_COUNT_ENABLE = REFRESH_BUSY | (CPU_BUSY & PHASE_n[9])
    sn74f08 g_PHASE_COUNT_ENABLE_term17 (.A(CPU_BUSY), .B(PHASE_n[9]), .Y(PHASE_COUNT_ENABLE_term17));
    sn74f32 g_PHASE_COUNT_ENABLE (.A(REFRESH_BUSY), .B(PHASE_COUNT_ENABLE_term17), .Y(PHASE_COUNT_ENABLE));
    // VALID_CPU_REQUEST = REQ_SYNC2 & (BANK0_ACTIVE ^ BANK1_ACTIVE)
    sn74f86 g_VALID_CPU_REQUEST_term19 (.A(BANK0_ACTIVE), .B(BANK1_ACTIVE), .Y(VALID_CPU_REQUEST_term19));
    sn74f08 g_VALID_CPU_REQUEST (.A(REQ_SYNC2), .B(VALID_CPU_REQUEST_term19), .Y(VALID_CPU_REQUEST));
    // INIT_START = IDLE & (INIT_DELAY_DONE & ~DRAM_INIT_DONE)
    sn74f04 g_INIT_START_term22 (.A(DRAM_INIT_DONE), .Y(INIT_START_term22));
    sn74f08 g_INIT_START_term21 (.A(INIT_DELAY_DONE), .B(INIT_START_term22), .Y(INIT_START_term21));
    sn74f08 g_INIT_START (.A(IDLE), .B(INIT_START_term21), .Y(INIT_START));
    // REFRESH_SERVICE = IDLE & (DRAM_INIT_DONE & REFRESH_PENDING)
    sn74f08 g_REFRESH_SERVICE_term24 (.A(DRAM_INIT_DONE), .B(REFRESH_PENDING), .Y(REFRESH_SERVICE_term24));
    sn74f08 g_REFRESH_SERVICE (.A(IDLE), .B(REFRESH_SERVICE_term24), .Y(REFRESH_SERVICE));
    // CPU_START = (IDLE & DRAM_INIT_DONE) & (~REFRESH_PENDING & VALID_CPU_REQUEST)
    sn74f08 g_CPU_START_term26 (.A(IDLE), .B(DRAM_INIT_DONE), .Y(CPU_START_term26));
    sn74f04 g_CPU_START_term28 (.A(REFRESH_PENDING), .Y(CPU_START_term28));
    sn74f08 g_CPU_START_term27 (.A(CPU_START_term28), .B(VALID_CPU_REQUEST), .Y(CPU_START_term27));
    sn74f08 g_CPU_START (.A(CPU_START_term26), .B(CPU_START_term27), .Y(CPU_START));
    // START_REFRESH = INIT_START | REFRESH_SERVICE
    sn74f32 g_START_REFRESH (.A(INIT_START), .B(REFRESH_SERVICE), .Y(START_REFRESH));
    // Remember a request ending before phase 9. A new synchronized request
    // can already be high by then; it must not prolong the previous ownership.
    // CPU_REQUEST_ENDED_D = CPU_BUSY & (CPU_REQUEST_ENDED | ~REQ_SYNC2)
    sn74f04 g_CPU_REQUEST_ENDED_D_term32 (.A(REQ_SYNC2), .Y(CPU_REQUEST_ENDED_D_term32));
    sn74f32 g_CPU_REQUEST_ENDED_D_term31 (.A(CPU_REQUEST_ENDED), .B(CPU_REQUEST_ENDED_D_term32), .Y(CPU_REQUEST_ENDED_D_term31));
    sn74f08 g_CPU_REQUEST_ENDED_D (.A(CPU_BUSY), .B(CPU_REQUEST_ENDED_D_term31), .Y(CPU_REQUEST_ENDED_D));
    // CPU_BUSY_D = CPU_START | (CPU_BUSY & (PHASE_n[9] | (REQ_SYNC2 & ~CPU_REQUEST_ENDED)))
    sn74f08 g_CPU_BUSY_D_term36 (.A(REQ_SYNC2), .B(CPU_REQUEST_ENDED_n), .Y(CPU_BUSY_D_term36));
    sn74f32 g_CPU_BUSY_D_term35 (.A(PHASE_n[9]), .B(CPU_BUSY_D_term36), .Y(CPU_BUSY_D_term35));
    sn74f08 g_CPU_BUSY_D_term34 (.A(CPU_BUSY), .B(CPU_BUSY_D_term35), .Y(CPU_BUSY_D_term34));
    sn74f32 g_CPU_BUSY_D (.A(CPU_START), .B(CPU_BUSY_D_term34), .Y(CPU_BUSY_D));
    // INIT_LAST = (INIT_COUNT[0] & INIT_COUNT[1]) & (INIT_COUNT[2] & ~INIT_COUNT[3])
    sn74f08 g_INIT_LAST_term39 (.A(INIT_COUNT[0]), .B(INIT_COUNT[1]), .Y(INIT_LAST_term39));
    sn74f04 g_INIT_LAST_term41 (.A(INIT_COUNT[3]), .Y(INIT_LAST_term41));
    sn74f08 g_INIT_LAST_term40 (.A(INIT_COUNT[2]), .B(INIT_LAST_term41), .Y(INIT_LAST_term40));
    sn74f08 g_INIT_LAST (.A(INIT_LAST_term39), .B(INIT_LAST_term40), .Y(INIT_LAST));
    // REFRESH_BUSY_D = START_REFRESH | (REFRESH_BUSY & (PHASE_n[5] | (~DRAM_INIT_DONE & ~INIT_LAST)))
    sn74f04 g_REFRESH_BUSY_D_term46 (.A(DRAM_INIT_DONE), .Y(REFRESH_BUSY_D_term46));
    sn74f04 g_REFRESH_BUSY_D_term47 (.A(INIT_LAST), .Y(REFRESH_BUSY_D_term47));
    sn74f08 g_REFRESH_BUSY_D_term45 (.A(REFRESH_BUSY_D_term46), .B(REFRESH_BUSY_D_term47), .Y(REFRESH_BUSY_D_term45));
    sn74f32 g_REFRESH_BUSY_D_term44 (.A(PHASE_n[5]), .B(REFRESH_BUSY_D_term45), .Y(REFRESH_BUSY_D_term44));
    sn74f08 g_REFRESH_BUSY_D_term43 (.A(REFRESH_BUSY), .B(REFRESH_BUSY_D_term44), .Y(REFRESH_BUSY_D_term43));
    sn74f32 g_REFRESH_BUSY_D (.A(START_REFRESH), .B(REFRESH_BUSY_D_term43), .Y(REFRESH_BUSY_D));
    // RAS0_ACTIVE_D = (CPU_BUSY & (CPU_RAS_WINDOW & ~TX_BANK1)) | (REFRESH_BUSY & CBR_RAS_WINDOW)
    sn74f04 g_RAS0_ACTIVE_D_term51 (.A(TX_BANK1), .Y(RAS0_ACTIVE_D_term51));
    sn74f08 g_RAS0_ACTIVE_D_term50 (.A(CPU_RAS_WINDOW), .B(RAS0_ACTIVE_D_term51), .Y(RAS0_ACTIVE_D_term50));
    sn74f08 g_RAS0_ACTIVE_D_term49 (.A(CPU_BUSY), .B(RAS0_ACTIVE_D_term50), .Y(RAS0_ACTIVE_D_term49));
    sn74f08 g_RAS0_ACTIVE_D_term52 (.A(REFRESH_BUSY), .B(CBR_RAS_WINDOW), .Y(RAS0_ACTIVE_D_term52));
    sn74f32 g_RAS0_ACTIVE_D (.A(RAS0_ACTIVE_D_term49), .B(RAS0_ACTIVE_D_term52), .Y(RAS0_ACTIVE_D));
    // RAS1_ACTIVE_D = (CPU_BUSY & (CPU_RAS_WINDOW & TX_BANK1)) | (REFRESH_BUSY & CBR_RAS_WINDOW)
    sn74f08 g_RAS1_ACTIVE_D_term55 (.A(CPU_RAS_WINDOW), .B(TX_BANK1), .Y(RAS1_ACTIVE_D_term55));
    sn74f08 g_RAS1_ACTIVE_D_term54 (.A(CPU_BUSY), .B(RAS1_ACTIVE_D_term55), .Y(RAS1_ACTIVE_D_term54));
    sn74f08 g_RAS1_ACTIVE_D_term56 (.A(REFRESH_BUSY), .B(CBR_RAS_WINDOW), .Y(RAS1_ACTIVE_D_term56));
    sn74f32 g_RAS1_ACTIVE_D (.A(RAS1_ACTIVE_D_term54), .B(RAS1_ACTIVE_D_term56), .Y(RAS1_ACTIVE_D));
    // CAS_U_ACTIVE_D = (CPU_BUSY & (CPU_CAS_WINDOW & TX_UPPER)) | (REFRESH_BUSY & CBR_CAS_WINDOW)
    sn74f08 g_CAS_U_ACTIVE_D_term59 (.A(CPU_CAS_WINDOW), .B(TX_UPPER), .Y(CAS_U_ACTIVE_D_term59));
    sn74f08 g_CAS_U_ACTIVE_D_term58 (.A(CPU_BUSY), .B(CAS_U_ACTIVE_D_term59), .Y(CAS_U_ACTIVE_D_term58));
    sn74f08 g_CAS_U_ACTIVE_D_term60 (.A(REFRESH_BUSY), .B(CBR_CAS_WINDOW), .Y(CAS_U_ACTIVE_D_term60));
    sn74f32 g_CAS_U_ACTIVE_D (.A(CAS_U_ACTIVE_D_term58), .B(CAS_U_ACTIVE_D_term60), .Y(CAS_U_ACTIVE_D));
    // CAS_L_ACTIVE_D = (CPU_BUSY & (CPU_CAS_WINDOW & TX_LOWER)) | (REFRESH_BUSY & CBR_CAS_WINDOW)
    sn74f08 g_CAS_L_ACTIVE_D_term63 (.A(CPU_CAS_WINDOW), .B(TX_LOWER), .Y(CAS_L_ACTIVE_D_term63));
    sn74f08 g_CAS_L_ACTIVE_D_term62 (.A(CPU_BUSY), .B(CAS_L_ACTIVE_D_term63), .Y(CAS_L_ACTIVE_D_term62));
    sn74f08 g_CAS_L_ACTIVE_D_term64 (.A(REFRESH_BUSY), .B(CBR_CAS_WINDOW), .Y(CAS_L_ACTIVE_D_term64));
    sn74f32 g_CAS_L_ACTIVE_D (.A(CAS_L_ACTIVE_D_term62), .B(CAS_L_ACTIVE_D_term64), .Y(CAS_L_ACTIVE_D));
    // W_ACTIVE_D = CPU_BUSY & (CPU_RAS_WINDOW & TX_WRITE)
    sn74f08 g_W_ACTIVE_D_term66 (.A(CPU_RAS_WINDOW), .B(TX_WRITE), .Y(W_ACTIVE_D_term66));
    sn74f08 g_W_ACTIVE_D (.A(CPU_BUSY), .B(W_ACTIVE_D_term66), .Y(W_ACTIVE_D));
    // OE_ACTIVE_D = CPU_BUSY & (CPU_CAS_WINDOW & ~TX_WRITE)
    sn74f04 g_OE_ACTIVE_D_term69 (.A(TX_WRITE), .Y(OE_ACTIVE_D_term69));
    sn74f08 g_OE_ACTIVE_D_term68 (.A(CPU_CAS_WINDOW), .B(OE_ACTIVE_D_term69), .Y(OE_ACTIVE_D_term68));
    sn74f08 g_OE_ACTIVE_D (.A(CPU_BUSY), .B(OE_ACTIVE_D_term68), .Y(OE_ACTIVE_D));
    // DRAM_ADDR_COL_D = CPU_BUSY & CPU_COL_WINDOW
    sn74f08 g_DRAM_ADDR_COL_D (.A(CPU_BUSY), .B(CPU_COL_WINDOW), .Y(DRAM_ADDR_COL_D));
    // Allow a full tick after the phase-4 data capture before arming ACK.
    // ACK_ARM_D = (CPU_BUSY & ~CPU_REQUEST_ENDED) & (REQ_SYNC2 & (PHASE_5 | ACK_ARM))
    sn74f08 g_ACK_ARM_D_term72 (.A(CPU_BUSY), .B(CPU_REQUEST_ENDED_n), .Y(ACK_ARM_D_term72));
    sn74f32 g_ACK_ARM_D_term75 (.A(PHASE_5), .B(ACK_ARM), .Y(ACK_ARM_D_term75));
    sn74f08 g_ACK_ARM_D_term74 (.A(REQ_SYNC2), .B(ACK_ARM_D_term75), .Y(ACK_ARM_D_term74));
    sn74f08 g_ACK_ARM_D (.A(ACK_ARM_D_term72), .B(ACK_ARM_D_term74), .Y(ACK_ARM_D));
    // Mask stale ACK_ARM while request-end propagates through the mode/control
    // registers. Using only the raw strobes permits a false ACK at a 105 ns gap.
    // ACK_REQUEST = REQ_SYNC2 & ~CPU_REQUEST_ENDED
    sn74f08 U_DRAM_ACK_D_2 (.A(REQ_SYNC2), .B(CPU_REQUEST_ENDED_n), .Y(ACK_REQUEST));
    // ACK_ARM_AS = ACK_ARM & AS_ACTIVE
    sn74f08 U_DRAM_ACK_D_1 (.A(ACK_ARM), .B(AS_ACTIVE), .Y(ACK_ARM_AS));
    // ACK_D = ACK_ARM_AS & (BYTE_ACTIVE & ACK_REQUEST)
    sn74f08 U_DRAM_ACK_D_3 (.A(BYTE_ACTIVE), .B(ACK_REQUEST), .Y(ACK_BYTE_REQUEST));
    sn74f08 U_DRAM_ACK_D_4 (.A(ACK_ARM_AS), .B(ACK_BYTE_REQUEST), .Y(ACK_D));
    // STARTUP_COUNTER_RESET = ~RESET_BRANCH_n[3]
    sn74f04 g_STARTUP_COUNTER_RESET (.A(RESET_BRANCH_n[3]), .Y(STARTUP_COUNTER_RESET));
    // REFRESH_TICK = REF_SYNC2 & ~REF_SYNC3
    sn74f04 g_REFRESH_TICK_term83 (.A(REF_SYNC3), .Y(REFRESH_TICK_term83));
    sn74f08 g_REFRESH_TICK (.A(REF_SYNC2), .B(REFRESH_TICK_term83), .Y(REFRESH_TICK));
    // CREDIT_CHANGE = REFRESH_TICK ^ REFRESH_SERVICE
    sn74f86 g_CREDIT_CHANGE (.A(REFRESH_TICK), .B(REFRESH_SERVICE), .Y(CREDIT_CHANGE));
    // CREDIT_CE_n = ~CREDIT_CHANGE
    sn74f04 g_CREDIT_CE_n (.A(CREDIT_CHANGE), .Y(CREDIT_CE_n));
    // REFRESH_PENDING = (CREDIT_Q[0] | CREDIT_Q[1]) | (CREDIT_Q[2] | CREDIT_Q[3])
    sn74f32 g_REFRESH_PENDING_term87 (.A(CREDIT_Q[0]), .B(CREDIT_Q[1]), .Y(REFRESH_PENDING_term87));
    sn74f32 g_REFRESH_PENDING_term88 (.A(CREDIT_Q[2]), .B(CREDIT_Q[3]), .Y(REFRESH_PENDING_term88));
    sn74f32 g_REFRESH_PENDING (.A(REFRESH_PENDING_term87), .B(REFRESH_PENDING_term88), .Y(REFRESH_PENDING));
    // INIT_CBR_DONE = REFRESH_DONE & ~DRAM_INIT_DONE
    sn74f04 g_INIT_CBR_DONE_term90 (.A(DRAM_INIT_DONE), .Y(INIT_CBR_DONE_term90));
    sn74f08 g_INIT_CBR_DONE (.A(REFRESH_DONE), .B(INIT_CBR_DONE_term90), .Y(INIT_CBR_DONE));

    sn74f02 g_IDLE (.A(CPU_BUSY), .B(REFRESH_BUSY), .Y(IDLE));
    sn74f00 g_OE_n_PRE (.A(CTL_B[1]), .B(DRAM_CPU_REQ), .Y(OE_n_PRE));
    sn74f00 g_REFRESH_COUNTER_RESET (.A(RESET_BRANCH_n[3]),
        .B(DRAM_INIT_DONE), .Y(REFRESH_COUNTER_RESET));

    // U_DRAM_DTACK_GATE: raw strobe release bypasses the synchronizer.
    sn74f10 U_DRAM_DTACK_GATE_1 (.A(AS_n), .B(AS_n), .C(AS_n), .Y(AS_ACTIVE));
    sn74f10 U_DRAM_DTACK_GATE_2 (.A(UDS_n), .B(LDS_n), .C(LDS_n), .Y(BYTE_ACTIVE));
    sn74f10 U_DRAM_DTACK_GATE_3 (.A(ACK_ACTIVE), .B(AS_ACTIVE),
        .C(BYTE_ACTIVE), .Y(DRAM_DTACK_n));

    // U_DRAM_REQ_SYNC and U_INIT_SYNC, two flip-flops per package.
    sn74f74 U_DRAM_REQ_SYNC_1 (.PRE_n(1'b1), .CLR_n(RESET_BRANCH_n[0]),
        .CLK(DRAM_CLK_B), .D(DRAM_CPU_REQ), .Q(REQ_SYNC1), .Q_n());
    sn74f74 U_DRAM_REQ_SYNC_2 (.PRE_n(1'b1), .CLR_n(RESET_BRANCH_n[0]),
        .CLK(DRAM_CLK_B), .D(REQ_SYNC1), .Q(REQ_SYNC2), .Q_n());
    sn74f74 U_INIT_SYNC_1 (.PRE_n(1'b1), .CLR_n(RESET_BRANCH_n[3]),
        .CLK(DRAM_CLK_D), .D(STARTUP_Q[12]), .Q(INIT_SYNC1), .Q_n());
    sn74f74 U_INIT_SYNC_2 (.PRE_n(1'b1), .CLR_n(RESET_BRANCH_n[3]),
        .CLK(DRAM_CLK_D), .D(INIT_SYNC1), .Q(INIT_DELAY_DONE), .Q_n());
    sn74f74 U_DRAM_ACK_1 (.PRE_n(1'b1), .CLR_n(RESET_BRANCH_n[0]),
        .CLK(DRAM_CLK_B), .D(ACK_D), .Q(ACK_ACTIVE), .Q_n());
    sn74f74 U_DRAM_ACK_2 (.PRE_n(1'b1), .CLR_n(RESET_BRANCH_n[0]),
        .CLK(DRAM_CLK_B), .D(1'b0), .Q(), .Q_n());

    philips_74f194 #(.TPLH(8.0), .TPHL(8.0), .TSU_S(9.0), .TH_D(1.0),
        .TH_S(1.0), .TREC(8.0)) U_DRAM_TX (
        .MR_n(RESET_BRANCH_n[0]), .CP(DRAM_CLK_B),
        .S0(CPU_START), .S1(CPU_START), .DSR(1'b0), .DSL(1'b0),
        .D({WRITE_REQ, LOWER_REQ, UPPER_REQ, BANK1_ACTIVE}), .Q(TX));

    sn74f161a U_DRAM_PHASE (.CLR_n(RESET_BRANCH_n[1]),
        .LOAD_n(PHASE_LOAD_n), .ENP(PHASE_COUNT_ENABLE), .ENT(PHASE_COUNT_ENABLE),
        .CLK(DRAM_CLK_A), .D(4'b0), .Q(PHASE_Q), .RCO());
    sn74f138 U_DRAM_PHASE_LO (.G1(RUN), .G2A_n(PHASE_Q[3]), .G2B_n(1'b0),
        .A(PHASE_Q[2:0]), .Y(PHASE_n[7:0]));
    sn74f138 U_DRAM_PHASE_HI (.G1(RUN), .G2A_n(PHASE_QD_n), .G2B_n(1'b0),
        .A(PHASE_Q[2:0]), .Y(PHASE_n[15:8]));
    sn74f30 U_CPU_RAS_WINDOW (.A(PHASE_n[0]), .B(PHASE_n[1]), .C(PHASE_n[2]), .D(PHASE_n[3]), .E(PHASE_n[4]), .F(PHASE_n[5]), .G(1'b1), .H(1'b1), .Y(CPU_RAS_WINDOW));
    sn74f30 U_CPU_COL_WINDOW (.A(PHASE_n[1]), .B(PHASE_n[2]), .C(PHASE_n[3]), .D(PHASE_n[4]), .E(PHASE_n[5]), .F(1'b1), .G(1'b1), .H(1'b1), .Y(CPU_COL_WINDOW));
    sn74f30 U_CPU_CAS_WINDOW (.A(PHASE_n[2]), .B(PHASE_n[3]), .C(PHASE_n[4]), .D(PHASE_n[5]), .E(1'b1), .F(1'b1), .G(1'b1), .H(1'b1), .Y(CPU_CAS_WINDOW));
    sn74f30 U_CBR_CAS_WINDOW (.A(PHASE_n[0]), .B(PHASE_n[1]), .C(PHASE_n[2]), .D(PHASE_n[3]), .E(1'b1), .F(1'b1), .G(1'b1), .H(1'b1), .Y(CBR_CAS_WINDOW));
    sn74f30 U_CBR_RAS_WINDOW (.A(PHASE_n[1]), .B(PHASE_n[2]), .C(1'b1), .D(1'b1), .E(1'b1), .F(1'b1), .G(1'b1), .H(1'b1), .Y(CBR_RAS_WINDOW));
    sn74f175 U_DRAM_MODE_1 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(CPU_BUSY_D), .Q(CPU_BUSY), .Q_n());
    sn74f175 U_DRAM_MODE_2 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(REFRESH_BUSY_D), .Q(REFRESH_BUSY), .Q_n());
    sn74f175 U_DRAM_MODE_3 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(CPU_REQUEST_ENDED_D), .Q(CPU_REQUEST_ENDED), .Q_n(CPU_REQUEST_ENDED_n));
    sn74f175 U_DRAM_MODE_4 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(READ_CAPTURE_D), .Q(READ_CAPTURE), .Q_n());

    // Two HCT574 packages read the local bus. Two ACT244 packages carry writes
    // in the opposite direction. Each byte has its own output enable.
    // Raw direction/strobes prevent contention after aborts and at handoff.
    sn74f04 g_TX_READ (.A(TX_WRITE), .Y(TX_READ));
    for (genvar lane = 0; lane < 2; lane = lane + 1) begin : data_lane
        wire selected = lane == 0 ? TX_LOWER : TX_UPPER;
        wire raw_selected = lane == 0 ? LOWER_REQ : UPPER_REQ;
        wire read_selected;
        sn74f08 g_READ_SELECTED (.A(selected), .B(raw_selected), .Y(read_selected));
        sn74f30 g_READ_ENABLE (.A(RESET_n), .B(CPU_BUSY), .C(TX_READ),
            .D(read_selected), .E(R_W), .F(AS_ACTIVE), .G(DRAM_CPU_REQ),
            .H(ACK_REQUEST), .Y(READ_HOLD_OE_n[lane]));
        sn74f30 g_WRITE_ENABLE (.A(RESET_n), .B(WRITE_REQ), .C(raw_selected),
            .D(AS_ACTIVE), .E(DRAM_CPU_REQ), .F(1'b1), .G(1'b1), .H(1'b1),
            .Y(WRITE_BUF_OE_n[lane]));
        for (genvar bit_n = 0; bit_n < 8; bit_n = bit_n + 1) begin : bit_driver
            // SN74 grade at 4.5 V: use 150 pF clock/output-enable limits,
            // and the full-temperature setup, hold, and pulse requirements.
            sn74hct574 #(.TPLH(66.0), .TPHL(66.0), .TPZH(59.0), .TPZL(59.0),
                .TPHZ(38.0), .TPLZ(38.0), .TSU(25.0), .TH(5.0), .TW(20.0))
                U_DRAM_READ_HOLD (.OE_n(READ_HOLD_OE_n[lane]),
                .CLK(READ_CAPTURE), .D(DRAM_D[8*lane+bit_n]), .Q(D[8*lane+bit_n]));
            cd74act244 U_DRAM_WRITE_BUF (.OE_n(WRITE_BUF_OE_n[lane]),
                .A(D[8*lane+bit_n]), .Y(DRAM_D[8*lane+bit_n]));
        end
    end
    sn74f175 U_DRAM_CTL_A_1 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(RAS0_ACTIVE_D), .Q(CTL_A[0]), .Q_n(CTL_A_n[0]));
    sn74f175 U_DRAM_CTL_A_2 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(RAS1_ACTIVE_D), .Q(CTL_A[1]), .Q_n(CTL_A_n[1]));
    sn74f175 U_DRAM_CTL_A_3 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(CAS_U_ACTIVE_D), .Q(CTL_A[2]), .Q_n(CTL_A_n[2]));
    sn74f175 U_DRAM_CTL_A_4 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(CAS_L_ACTIVE_D), .Q(CTL_A[3]), .Q_n(CTL_A_n[3]));
    sn74f175 U_DRAM_CTL_B_1 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(W_ACTIVE_D), .Q(CTL_B[0]), .Q_n(CTL_B_n[0]));
    sn74f175 U_DRAM_CTL_B_2 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(OE_ACTIVE_D), .Q(CTL_B[1]), .Q_n(CTL_B_n[1]));
    sn74f175 U_DRAM_CTL_B_3 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(DRAM_ADDR_COL_D), .Q(CTL_B[2]), .Q_n(CTL_B_n[2]));
    sn74f175 U_DRAM_CTL_B_4 (.CLR_n(RESET_BRANCH_n[1]),
        .CLK(DRAM_CLK_A), .D(ACK_ARM_D), .Q(CTL_B[3]), .Q_n(CTL_B_n[3]));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_1
        (.OE_n(1'b0), .A(CTL_A_n[0]), .Y(RAS0_n));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_2
        (.OE_n(1'b0), .A(CTL_A_n[1]), .Y(RAS1_n));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_3
        (.OE_n(1'b0), .A(CTL_A_n[2]), .Y(CAS_U_n));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_4
        (.OE_n(1'b0), .A(CTL_A_n[3]), .Y(CAS_L_n));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_5
        (.OE_n(1'b0), .A(CTL_B_n[0]), .Y(W_n));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_6
        (.OE_n(1'b0), .A(OE_n_PRE), .Y(OE_n));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_7
        (.OE_n(1'b0), .A(CTL_B[2]), .Y(DRAM_ADDR_COL));
    cd74act244 #(.TPLH(9.6), .TPHL(9.6)) U_DRAM_STROBE_8
        (.OE_n(1'b0), .A(1'b0), .Y());

    cd74hct4040 U_STARTUP_DIV (.CP(DRAM_CLK_10), .MR(STARTUP_COUNTER_RESET), .Q(STARTUP_Q));
    cd74hct4040 U_REFRESH_DIV (.CP(DRAM_CLK_10), .MR(REFRESH_COUNTER_RESET), .Q(REFRESH_Q));
    sn74f175 U_REFRESH_SYNC_1 (.CLR_n(RESET_BRANCH_n[2]),
        .CLK(DRAM_CLK_C), .D(REFRESH_Q[7]), .Q(REF_SYNC1), .Q_n());
    sn74f175 U_REFRESH_SYNC_2 (.CLR_n(RESET_BRANCH_n[2]),
        .CLK(DRAM_CLK_C), .D(REF_SYNC1), .Q(REF_SYNC2), .Q_n());
    sn74f175 U_REFRESH_SYNC_3 (.CLR_n(RESET_BRANCH_n[2]),
        .CLK(DRAM_CLK_C), .D(REF_SYNC2), .Q(REF_SYNC3), .Q_n());
    sn74f175 U_REFRESH_SYNC_4 (.CLR_n(RESET_BRANCH_n[2]),
        .CLK(DRAM_CLK_C), .D(1'b0), .Q(), .Q_n());

    fairchild_74f191 U_REFRESH_CREDIT (.PL_n(RESET_BRANCH_n[2]),
        .CE_n(CREDIT_CE_n), .UD_n(REFRESH_SERVICE), .CP(DRAM_CLK_C),
        .P(4'b0), .Q(CREDIT_Q), .TC(), .RC_n());
    sn74f161a U_DRAM_INIT_CNT (.CLR_n(RESET_BRANCH_n[2]), .LOAD_n(1'b1),
        .ENP(INIT_CBR_DONE), .ENT(INIT_CBR_DONE), .CLK(DRAM_CLK_C),
        .D(4'b0), .Q(INIT_COUNT), .RCO());
endmodule

`default_nettype wire
