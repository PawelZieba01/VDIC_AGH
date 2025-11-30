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

//------------------------------------------------------------------------------
// the interface
//------------------------------------------------------------------------------

interface tinyalu_bfm import tinyalu_tb_pkg::*; ;

//------------------------------------------------------------------------------
// dut connections
//------------------------------------------------------------------------------

bit [7:0] A;
bit [7:0] B;
bit clk;
bit reset_n;
bit [2:0] op;
bit start;
wire done;
wire [15:0] result;

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

operation_t op_set;
assign op = op_set; // convert from enum to bit

command_monitor command_monitor_h;
result_monitor result_monitor_h;

//------------------------------------------------------------------------------
// DUT reset task
//------------------------------------------------------------------------------

task reset_alu();
    `ifdef DEBUG
    $display("%0t DEBUG: reset_alu", $time);
    `endif
    start   = 1'b0;
    reset_n = 1'b0;
    @(negedge clk);
    reset_n = 1'b1;
endtask : reset_alu

//------------------------------------------------------------------------------
// send transaction to DUT
//------------------------------------------------------------------------------

task send_op(input byte iA, input byte iB, input operation_t iop, output shortint alu_result);

    op_set = iop;
    A      = iA;
    B      = iB;

    start  = 1'b1;
    case (op_set)
        rst_op: begin : case_rst_op
            reset_alu();
        end
        no_op: begin : case_no_op
            @(negedge clk);
            start      = 1'b0;
        end
        default: begin : case_default
            while(!done) @(negedge clk);
            start      = 1'b0;
            alu_result = result; // TODO check result for unknown states
            @(negedge clk);
        end
    endcase

endtask : send_op

//------------------------------------------------------------------------------
// convert binary op code to enum
//------------------------------------------------------------------------------

function operation_t op2enum();
    case(op)
        3'b000 : return no_op;
        3'b001 : return add_op;
        3'b010 : return and_op;
        3'b011 : return xor_op;
        3'b100 : return mul_op;
        default : $fatal(1, "Illegal operation on op bus");
    endcase // case (op)
endfunction : op2enum

//------------------------------------------------------------------------------
// write command monitor
//------------------------------------------------------------------------------

always @(posedge clk) begin : op_monitor
    static bit in_command = 0;
    command_transaction command;
    if (start) begin : start_high
        if (!in_command) begin : new_command
            command_monitor_h.write_to_monitor(A, B, op2enum());
            in_command = (op2enum() != no_op);
        end : new_command
    end : start_high
    else // start low
        in_command = 0;
end : op_monitor

always @(negedge reset_n) begin : rst_monitor
    command_transaction command;
    if (command_monitor_h != null) //guard against VCS time 0 negedge
        command_monitor_h.write_to_monitor(8'($random),0,rst_op);
end : rst_monitor

//------------------------------------------------------------------------------
// write result monitor
//------------------------------------------------------------------------------

initial begin : result_monitor_thread
    forever begin : result_monitor
        @(posedge clk) ;
        if (done)
            result_monitor_h.write_to_monitor(result);
    end : result_monitor
end : result_monitor_thread

//------------------------------------------------------------------------------
// clock generator
//------------------------------------------------------------------------------

initial begin
    clk = 0;
    forever begin
        #10;
        clk = ~clk;
    end
end


endinterface: tinyalu_bfm
