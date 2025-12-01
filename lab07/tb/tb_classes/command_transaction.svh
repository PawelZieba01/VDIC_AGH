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
class command_transaction extends uvm_transaction;
    `uvm_object_utils(command_transaction)

//------------------------------------------------------------------------------
// transaction variables
//------------------------------------------------------------------------------

    rand byte unsigned data;
    rand byte unsigned addr;
    uart_port_t port;
    rand bit stop_bit_valid;
    rand bit parity_bit_valid;
    rand bit start_bit_valid;
    
    operation_t op;
//------------------------------------------------------------------------------
// constraints
//------------------------------------------------------------------------------

    constraint c_data_addr {
        data dist { 8'h00 := 2, [8'h01:8'hFE] := 1, 8'hFF := 2 };
        addr dist { 8'h00 := 2, [8'h01:8'hFE] := 1, 8'hFF := 2 };
    }

    constraint c_flags {
        stop_bit_valid   dist { 1 := 8, 0 := 2 };  // 80% poprawnych, 20% błędnych
        parity_bit_valid dist { 1 := 7, 0 := 3 };  // 70% poprawnych, 30% błędnych
        start_bit_valid  dist { 1 := 10, 0 := 0 };  
    }
    
//------------------------------------------------------------------------------
// transaction functions: do_copy, clone_me, do_compare, convert2string
//------------------------------------------------------------------------------

    function void do_copy(uvm_object rhs);
        command_transaction copied_transaction_h;

        if(rhs == null)
            `uvm_fatal("COMMAND TRANSACTION", "Tried to copy from a null pointer")

        super.do_copy(rhs); // copy all parent class data

        if(!$cast(copied_transaction_h,rhs))
            `uvm_fatal("COMMAND TRANSACTION", "Tried to copy wrong type.")

        data                = copied_transaction_h.data;
        addr                = copied_transaction_h.addr;
        stop_bit_valid      = copied_transaction_h.stop_bit_valid;
        parity_bit_valid    = copied_transaction_h.parity_bit_valid;
        start_bit_valid     = copied_transaction_h.start_bit_valid;
        op                  = copied_transaction_h.op;

    endfunction : do_copy


    function command_transaction clone_me();
        
        command_transaction clone;
        uvm_object tmp;

        tmp = this.clone();
        $cast(clone, tmp);
        return clone;
        
    endfunction : clone_me


    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        
        command_transaction compared_transaction_h;
        bit same;

        if (rhs==null) `uvm_fatal("RANDOM TRANSACTION",
                "Tried to do comparison to a null pointer");

        if (!$cast(compared_transaction_h,rhs))
            same = 0;
        else
            same = super.do_compare(rhs, comparer) &&
            (compared_transaction_h.data == data) &&
            (compared_transaction_h.addr == addr) &&
            (compared_transaction_h.port == port);

        return same;
        
    endfunction : do_compare


    function string convert2string();
        string s;
        s = $sformatf("addr: 0x%2h  data: 0x%2h  stop_bit_valid: 0b%b  parity_bit_valid: 0b%b  port: %s  op: %s", addr, data, stop_bit_valid, parity_bit_valid, port.name(), op.name());
        return s;
    endfunction : convert2string

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new (string name = "");
        super.new(name);
    endfunction : new

endclass : command_transaction
