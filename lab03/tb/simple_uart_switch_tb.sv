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


// ----------------------------------------------------------------------------
//  PACKAGE: tb_pkg
//  Contains type definitions, constants, and data structures used by all TB
// ----------------------------------------------------------------------------
package tb_pkg;
    // UART protocol timing constant
    localparam int CLKS_PER_BIT = 16;

    // Global test result enum
    typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result_t;

    // Text color formatting for pretty console output
    typedef enum {
        COLOR_BOLD_BLACK_ON_GREEN,
        COLOR_BOLD_BLACK_ON_RED,
        COLOR_BOLD_BLACK_ON_YELLOW,
        COLOR_BOLD_BLUE_ON_WHITE,
        COLOR_BLUE_ON_WHITE,
        COLOR_DEFAULT
    } print_color_t;

    // UART frame definition (start, data, parity, stop)
    typedef struct packed {
        logic start;
        logic [7:0] data;
        logic parity;
        logic stop;
    } uart_frame_t;

    // Switch packet = two UART frames: address + data
    typedef struct packed {
        uart_frame_t addr;
        uart_frame_t data;
    } switch_packet_t;

    // Status enumerations for UART frame integrity
    typedef enum {UART_OK, UART_PARITY_ERR, UART_START_ERR, UART_STOP_ERR} uart_status_t;

    // Output port identifiers
    typedef enum int {SOUT0, SOUT1, SOUTX} uart_port_t;

    // Memory entry: routing table entry (address → output port)
    typedef struct {
        logic [7:0] addr;
        uart_port_t port;
    } mem_entry_t;

    // UART transaction object exchanged between TB components
    typedef struct {
        switch_packet_t  switch_packet;
        bit              prog;           // programming transaction
        bit              valid;          // expected to be valid?
        bit              valid_start;
        bit              valid_parity;
        bit              valid_stop;
        bit              empty_packet;   // monitor saw nothing
        bit              finish_sim;     // end-of-sim signal
        uart_port_t      port;           // expected output port
    } uart_transaction_t;

endpackage : tb_pkg


// ============================================================================
//  INTERFACE: tb_if
//  ----------------------------------------------------------------------------
//  The interface groups all DUT I/Os and shared resources used by
//  the verification components. It acts as a central hub for communication.
// ============================================================================
interface tb_if;
    import tb_pkg::*;

    // DUT I/O lines
    logic clk;
    logic rst_n;
    logic prog;
    logic sin;
    logic sout0;
    logic sout1;

    // Shared test result (visible to all blocks)
    test_result_t test_result;

    // Inter-component mailboxes
    mailbox #(uart_transaction_t) gen2drv_mb;  // Generator → Driver
    mailbox #(uart_transaction_t) gen2sb_mb;   // Generator → Scoreboard
    mailbox #(uart_transaction_t) mon2sb_mb;   // Monitor → Scoreboard
    mailbox #(uart_transaction_t) gen2cov_mb;  // Generator → Coverage

    // Synchronization event for monitor start
    event monitor_start_evt;

    // Shared state: programming packet counter + routing table
    int unsigned prog_pkt_count;
    mem_entry_t mem_table [0:255];

    // Debug flag (used to enable verbose logs)
    logic debug;

endinterface : tb_if


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
    import tb_pkg::*;

    // Instantiate shared interface (connects all blocks)
    tb_if tb();

    // ------------------------------------------------------------------------
    // DUT Instantiation
    // Connect all DUT ports to interface signals.
    // ------------------------------------------------------------------------
    simple_switch_uart dut (
        .clk    (tb.clk),
        .rst_n  (tb.rst_n),
        .prog   (tb.prog),
        .sin    (tb.sin),
        .sout0  (tb.sout0),
        .sout1  (tb.sout1)
    );

    // ------------------------------------------------------------------------
    // Verification environment instantiation
    // ------------------------------------------------------------------------
    tp_gen     u_tp_gen  ( .tb(tb) );   // Transaction generator
    driver     u_driver  ( .tb(tb) );   // Drives serial line inputs
    monitor    u_monitor ( .tb(tb) );   // Observes DUT outputs
    scoreboard u_score   ( .tb(tb) );   // Compares expected vs observed
    coverage   u_cov     ( .tb(tb) );   // Functional coverage collector

    // ------------------------------------------------------------------------
    // Clock generation block
    //  - 50 MHz clock (period = 20 ns)
    //  - Default reset state: asserted low
    // ------------------------------------------------------------------------
    initial begin : clk_gen_blk
        tb.rst_n = 1;
        tb.sin   = 1;
        tb.prog  = 0;
        tb.clk   = 0;

        forever begin
            #10;
            tb.clk = ~tb.clk;
        end
    end

    // ------------------------------------------------------------------------
    // Testbench initialization
    //  - Allocate mailboxes for inter-module communication
    //  - Initialize shared variables and default states
    // ------------------------------------------------------------------------
    initial begin
        tb.gen2drv_mb = new();
        tb.gen2sb_mb  = new();
        tb.mon2sb_mb  = new();
        tb.gen2cov_mb = new();

        tb.prog_pkt_count = 0;
        tb.debug = 1'b0; // Disable debug prints by default

        // Optional startup message
        $display("[%0t] [TOP] Testbench initialized — starting simulation...", $time);
    end

endmodule : top
