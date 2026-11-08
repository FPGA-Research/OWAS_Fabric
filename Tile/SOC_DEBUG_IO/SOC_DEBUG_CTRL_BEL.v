`timescale 1ns / 1ps

(* FABulous, BelMap,
    INV_RESET  = 0,
    INV_IRQ    = 1,
    BYPASS_RST = 2,
    BYPASS_IRQ = 3
*)
module SOC_DEBUG_CTRL_BEL #(
    parameter integer NoConfigBits = 4
)(
    // =========================================================================
    // Manager & SoC Facing Pins (Slot Debug & Control)
    // =========================================================================
    (* FABulous, EXTERNAL *) input  wire [7:0] DEBUG_OUT,
    (* FABulous, EXTERNAL *) output reg  [7:0] DEBUG_IN,
    (* FABulous, EXTERNAL *) output wire       USR_IRQ,
    (* FABulous, EXTERNAL *) input  wire       SLOT_SOFT_RST_N,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    output reg  [7:0] FAB_DEBUG_OUT,
    input  wire [7:0] FAB_DEBUG_IN,
    input  wire       FAB_USR_IRQ,
    output wire       FAB_SLOT_SOFT_RST_N,

    // =========================================================================
    // Global User Clock (Dedicated Fabric Net)
    // =========================================================================
    (* FABulous, EXTERNAL, SHARED_PORT *) input wire UserCLK,

    // =========================================================================
    // Static Configuration Bits
    // =========================================================================
    (* FABulous, GLOBAL *) input wire [NoConfigBits-1:0] ConfigBits
);

    // -------------------------------------------------------------------------
    // Bit 0: INV_RESET  -> Inverts soft reset polarity on ASIC side
    // Bit 1: INV_IRQ    -> Inverts user IRQ polarity on ASIC side
    // Bit 2: BYPASS_RST -> Register disable / bypass on reset (async delivery)
    // Bit 3: BYPASS_IRQ -> Register disable / bypass on interrupt (async delivery)
    // -------------------------------------------------------------------------
    wire INV_RESET  = ConfigBits[0];
    wire INV_IRQ    = ConfigBits[1];
    wire BYPASS_RST = ConfigBits[2];
    wire BYPASS_IRQ = ConfigBits[3];

    reg       reg_usr_irq;
    reg       reg_soft_rst_n;

    // ASIC-side polarity inversion
    wire raw_asic_rst_n = INV_RESET ? ~SLOT_SOFT_RST_N : SLOT_SOFT_RST_N;
    wire raw_fab_irq    = INV_IRQ   ? ~FAB_USR_IRQ     : FAB_USR_IRQ;

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> Manager/SoC: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    // UserCLK through 3 leaf buffers, 6 FFs each.
    wire clk_l0, clk_l1, clk_l2;
    clk_leaf_buf inst_clk_leaf0 (.A(UserCLK), .X(clk_l0));
    clk_leaf_buf inst_clk_leaf1 (.A(UserCLK), .X(clk_l1));
    clk_leaf_buf inst_clk_leaf2 (.A(UserCLK), .X(clk_l2));

    always @(posedge clk_l0) begin
        DEBUG_IN[5:0] <= FAB_DEBUG_IN[5:0];
    end
    always @(posedge clk_l1) begin
        DEBUG_IN[7:6] <= FAB_DEBUG_IN[7:6];
        reg_usr_irq   <= raw_fab_irq;
        FAB_DEBUG_OUT[2:0] <= DEBUG_OUT[2:0];
    end

    // -------------------------------------------------------------------------
    // Inbound Capture Pipeline Registers (Manager -> Fabric: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge clk_l2) begin
        FAB_DEBUG_OUT[7:3] <= DEBUG_OUT[7:3];
        reg_soft_rst_n     <= raw_asic_rst_n;
    end

    // Direct / Bypassable Reset and IRQ lines
    assign USR_IRQ             = BYPASS_IRQ ? raw_fab_irq    : reg_usr_irq;
    assign FAB_SLOT_SOFT_RST_N = BYPASS_RST ? raw_asic_rst_n : reg_soft_rst_n;

endmodule
