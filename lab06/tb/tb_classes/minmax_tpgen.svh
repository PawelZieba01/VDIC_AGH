/*
 Copyright 2013 Ray Salemi

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
class minmax_tpgen extends random_tpgen;
    `uvm_component_utils (minmax_tpgen) 
    
    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    
    protected function uart_transaction_t get_transaction();
        uart_transaction_t tr;
        tr = get_minmax_packet();
        return tr;
    endfunction


    //----------------------------------------------------------------------
    // Task: get_minmax_packet
    //----------------------------------------------------------------------
    function automatic uart_transaction_t get_minmax_packet();
        byte unsigned addr, data;
        uart_port_t exp_port;
        bit addr_start_v, addr_parity_v, addr_stop_v;
        bit data_start_v, data_parity_v, data_stop_v;
        bit pkt_valid;
        uart_transaction_t tr;
        
        addr = ($urandom_range(0, 1)) ? 0 : 255;
        data = {$urandom_range(0, 255)}[7:0];
        exp_port = mem_table[addr].port;

        addr_start_v  = 1'b1;
        addr_stop_v   = 1'b1;
        addr_parity_v = 1'b1;

        data_start_v  = 1'b1;
        data_stop_v   = 1'b1;
        data_parity_v = 1'b1;

        pkt_valid = 1'b1;

        `ifdef DEBUG
        $display("[%0t] [GEN] exp_port for addr=0x%02h is %0d", $time, addr, exp_port);
        `endif

        tr = create_transaction(
            addr[7:0], data[7:0], exp_port,
            addr_start_v, addr_parity_v, addr_stop_v,
            data_start_v, data_parity_v, data_stop_v,
            pkt_valid, 1'b0
        );
        
        `ifdef DEBUG
        $display("[%0t] [GEN] ----------- Min/Max packets generation done -----------", $time);
        `endif

        return tr;
    endfunction


endclass : minmax_tpgen






