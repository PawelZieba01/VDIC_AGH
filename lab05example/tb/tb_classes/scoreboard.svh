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
class scoreboard extends uvm_component;
    `uvm_component_utils(scoreboard)

//------------------------------------------------------------------------------
// local typedefs
//------------------------------------------------------------------------------
    protected typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result;

    protected typedef struct packed {
        bit [7:0] A;
        bit [7:0] B;
        operation_t op_set;
        shortint result;
    } data_packet_t;

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    protected virtual tinyalu_bfm bfm;
    protected test_result tr = TEST_PASSED; // the result of the current test

    // fifo for storing input and expected data
    protected data_packet_t sb_data_q [$];

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

//------------------------------------------------------------------------------
// calculate expected result
//------------------------------------------------------------------------------

    protected function logic [15:0] get_expected(
            bit [7:0] A,
            bit [7:0] B,
            operation_t op_set
        );
        bit [15:0] ret;
    `ifdef DEBUG
        $display("%0t DEBUG: get_expected(%0d,%0d,%0d)",$time, A, B, op_set);
    `endif
        case(op_set)
            and_op : ret = A & B;
            add_op : ret = A + B;
            mul_op : ret = A * B;
            xor_op : ret = A ^ B;
            default: begin
                $display("%0t INTERNAL ERROR. get_expected: unexpected case argument: %s", $time, op_set);
                tr       = TEST_FAILED;
                return -1;
            end
        endcase
        return(ret);
    endfunction

//------------------------------------------------------------------------------
// local tasks
//------------------------------------------------------------------------------
    protected task store_cmd();
        forever begin:scoreboard_fe_blk
            @(posedge bfm.clk);
            if(bfm.start == 1)begin
                case(bfm.op_set)
                    add_op, and_op, mul_op, xor_op : begin
                        sb_data_q.push_front(
                            data_packet_t'({bfm.A,bfm.B,bfm.op_set,get_expected(bfm.A, bfm.B, bfm.op_set)})
                        );
                        while(!bfm.done) @(negedge bfm.clk);
                    end
                endcase
            end
        end
    endtask

    protected task process_data_from_dut();
        forever begin : scoreboard_be_blk
            @(negedge bfm.clk) ;
            if(bfm.done) begin:verify_result
                data_packet_t dp;

                dp = sb_data_q.pop_back();

                CHK_RESULT: assert(bfm.result === dp.result) begin
           `ifdef DEBUG
                    $display("%0t Test passed for A=%0d B=%0d op_set=%0d", $time, dp.A, dp.B, dp.op_set);
           `endif
                end
                else begin
                    tr = TEST_FAILED;
                    $error("%0t Test FAILED for A=%0d B=%0d op_set=%0d\nExpected: %d  received: %d",
                        $time, dp.A, dp.B, dp.op_set , dp.result, bfm.result);
                end;

            end
        end : scoreboard_be_blk
    endtask

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db #(virtual tinyalu_bfm)::get(null, "*","bfm", bfm))
            $fatal(1,"Failed to get BFM");
    endfunction : build_phase

//------------------------------------------------------------------------------
// run phase
//------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        fork
            store_cmd();
            process_data_from_dut();
        join_none
    endtask : run_phase

//------------------------------------------------------------------------------
// print the PASSED/FAILED in color
//------------------------------------------------------------------------------
    protected function void print_test_result (test_result r);
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
// report phase
//------------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        print_test_result(tr);
    endfunction : report_phase

endclass : scoreboard