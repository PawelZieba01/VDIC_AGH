`ifndef TPGEN_SV
`define TPGEN_SV
`include "uvm_macros.svh"
import uvm_pkg::*;

class tpgen extends uvm_component;
    `uvm_component_utils (tpgen)

    uvm_put_port #(command_transaction) command_port;

    mem_entry_t mem_table [0:255];



    //------------------------------------------------------------------------------
    // Constructor
    //------------------------------------------------------------------------------
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
       `uvm_info("TPGEN", "Programming DUT...", UVM_LOW)    

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

        `uvm_info("TPGEN", "Programming DUT complete", UVM_LOW)
    endtask

endclass : tpgen
`endif

