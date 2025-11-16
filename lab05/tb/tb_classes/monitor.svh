class monitor extends uvm_component;
    `uvm_component_utils(monitor)

    // Handle to the BFM interface
    virtual switch_bfm bfm;
    int timeout_counter;

    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Build phase: pobranie BFM z config_db
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual switch_bfm)::get(this, "", "bfm", bfm)) begin
            `ifdef DEBUG
                $display("[MON] FATAL: BFM not found in config_db");
            `endif
        end
    endfunction

    // Run phase: główny proces monitorowania
    task run_phase(uvm_phase phase);
        uart_transaction_t tr0, tr1;
        

        // Czekamy na start monitorowania
        @(bfm.monitor_start_evt);
        repeat(2) @(posedge bfm.clk);  // minimalne odczekanie na ustabilizowanie

        `ifdef DEBUG
            $display("[%0t] MONITOR STARTED", $time);
        `endif

        forever begin
            fork
                begin   
                    monitor_switch_packet(bfm.sout0, "sout0", tr0);
                    tr0.port = SOUT0;
                    bfm.mon2sb_mb.put(tr0);
                end
                begin
                    monitor_switch_packet(bfm.sout1, "sout1", tr1);
                    tr1.port = SOUT1;
                    bfm.mon2sb_mb.put(tr1);
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
                            bfm.mon2sb_mb.put(tr1);
                            break;
                        end
                    end
                end
            join_any
            disable fork;
        end
    endtask

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

endclass : monitor
