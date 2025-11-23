class coverage extends uvm_subscriber #(command_s);
    `uvm_component_utils(coverage)

    byte unsigned   addr_cov;
    bit             prog_cov;
    operation_t     op_cov;

    byte unsigned port_cov;
    byte unsigned data_cov;
    bit           packet_valid_cov;
    bit [2:0]     invalid_type_cov;

    
    covergroup address_cov;
        option.name = "cg_address";
        
        coverpoint addr_cov {
            bins all_addrs_prog[]    = {[0:255]} iff (prog_cov == 1);
            bins all_addrs_nonprog[] = {[0:255]} iff (prog_cov == 0);
        }
    endgroup

    covergroup routing_data_cov;
        option.name = "cg_routing_and_data";

        cp_programmed: coverpoint port_cov {
            bins sout0_programmed = {8'h00} iff (prog_cov == 1);
            bins sout1_programmed = {8'h01} iff (prog_cov == 1);
        }

        cp_valid_to_port: coverpoint packet_valid_cov {
            bins valid_sout0   = {1'b1} iff (port_cov == 8'h00);
            bins valid_sout1   = {1'b1} iff (port_cov == 8'h01);
            bins invalid_sout0 = {1'b0} iff (port_cov == 8'h00);
            bins invalid_sout1 = {1'b0} iff (port_cov == 8'h01);
        }

        cp_invalid_types: coverpoint invalid_type_cov {
            bins no_error     = {3'b000};
            bins stop_error   = {3'b010};
            bins parity_error = {3'b001};
            bins stop_parity  = {3'b011};
        }

        cp_all_data: coverpoint data_cov {
            bins all_data_values[] = {[0:255]} iff (prog_cov == 0);
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
    function void write(command_s t);
        addr_cov            = t.tr.switch_packet.addr.data;
        prog_cov            = t.tr.prog;
        packet_valid_cov    = t.tr.valid;
        port_cov            = t.tr.switch_packet.data.data;
        invalid_type_cov    = {(!t.tr.valid_start), (!t.tr.valid_stop), (!t.tr.valid_parity)};
        data_cov            = t.tr.switch_packet.data.data;
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
