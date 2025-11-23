// ============================================================================
//  INTERFACE: tb_if
//  ----------------------------------------------------------------------------
//  The interface groups all DUT I/Os and shared resources used by
//  the verification components. It acts as a central hub for communication.
// ============================================================================

import fifomult_tb_pkg::*;
interface switch_bfm();

    command_monitor command_monitor_h;
    result_monitor result_monitor_h;
    

    // DUT I/O lines
    logic clk;
    logic rst_n; 
    logic prog;
    logic sin;
    logic sout0;
    logic sout1;  

    int timeout_counter;
 
  
  
    // Inter-component mailboxes
    // mailbox #(uart_transaction_t) gen2drv_mb;  // Generator → Driver
    // mailbox #(uart_transaction_t) gen2sb_mb;   // Generator → Scoreboard
    // mailbox #(uart_transaction_t) mon2sb_mb;   // Monitor → Scoreboard
    // mailbox #(uart_transaction_t) gen2cov_mb;  // Generator → Coverage
    mailbox #(command_s) drv2mon_mb;  // Generator → Coverage

    // Synchronization event for monitor start
    event monitor_start_evt;

    // Shared state: programming packet counter + routing table
    int unsigned prog_pkt_count;
    //mem_entry_t mem_table [0:255];

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
        // gen2drv_mb = new();
        // gen2sb_mb  = new();
        // mon2sb_mb  = new();
        // gen2cov_mb = new();
        drv2mon_mb = new();
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

    task automatic drive_dut (
        input command_s command
    );
    begin
        `ifdef DEBUG
        $display("[%0t] [DRV] Driving DUT with command op=%0s", $time, command.op.name());
        `endif

        
        case(command.op)
            normal_op: begin
                bfm.uart_send_frame(command.tr.switch_packet.addr, bfm.sin);  // Send address frame
                bfm.uart_send_frame(command.tr.switch_packet.data, bfm.sin);  // Send data frame
            end
            
            prog_op: begin
                bfm.prog = 1;
                bfm.uart_send_frame(command.tr.switch_packet.addr, bfm.sin);  // Send address frame
                bfm.uart_send_frame(command.tr.switch_packet.data, bfm.sin);  // Send data frame
                bfm.prog = 0; 
            end
            
            rst_op: begin
                reset_dut();
            end
            
            default: 
                $fatal(1, "Unknown operation");
        endcase
        drv2mon_mb.put(command); // Send command to monitor
    end
    endtask



//------------------------------------------------------------------------------
// write command monitor
//------------------------------------------------------------------------------

always @(posedge clk) begin : op_monitor    
    if (command_monitor_h != null) begin //guard against VCS time 0 posedge
        command_s command;
        drv2mon_mb.get(command);
        command_monitor_h.write_to_monitor(command);
    end    
end : op_monitor


//------------------------------------------------------------------------------
// write result monitor
//------------------------------------------------------------------------------

initial begin : result_monitor_thread
    uart_transaction_t tr0, tr1;
    command_s command;
        
    // Czekamy na start monitorowania
    //@(bfm.monitor_start_evt);
    //repeat(2) @(posedge bfm.clk);  // minimalne odczekanie na ustabilizowanie

    `ifdef DEBUG
        $display("[%0t] MONITOR STARTED", $time);
    `endif

    forever begin
        fork
            begin   
                monitor_switch_packet(bfm.sout0, "sout0", tr0); 
                tr0.port = SOUT0;
                //bfm.mon2sb_mb.put(tr0);
                command.tr = tr0;
            end
            begin
                monitor_switch_packet(bfm.sout1, "sout1", tr1);
                tr1.port = SOUT1;
                //bfm.mon2sb_mb.put(tr1);
                command.tr = tr1;
            end
            begin
                timeout_counter = 0;
                forever begin
                    @(posedge bfm.clk);
                    timeout_counter++;
                    if(timeout_counter >= 22*CLKS_PER_BIT) begin
                        `ifdef DEBUG
                            $display("[%0t] MONITOR TIMEOUT - sending empty packet", $time);
                        `endif
                        tr1.empty_packet = 1'b1;
                        tr1.port = SOUTX;
                        //bfm.mon2sb_mb.put(tr1);
                        command.tr = tr1;
                        break;
                    end
                end
            end
        join_any
        disable fork;
        
        result_monitor_h.write_to_monitor(command.tr);
    end
end : result_monitor_thread

// =========================================================================
    // UART frame capture
    // =========================================================================
    task automatic uart_capture_frame(ref logic sout, output uart_frame_t frame);
        int i;
        @(negedge sout);
        timeout_counter = 0;
        repeat(CLKS_PER_BIT/2) @(posedge bfm.clk);
        frame.start = 0;
        for(i=0; i<8; i++) begin
            repeat(CLKS_PER_BIT) @(posedge bfm.clk);
            frame.data[i] = sout;
        end
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        frame.parity = sout; 
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        frame.stop = sout;
    endtask

    // =========================================================================
    // Monitor one switch packet (ADDR + DATA)
    // =========================================================================
    task automatic monitor_switch_packet(ref logic sout, input string name, output uart_transaction_t tr);
        switch_packet_t pkt;
        byte data;
        uart_status_t status;

        uart_capture_frame(sout, pkt.addr);
        status = decode_uart_frame(pkt.addr, data);
        `ifdef DEBUG
            $display("[%0t] [MON] %s ADDR = 0x%02h",$time, name, data);
        `endif

        uart_capture_frame(sout, pkt.data);
        status = decode_uart_frame(pkt.data, data);
        `ifdef DEBUG
            $display("[%0t] [MON] %s DATA = 0x%02h",$time, name, data);
        `endif

        tr.switch_packet = pkt;
        tr.prog = 0;
        tr.valid = (status == UART_OK) ? 1'b1 : 1'b0;
        tr.empty_packet = 1'b0;
        tr.finish_sim = 1'b0;
    endtask

    // =========================================================================
    // UART frame decoding
    // =========================================================================
    function automatic uart_status_t decode_uart_frame(input uart_frame_t frame, output byte data);
        uart_status_t status = UART_OK;
        data = 8'h00;
        if(frame.start !== 0) status = UART_START_ERR;
        data = frame.data;
        if(frame.parity !== (^frame.data)) status = UART_PARITY_ERR;
        if(frame.stop !== 1) status = UART_STOP_ERR;
        return status;
    endfunction


endinterface : switch_bfm