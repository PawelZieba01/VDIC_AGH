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
class random_tpgen extends base_tpgen;
    `uvm_component_utils (random_tpgen) 
    
//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    
    protected function uart_transaction_t get_transaction();
        uart_transaction_t tr;
        tr = get_random_packet();
        return tr;
    endfunction



    //----------------------------------------------------------------------
    // Task: send_random_packets
    //----------------------------------------------------------------------
    function automatic uart_transaction_t get_random_packet();
        byte unsigned addr, data;
        uart_port_t exp_port;
        bit addr_start_v, addr_parity_v, addr_stop_v;
        bit data_start_v, data_parity_v, data_stop_v;
        bit pkt_valid;
        bit parity_bit;
        uart_transaction_t tr;
        
        addr = rand_biased_addr();
        data = rand_biased_byte();
        exp_port = bfm.mem_table[addr].port;

        addr_start_v  = (rand_biased_start_bit(1) == 1'b0);
        addr_stop_v   = (rand_biased_stop_bit(0)  == 1'b1);
        parity_bit    = rand_biased_parity_bit(addr, 0);
        addr_parity_v = (parity_bit == (^addr));

        data_start_v  = (rand_biased_start_bit(1) == 1'b0);
        data_stop_v   = (rand_biased_stop_bit(0)  == 1'b1);
        parity_bit    = rand_biased_parity_bit(data, 0);
        data_parity_v = (parity_bit == (^data));

        pkt_valid = addr_start_v && addr_parity_v && addr_stop_v &&
                    data_start_v && data_parity_v && data_stop_v;

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
        $display("[%0t] [GEN] ----------- Random packets generation done -----------", $time);
        `endif

        return tr;
    endfunction

    
    //----------------------------------------------------------------------
    // Random helper functions (unchanged)
    //----------------------------------------------------------------------
    function automatic byte unsigned rand_biased_byte();
        int r;
        byte unsigned val;
        int unsigned tmp;
        r = $urandom_range(0,9);
        case (r)
            0: val = 8'h00;
            1: val = 8'hFF;
            default: begin
                tmp = $urandom_range(1,254);
                val = tmp[7:0];
            end
        endcase
        return val;
    endfunction

    function automatic byte unsigned rand_biased_addr();
        return rand_biased_byte();
    endfunction

    function automatic bit rand_biased_start_bit(input bit force_correct);
        int r;
        if (force_correct) return 1'b0;
        r = $urandom_range(0,9);
        case (r)
            0,1: return 1'b1;
            default: return 1'b0;
        endcase
    endfunction

    function automatic bit rand_biased_stop_bit(input bit force_correct);
        int r;
        if (force_correct) return 1'b1;
        r = $urandom_range(0,9);
        case (r)
            0,1: return 1'b0;
            default: return 1'b1;
        endcase
    endfunction

    function automatic bit rand_biased_parity_bit(input byte unsigned data, input bit force_correct);
        int r;
        bit correct = (^data);
        if (force_correct) return correct;
        r = $urandom_range(0,9);
        case (r)
            0,1,2: return ~correct;
            default: return correct;
        endcase
    endfunction

endclass : random_tpgen






