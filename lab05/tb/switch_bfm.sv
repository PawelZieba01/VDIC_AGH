// ============================================================================
//  INTERFACE: tb_if
//  ----------------------------------------------------------------------------
//  The interface groups all DUT I/Os and shared resources used by
//  the verification components. It acts as a central hub for communication.
// ============================================================================

import fifomult_tb_pkg::*;
interface switch_bfm();
    

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


    // ------------------------------------------------------------------------
    // Clock generation block
    //  - 50 MHz clock (period = 20 ns)
    //  - Default reset state: asserted low
    // ------------------------------------------------------------------------
    initial begin : clk_gen_blk
        bfm.rst_n = 1;
        bfm.sin   = 1;
        bfm.prog  = 0;
        bfm.clk   = 0;

        forever begin
            #10;
            bfm.clk = ~bfm.clk;
        end
    end

    initial begin
        gen2drv_mb = new();
        gen2sb_mb  = new();
        mon2sb_mb  = new();
        gen2cov_mb = new();
    end

    //--------------------------------------------------------------------------
    // Task: uart_send_frame
    // Sends one UART frame bit-by-bit synchronized with bfm.clk
    // start -> 8 data bits -> parity -> stop
    //--------------------------------------------------------------------------
    task automatic uart_send_frame(
        input uart_frame_t frame,
        ref logic sin
    );
        int i;
        // Start bit
        sin = frame.start;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);

        // 8 data bits (LSB first)
        for (i = 0; i < 8; i++) begin
            sin = frame.data[i];
            repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        end

        // Parity bit
        sin = frame.parity;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);

        // Stop bit
        sin = frame.stop;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
    endtask


    //--------------------------------------------------------------------------
    // Task: reset_dut
    // Performs synchronous reset on DUT and waits for it to stabilize
    //--------------------------------------------------------------------------
    task automatic reset_dut();
    begin
        `ifdef DEBUG
        $display("[%0t] [DRV] ----------- DUT reset start -----------", $time);
        `endif

        bfm.rst_n = 0;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        bfm.rst_n = 1;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);

        `ifdef DEBUG
        $display("[%0t] [DRV] ----------- DUT reset done -----------", $time);
        `endif
    end
    endtask

    task automatic send_transaction (
        input uart_transaction_t tr
    );
    begin

         // Drive DUT
        bfm.prog = tr.prog;
        bfm.uart_send_frame(tr.switch_packet.addr, bfm.sin);  // Send address frame
        bfm.uart_send_frame(tr.switch_packet.data, bfm.sin);  // Send data frame
        bfm.prog = 0;  
    end
    endtask


endinterface : switch_bfm