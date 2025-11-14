// ============================================================================
//  Class: monitor
//  Description:
//      Functional monitor for the UART switch testbench.
//      Converted from module form with identical behavior.
//      Uses execute() as main entry point.
// ============================================================================
class monitor;

    

    // Handle to the testbench BFM interface
    virtual switch_bfm bfm; 

    // Constructor
    function new(virtual switch_bfm bfm);
        this.bfm = bfm; 
    endfunction


    // =========================================================================
    //  Main process (was initial block)
    // =========================================================================
    function void execute();
        fork
            begin : monitor_blk
                fifomult_tb_pkg::uart_transaction_t tr0, tr1;
                int timeout_counter;

                @bfm.monitor_start_evt;
                repeat (11*CLKS_PER_BIT) @(posedge bfm.clk);

                `ifdef DEBUG
                $display("[%0t] [MON] Monitor started", $time); 
                `endif

                forever begin
                    fork
                        begin
                            forever begin
                                @(negedge bfm.sout0 or negedge bfm.sout1);
                                timeout_counter = 0;
                            end
                        end

                        begin
                            monitor_switch_packet(bfm.sout0, "sout0", tr0);
                            repeat (CLKS_PER_BIT/2) @(posedge bfm.clk);
                            tr0.port = SOUT0;
                            bfm.mon2sb_mb.put(tr0);
                        end

                        begin
                            monitor_switch_packet(bfm.sout1, "sout1", tr1);
                            repeat (CLKS_PER_BIT/2) @(posedge bfm.clk);
                            tr1.port = SOUT1;
                            bfm.mon2sb_mb.put(tr1);
                        end

                        begin
                            timeout_counter = 0;
                            forever begin
                                @(posedge bfm.clk);
                                timeout_counter = timeout_counter + 1;
                                if (timeout_counter >= 22*CLKS_PER_BIT) break;
                            end

                            `ifdef DEBUG
                            $display("[%0t] [MON] INFO: Monitor timeout!", $time);
                            `endif

                            tr1.empty_packet = 1'b1;
                            tr1.port = SOUTX;
                            bfm.mon2sb_mb.put(tr1);
                        end
                    join_any
                    disable fork;
                end
            end
        join_none
    endfunction


    // =========================================================================
    //  Task: UART frame capture
    // =========================================================================
    task automatic uart_capture_frame(
        ref logic sout,
        output uart_frame_t frame
    );
        int i;
        @(negedge sout);
        repeat(CLKS_PER_BIT/2) @(posedge bfm.clk);
        frame.start = 0;
        for (i = 0; i < 8; i++) begin
            repeat(CLKS_PER_BIT) @(posedge bfm.clk);
            frame.data[i] = sout;
        end
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        frame.parity = sout;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        frame.stop = sout;
    endtask


    // =========================================================================
    //  Task: Monitor one switch packet (ADDR + DATA)
    // =========================================================================
    task automatic monitor_switch_packet(
        ref logic sout,
        input string name,
        output uart_transaction_t tr
    );
        switch_packet_t pkt;
        byte data;
        uart_status_t status;

        uart_capture_frame(sout, pkt.addr);
        status = decode_uart_frame(pkt.addr, data);
        `ifdef DEBUG
        if (status == UART_OK)
            $display("[%0t] [MON] %s ADDR = 0x%02h", $time, name, data);
        else
            $display("[%0t] [MON] %s ADDR frame error: %0d", $time, name, status);
        `endif

        uart_capture_frame(sout, pkt.data);
        status = decode_uart_frame(pkt.data, data);
        `ifdef DEBUG
        if (status == UART_OK)
            $display("[%0t] [MON] %s DATA = 0x%02h", $time, name, data);
        else
            $display("[%0t] [MON] %s DATA frame error: %0d", $time, name, status);
        `endif

        tr.switch_packet = pkt;
        tr.prog = 0;
        tr.valid = (status == UART_OK) ? 1'b1 : 1'b0;
        tr.empty_packet = 1'b0;
        tr.finish_sim = 1'b0;
    endtask


    // =========================================================================
    //  Function: UART frame decoding
    // =========================================================================
    function automatic uart_status_t decode_uart_frame(
        input uart_frame_t frame,
        output byte data
    );
        uart_status_t status = UART_OK;
        data = 8'h00;
        if (frame.start !== 0) begin
            status = UART_START_ERR;
            return status;
        end
        data = frame.data;
        if (frame.parity !== (^frame.data)) begin
            status = UART_PARITY_ERR;
            return status;
        end
        if (frame.stop !== 1) begin
            status = UART_STOP_ERR;
            return status;
        end
        return status;
    endfunction

endclass : monitor
