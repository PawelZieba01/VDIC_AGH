`ifndef TPGEN_SV
`define TPGEN_SV
`include "uvm_macros.svh"
import uvm_pkg::*;

class tpgen extends uvm_component;
    `uvm_component_utils (tpgen)

    // BFM handle (virtual)
    uvm_put_port #(command_transaction) command_port;

    mem_entry_t mem_table [0:255];

    // konstruktor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        command_port = new("command_port", this);
    endfunction : build_phase

    

    // run_phase zarządza objectionami i kolejnością wywołań
    task run_phase(uvm_phase phase);
        command_transaction command;

        phase.raise_objection(this);

        // reset DUT
        command    = new("command");
        command.op = rst_op;
        command_port.put(command);
       
        #2000

        // Zacznij programowanie i generowanie
        program_dut();
         
        

        repeat (5000) begin      
            command    = command_transaction::type_id::create("command");        
            assert(command.randomize());
            command.op = normal_op;
            command.port = mem_table[command.addr].port; //set destination port
            command_port.put(command);

        end
            
        phase.drop_objection(this);
    endtask



    protected task program_dut();
        int unsigned i;
        command_transaction command;
        uart_transaction_t tr;
        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT start -----------", $time);
        `endif

        

        for (i = 0; i < 256; i++) begin
            mem_table[i].addr = i[7:0];
            mem_table[i].port = ($urandom_range(0,1) == 0) ? SOUT0 : SOUT1;
        end

        for (i = 0; i < 256; i++) begin
            command    = new("command");
            command.addr = mem_table[i].addr;
            command.port = mem_table[i].port;
            command.data = mem_table[i].port;
            command.op = prog_op;

            command.stop_bit_valid = 1;
            command.parity_bit_valid = 1;
            command.start_bit_valid = 1;

            command_port.put(command);
        end

        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT done -----------", $time);
        `endif
    endtask



    // //----------------------------------------------------------------------
    // // Task: create_and_send_transaction
    // //----------------------------------------------------------------------
    // function automatic uart_transaction_t create_transaction(
    //     input  byte unsigned addr,
    //     input  byte unsigned data,
    //     input  uart_port_t port,
    //     input  bit  addr_start_valid,
    //     input  bit  addr_parity_valid,
    //     input  bit  addr_stop_valid,
    //     input  bit  data_start_valid,
    //     input  bit  data_parity_valid,
    //     input  bit  data_stop_valid,
    //     input  bit  packet_valid,
    //     input  bit  prog_sig
    // );
    //     uart_transaction_t tr;
    //     uart_frame_t addr_frame, data_frame;

    //     addr_frame = make_uart_frame(addr);
    //     data_frame = make_uart_frame(data);

    //     if (!prog_sig) begin
    //         if (!addr_start_valid)  addr_frame.start  = 1'b1;
    //         if (!addr_parity_valid) addr_frame.parity = ~addr_frame.parity;
    //         if (!addr_stop_valid)   addr_frame.stop   = 1'b0;
    //         if (!data_start_valid)  data_frame.start  = 1'b1;
    //         if (!data_parity_valid) data_frame.parity = ~data_frame.parity;
    //         if (!data_stop_valid)   data_frame.stop   = 1'b0;
    //     end

    //     tr.switch_packet.addr = addr_frame;
    //     tr.switch_packet.data = data_frame;
    //     tr.valid       = prog_sig ? 1'b1 : packet_valid;
    //     tr.finish_sim  = 0;
    //     tr.prog        = prog_sig;
    //     tr.port        = port;
    //     tr.valid_start  = addr_start_valid && data_start_valid;
    //     tr.valid_parity = addr_parity_valid && data_parity_valid;
    //     tr.valid_stop   = addr_stop_valid && data_stop_valid;

    //     //bfm.gen2drv_mb.put(tr);
    //     //bfm.gen2cov_mb.put(tr);
    //     // if (!prog_sig)
    //     //     bfm.gen2sb_mb.put(tr);
    //     // else
    //     //     bfm.prog_pkt_count++;

    //     `ifdef DEBUG
    //     if (!prog_sig) begin
    //         $display("[%0t] [GEN] Created transaction: addr=0x%02h, data=0x%02h, port=%0d, valid=%0b",
    //                  $time, addr, data, port, tr.valid);
    //     end else begin
    //     $display("[%0t] [GEN] Created PROGRAMMING transaction: addr=0x%02h, data=0x%02h, port=%0d, valid=%0b",
    //              $time, addr, data, port, tr.valid);
    //     end
    //     `endif

    //     return tr;
    // endfunction



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

endclass : tpgen
`endif

