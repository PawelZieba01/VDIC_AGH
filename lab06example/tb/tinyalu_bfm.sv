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
import tinyalu_tb_pkg::*;

//------------------------------------------------------------------------------
// the interface
//------------------------------------------------------------------------------

interface tinyalu_bfm;

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
assign op = op_set;

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

task send_op(input byte iA, input byte iB, input operation_t iop, shortint result);

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
            start = 1'b0;
        end
        default: begin : case_default
            while(!done) @(negedge clk);
            start = 1'b0;
            @(negedge clk);
        end
    endcase

endtask : send_op


//------------------------------------------------------------------------------
// convert binary op code to enum
//------------------------------------------------------------------------------

function operation_t op2enum();
    operation_t opi;
    if( ! $cast(opi,op) )
        $fatal(1, "Illegal operation on op bus");
    return opi;
endfunction : op2enum

//------------------------------------------------------------------------------
// write command monitor
//------------------------------------------------------------------------------

always @(posedge clk) begin : op_monitor
    static bit in_command = 0;
    command_s command;
    if (start) begin : start_high
        if (!in_command) begin : new_command
            command.A  = A;
            command.B  = B;
            command.op = op2enum();
            command_monitor_h.write_to_monitor(command);
            in_command = (command.op != no_op);
        end : new_command
    end : start_high
    else // start low
        in_command = 0;
end : op_monitor

always @(negedge reset_n) begin : rst_monitor
    command_s command;
    command.op = rst_op;
    if (command_monitor_h != null) //guard against VCS time 0 negedge
        command_monitor_h.write_to_monitor(command);
end : rst_monitor


//------------------------------------------------------------------------------
// write result monitor
//------------------------------------------------------------------------------

initial begin : result_monitor_thread
    forever begin
        @(posedge clk) ;
        if (done)
            result_monitor_h.write_to_monitor(result);
    end
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



endinterface : tinyalu_bfm
