class coverage extends uvm_subscriber #(command_transaction);
    `uvm_component_utils(coverage)

    byte unsigned   addr_cov;
    operation_t     op_cov;

    byte unsigned port_cov;
    byte unsigned data_cov;
    bit           packet_valid_cov;
    bit [2:0]     invalid_type_cov;

    
    covergroup address_cov;
        option.name = "cg_address";
        
        coverpoint addr_cov {
            bins all_addrs_prog[]    = {[0:255]} iff (op_cov == prog_op);
            bins all_addrs_nonprog[] = {[0:255]} iff (op_cov == normal_op);
        }
    endgroup


    covergroup routing_data_cov;
        option.name = "cg_routing_and_data";

        cp_programmed: coverpoint port_cov {
            bins sout0_programmed = {8'h00} iff (op_cov == prog_op);
            bins sout1_programmed = {8'h01} iff (op_cov == prog_op);
        }

        
        cp_invalid_types: coverpoint invalid_type_cov {
            bins no_error     = {3'b000};
            bins stop_error   = {3'b010};
            bins parity_error = {3'b001};
            bins stop_parity  = {3'b011};
        }

        cp_all_data: coverpoint data_cov {
            bins all_data_values[] = {[0:255]} iff (op_cov == normal_op);
        }
    endgroup

    
    covergroup reset_cov;
        option.name = "cg_reset";
        coverpoint op_cov {
            bins rst_op = {rst_op};
        }
    endgroup


    function new(string name, uvm_component parent);
        super.new(name, parent);
        address_cov      = new();
        routing_data_cov = new();
        reset_cov        = new();
    endfunction



//------------------------------------------------------------------------------
// subscriber write function
//------------------------------------------------------------------------------
    function void write(command_transaction t);
        addr_cov            = t.addr;
        port_cov            = t.port;
        invalid_type_cov    = {(!t.start_bit_valid), (!t.stop_bit_valid), (!t.parity_bit_valid)};
        data_cov            = t.data;
        op_cov              = t.op;

        address_cov.sample();
        routing_data_cov.sample();
        reset_cov.sample();
    endfunction : write

    
    
    function void report();
        $display("============================================================");
        $display(" Functional Coverage Summary:");
        $display(" -----------------------------------------------------------");
        $display("  Address coverage        : %.2f%%", address_cov.get_coverage());
        $display("  Routing & Data coverage : %.2f%%", routing_data_cov.get_coverage());
        $display("  Reset coverage          : %.2f%%", reset_cov.get_coverage());
        $display(" -----------------------------------------------------------");
        $display("============================================================");
    endfunction

endclass : coverage
