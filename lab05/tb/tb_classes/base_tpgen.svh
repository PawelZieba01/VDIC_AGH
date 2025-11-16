`ifndef BASE_TPGEN_SV
`define BASE_TPGEN_SV
`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class base_tpgen extends uvm_component;
    // Nie rejestrujemy base_tpgen w fabryce (to klasa abstrakcyjna)

    // BFM handle (virtual)
    protected virtual switch_bfm bfm;

    // konstruktor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    pure virtual protected function uart_transaction_t get_transaction();

    // pobranie BFM z config_db
    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(virtual switch_bfm)::get(null, "*", "bfm", bfm)) begin
            `uvm_fatal("NO_BFM", "base_tpgen: Failed to get BFM from config DB");
        end
    endfunction

    // run_phase zarządza objectionami i kolejnością wywołań
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // reset DUT przez BFM
        bfm.reset_dut();
        bfm.reset_dut();


        // Zacznij programowanie i generowanie
        program_dut();
        // poinformuj monitor że można startować (zachowuję Twoją konwencję)
        -> bfm.monitor_start_evt;
        
        repeat (5000) begin
            uart_transaction_t tr = get_transaction();
           
            if(tr.prog == 0) begin
                bfm.gen2sb_mb.put(tr);
            end
            bfm.gen2cov_mb.put(tr);

            bfm.send_transaction(tr);
        end
            
        // opcjonalnie notify end: jeśli chcesz przesłać tr_finish, zrób to w implementacji

        phase.drop_objection(this);
    endtask



    protected task program_dut();
        int unsigned i;
        uart_transaction_t tr;
        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT start -----------", $time);
        `endif

        for (i = 0; i < 256; i++) begin
            bfm.mem_table[i].addr = i[7:0];
            bfm.mem_table[i].port = ($urandom_range(0,1) == 0) ? SOUT0 : SOUT1;
        end

        for (i = 0; i < 256; i++) begin
            tr = create_transaction(
                bfm.mem_table[i].addr,
                bfm.mem_table[i].port,
                bfm.mem_table[i].port,
                1'b1, 1'b1, 1'b1,
                1'b1, 1'b1, 1'b1,
                1'b1, 1'b1
            );
            bfm.gen2cov_mb.put(tr);
            bfm.send_transaction(tr);
        end

        //repeat (bfm.prog_pkt_count*44*CLKS_PER_BIT) @(posedge bfm.clk);

        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT done -----------", $time);
        `endif
    endtask



    //----------------------------------------------------------------------
    // Task: create_and_send_transaction
    //----------------------------------------------------------------------
    function automatic uart_transaction_t create_transaction(
        input  byte unsigned addr,
        input  byte unsigned data,
        input  uart_port_t port,
        input  bit  addr_start_valid,
        input  bit  addr_parity_valid,
        input  bit  addr_stop_valid,
        input  bit  data_start_valid,
        input  bit  data_parity_valid,
        input  bit  data_stop_valid,
        input  bit  packet_valid,
        input  bit  prog_sig
    );
        uart_transaction_t tr;
        uart_frame_t addr_frame, data_frame;

        addr_frame = make_uart_frame(addr);
        data_frame = make_uart_frame(data);

        if (!prog_sig) begin
            if (!addr_start_valid)  addr_frame.start  = 1'b1;
            if (!addr_parity_valid) addr_frame.parity = ~addr_frame.parity;
            if (!addr_stop_valid)   addr_frame.stop   = 1'b0;
            if (!data_start_valid)  data_frame.start  = 1'b1;
            if (!data_parity_valid) data_frame.parity = ~data_frame.parity;
            if (!data_stop_valid)   data_frame.stop   = 1'b0;
        end

        tr.switch_packet.addr = addr_frame;
        tr.switch_packet.data = data_frame;
        tr.valid       = prog_sig ? 1'b1 : packet_valid;
        tr.finish_sim  = 0;
        tr.prog        = prog_sig;
        tr.port        = port;
        tr.valid_start  = addr_start_valid && data_start_valid;
        tr.valid_parity = addr_parity_valid && data_parity_valid;
        tr.valid_stop   = addr_stop_valid && data_stop_valid;

        //bfm.gen2drv_mb.put(tr);
        //bfm.gen2cov_mb.put(tr);
        // if (!prog_sig)
        //     bfm.gen2sb_mb.put(tr);
        // else
        //     bfm.prog_pkt_count++;

        `ifdef DEBUG
        if (!prog_sig) begin
            $display("[%0t] [GEN] Created transaction: addr=0x%02h, data=0x%02h, port=%0d, valid=%0b",
                     $time, addr, data, port, tr.valid);
        end else begin
        $display("[%0t] [GEN] Created PROGRAMMING transaction: addr=0x%02h, data=0x%02h, port=%0d, valid=%0b",
                 $time, addr, data, port, tr.valid);
        end
        `endif

        return tr;
    endfunction



    //----------------------------------------------------------------------
    // Function: make_uart_frame
    //----------------------------------------------------------------------
    function automatic uart_frame_t make_uart_frame(input byte unsigned data);
        uart_frame_t frame;
        frame.start  = 0;
        frame.data   = data;
        frame.parity = (^data);
        frame.stop   = 1;
        return frame;
    endfunction

endclass : base_tpgen
`endif

