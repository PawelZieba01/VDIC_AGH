// ============================================================================
//  Top-Level Testbench for UART Switch
//  ----------------------------------------------------------------------------
//  Description:
//      This is the main testbench wrapper that instantiates the DUT
//      (Device Under Test) and all verification components: generator,
//      driver, monitor, scoreboard, and coverage collector.
//
//      The interface `tb_if` carries all shared resources such as:
//        - clocks, resets, and DUT connections
//        - mailboxes (for inter-component communication)
//        - event synchronization
//        - memory table for routing configuration
//
//      The testbench implements the standard layered UVM-like structure:
//        [Generator] → [Driver] → [DUT] → [Monitor] → [Scoreboard + Coverage]
//
//  Author: PZ
//  ============================================================================



// ============================================================================
//  MODULE: top
//  ----------------------------------------------------------------------------
//  Top-level testbench module connecting DUT and verification components.
//  It performs the following tasks:
//    1. Instantiates the DUT and TB modules (generator, driver, monitor, etc.)
//    2. Generates the system clock.
//    3. Initializes all mailboxes and shared data structures.
// ============================================================================
module top;
    import fifomult_tb_pkg::*;

    // Instantiate shared interface (connects all blocks)
    switch_bfm bfm();

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // Connect all DUT ports to interface signals.
    // ------------------------------------------------------------------------
    simple_switch_uart dut (
        .clk    (bfm.clk),
        .rst_n  (bfm.rst_n),
        .prog   (bfm.prog),
        .sin    (bfm.sin),
        .sout0  (bfm.sout0),
        .sout1  (bfm.sout1)
    );

    // ------------------------------------------------------------------------
    // Verification environment instantiation
    // ------------------------------------------------------------------------
    tp_gen     u_tp_gen  ( .bfm(bfm) );   // Transaction generator
    driver     u_driver  ( .bfm(bfm) );   // Drives serial line inputs
    monitor    u_monitor ( .bfm(bfm) );   // Observes DUT outputs
    scoreboard u_score   ( .bfm(bfm) );   // Compares expected vs observed
    coverage   u_cov     ( .bfm(bfm) );   // Functional coverage collector

    

    // ------------------------------------------------------------------------
    // Testbench initialization
    //  - Allocate mailboxes for inter-module communication
    //  - Initialize shared variables and default states
    // ------------------------------------------------------------------------
    initial begin
        bfm.gen2drv_mb = new();
        bfm.gen2sb_mb  = new();
        bfm.mon2sb_mb  = new();
        bfm.gen2cov_mb = new();

        bfm.prog_pkt_count = 0;
        bfm.debug = 1'b0; // Disable debug prints by default

        // Optional startup message
        $display("[%0t] [TOP] Testbench initialized — starting simulation...", $time);
    end

endmodule : top
