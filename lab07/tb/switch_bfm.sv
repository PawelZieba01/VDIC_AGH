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
  

    mailbox #(command_transaction) drv2mon_mb;  // Generator → Coverage

    // Synchronization event for monitor start
    event result_monitor_start_evt;

    // Shared state: programming packet counter + routing table
    int unsigned prog_pkt_count;

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
        drv2mon_mb = new();
    end

    //--------------------------------------------------------------------------
    // Task: uart_send_frame
    // Sends one UART frame bit-by-bit synchronized with bfm.clk
    // start -> 8 data bits -> parity -> stop
    //--------------------------------------------------------------------------
    task automatic uart_send_frame(
        //input uart_frame_t frame
        input byte unsigned data,
        input bit start_bit_valid,
        input bit parity_bit_valid,
        input bit stop_bit_valid
    );
        int i;
        // Start bit
        bfm.sin = start_bit_valid ? 0 : 1;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);

        // 8 data bits (LSB first)
        for (i = 0; i < 8; i++) begin
            bfm.sin = data[i];
            repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        end

        // Parity bit
        bfm.sin = parity_bit_valid ? (^data) : ~(^data);
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);

        // Stop bit
        bfm.sin = stop_bit_valid ? 1 : 0;
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



    //--------------------------------------------------------------------------
    // Task: drive_dut
    // Drives DUT with one command transaction
    //--------------------------------------------------------------------------
    task automatic drive_dut (
        input command_transaction command
    );
    begin
        
        case(command.op)
            normal_op: begin
                bfm.uart_send_frame(command.addr, command.start_bit_valid, command.parity_bit_valid, command.stop_bit_valid);  // Send address frame
                bfm.uart_send_frame(command.data, command.start_bit_valid, command.parity_bit_valid, command.stop_bit_valid);  // Send data frame
                -> bfm.result_monitor_start_evt; // Notify monitor to start capturing
            end
            
            prog_op: begin
                bfm.prog = 1;
                bfm.uart_send_frame(command.addr, 1'b1, 1'b1, 1'b1);  // Send address frame
                bfm.uart_send_frame(command.data, 1'b1, 1'b1, 1'b1);  // Send data frame
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
        command_transaction command;
        drv2mon_mb.get(command);           
        command_monitor_h.write_to_monitor(command);
    end    
end : op_monitor


//------------------------------------------------------------------------------
// write result monitor
//------------------------------------------------------------------------------

initial begin : result_monitor_thread
    uart_transaction_t tr0, tr1, tr;
        
    // Czekamy na start monitorowania
    @(bfm.result_monitor_start_evt);
    //repeat(2) @(posedge bfm.clk);  // minimalne odczekanie na ustabilizowanie

    `ifdef DEBUG
        $display("[%0t] MONITOR STARTED", $time);
    `endif

    forever begin
        fork
            begin   
                monitor_switch_packet(bfm.sout0, "sout0", tr0); 
                tr0.port = SOUT0;
                tr0.empty_packet = 1'b0;
                tr0.valid_start = 1'b1;
                tr0.valid_parity = 1'b1;
                tr0.valid_stop = 1'b1;
                
                tr = tr0;
            end
            begin
                monitor_switch_packet(bfm.sout1, "sout1", tr1);
                tr1.port = SOUT1;
                tr1.empty_packet = 1'b0;
                tr1.valid_start = 1'b1;
                tr1.valid_parity = 1'b1;
                tr1.valid_stop = 1'b1;

                tr = tr1;
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
                        tr1 = '{default:0};
                        tr1.empty_packet = 1'b1;
                        tr1.port = SOUTX;
                        //bfm.mon2sb_mb.put(tr1);
                        tr = tr1;
                        break;
                    end
                end
            end
        join_any
        disable fork;
        
        result_monitor_h.write_to_monitor(tr);
    end
end : result_monitor_thread

// =========================================================================
    // UART frame capture
    // =========================================================================
    task automatic uart_capture_frame(ref logic sout, output byte unsigned data);
        int i;
        @(negedge sout);
        timeout_counter = 0;
        repeat(CLKS_PER_BIT/2) @(posedge bfm.clk);
        //frame.start = 0;
        for(i=0; i<8; i++) begin
            repeat(CLKS_PER_BIT) @(posedge bfm.clk);
            data[i] = sout;
        end
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        //frame.parity = sout; 
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        //frame.stop = sout;
    endtask

    // =========================================================================
    // Monitor one switch packet (ADDR + DATA)
    // =========================================================================
    task automatic monitor_switch_packet(ref logic sout, input string name, output uart_transaction_t tr);
        switch_packet_t pkt;

        uart_capture_frame(sout, pkt.addr);
        // `ifdef DEBUG
        //     $display("[%0t] [MON] %s ADDR = 0x%02h",$time, name, pkt.addr);
        // `endif

        uart_capture_frame(sout, pkt.data);
        // `ifdef DEBUG
        //     $display("[%0t] [MON] %s DATA = 0x%02h",$time, name, pkt.data);
        // `endif

        tr.switch_packet = pkt;
        //tr.prog = 0; 
        //tr.valid = (status == UART_OK) ? 1'b1 : 1'b0;
        tr.empty_packet = 1'b0;
        //tr.finish_sim = 1'b0;
    endtask

    // // =========================================================================
    // // UART frame decoding
    // // =========================================================================
    // function automatic uart_status_t decode_uart_frame(input uart_frame_t frame, output byte data);
    //     uart_status_t status = UART_OK;
    //     data = 8'h00;
    //     if(frame.start !== 0) status = UART_START_ERR;
    //     data = frame.data;
    //     if(frame.parity !== (^frame.data)) status = UART_PARITY_ERR;
    //     if(frame.stop !== 1) status = UART_STOP_ERR;
    //     return status;
    // endfunction


endinterface : switch_bfm