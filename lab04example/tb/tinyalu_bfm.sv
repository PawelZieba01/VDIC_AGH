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
interface tinyalu_bfm;
import tinyalu_tb_pkg::*;

bit [7:0] A;
bit [7:0] B;
bit clk;
bit reset_n;
wire [2:0] op;
bit start;
wire done;
wire [15:0] result;
operation_t op_set;

assign op = op_set;

initial begin
    clk = 0;
    forever begin
        #10;
        clk = ~clk;
    end
end


task reset_alu();
    `ifdef DEBUG
    $display("%0t DEBUG: reset_alu", $time);
    `endif
    start   = 1'b0;
    reset_n = 1'b0;
    @(negedge clk);
    reset_n = 1'b1;
endtask : reset_alu


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
            start = 1'b0;
        end
        default: begin : case_default
            while(!done) @(negedge clk);
            start = 1'b0;
            @(negedge clk);
        end
    endcase

endtask : send_op

endinterface : tinyalu_bfm


