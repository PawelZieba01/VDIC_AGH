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
class scoreboard extends uvm_subscriber #(shortint);
    `uvm_component_utils(scoreboard)

//------------------------------------------------------------------------------
// local typedefs
//------------------------------------------------------------------------------
    typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result;

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
//    virtual tinyalu_bfm bfm;
    uvm_tlm_analysis_fifo #(command_s) cmd_f;

    local test_result tr = TEST_PASSED; // the result of the current test

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

//------------------------------------------------------------------------------
// print the PASSED/FAILED in color
//------------------------------------------------------------------------------
    local function void print_test_result (test_result r);
        if(tr == TEST_PASSED) begin
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
            $write ("-----------------------------------\n");
            $write ("----------- Test PASSED -----------\n");
            $write ("-----------------------------------");
            set_print_color(COLOR_DEFAULT);
            $write ("\n");
        end
        else begin
            set_print_color(COLOR_BOLD_BLACK_ON_RED);
            $write ("-----------------------------------\n");
            $write ("----------- Test FAILED -----------\n");
            $write ("-----------------------------------");
            set_print_color(COLOR_DEFAULT);
            $write ("\n");
        end
    endfunction

//------------------------------------------------------------------------------
// function to calculate the expected ALU result
//------------------------------------------------------------------------------
    local function shortint get_expected(
            bit [7:0] A,
            bit [7:0] B,
            operation_t op_set
        );
        shortint ret;
    `ifdef DEBUG
        $display("%0t DEBUG: get_expected(%0d,%0d,%0d)",$time, A, B, op_set);
    `endif
        case(op_set)
            and_op : ret = A & B;
            add_op : ret = A + B;
            mul_op : ret = A * B;
            xor_op : ret = A ^ B;
            default: begin
                $error("%0t INTERNAL ERROR. get_expected: unexpected case argument: %s", $time, op_set);
                return shortint'(-1);
            end
        endcase
        return(ret);
    endfunction

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        cmd_f = new ("cmd_f", this);
    endfunction : build_phase


//------------------------------------------------------------------------------
// subscriber write function
//------------------------------------------------------------------------------
    function void write(shortint t);
        shortint predicted_result;
        command_s cmd;
        cmd.A            = 0;
        cmd.B            = 0;
        cmd.op           = no_op;
        do
            if (!cmd_f.try_get(cmd))
                $fatal(1, "Missing command in self checker");
        while ((cmd.op == no_op) || (cmd.op == rst_op));

        predicted_result = get_expected(cmd.A, cmd.B, cmd.op);

        SCOREBOARD_CHECK:
        assert (predicted_result == t) begin
           `ifdef DEBUG
            $display("%0t Test passed for A=%0d B=%0d op_set=%0d", $time, cmd.A, cmd.B, cmd.op);
            `endif
        end
        else begin
            $error ("FAILED: A: %0h  B: %0h  op: %s result: %0h", cmd.A, cmd.B, cmd.op.name(), t);
            tr = TEST_FAILED;
        end
    endfunction : write

//------------------------------------------------------------------------------
// report phase
//------------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        print_test_result(tr);
    endfunction : report_phase

endclass : scoreboard






