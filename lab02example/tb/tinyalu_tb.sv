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

 History:
 2021-10-05 RSz, AGH UST - test modified to send all the data on negedge clk
 and check the data on the correct clock edge (covergroup on posedge
 and scoreboard on negedge). Scoreboard and coverage removed.
 */
module top;

//------------------------------------------------------------------------------
// Type definitions
//------------------------------------------------------------------------------

    typedef enum bit[2:0] {
        no_op  = 3'b000,
        add_op = 3'b001,
        and_op = 3'b010,
        xor_op = 3'b011,
        mul_op = 3'b100,
        rst_op = 3'b111
    } operation_t;

    typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result_t;

    typedef enum {
        COLOR_BOLD_BLACK_ON_GREEN,
        COLOR_BOLD_BLACK_ON_RED,
        COLOR_BOLD_BLACK_ON_YELLOW,
        COLOR_BOLD_BLUE_ON_WHITE,
        COLOR_BLUE_ON_WHITE,
        COLOR_DEFAULT
    } print_color_t;

//------------------------------------------------------------------------------
// Local variables
//------------------------------------------------------------------------------

    bit                  [7:0]  A;
    bit                  [7:0]  B;
    bit                         clk;
    bit                         reset_n;
    wire                 [2:0]  op;
    bit                         start;
    wire                        done;
    wire                 [15:0] result;

    operation_t                 op_set;
    assign op = op_set;

    test_result_t               test_result     = TEST_PASSED;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------

    tinyalu DUT (.A, .B, .clk, .op, .reset_n, .start, .done, .result);

//------------------------------------------------------------------------------
// Coverage block
//------------------------------------------------------------------------------

// Covergroup checking the op codes and theri sequences
    covergroup op_cov;

        option.name = "cg_op_cov";

        coverpoint op_set {
            // #A1 test all operations
            bins A1_single_cycle[] = {[add_op : xor_op], rst_op,no_op};
            bins A1_multi_cycle    = {mul_op};

            // #A2 test all operations after reset
            bins A2_rst_opn[]      = (rst_op => [add_op:mul_op]);

            // #A3 test reset after all operations
            bins A3_opn_rst[]      = ([add_op:mul_op] => rst_op);

            // #A4 multiply after single-cycle operation
            bins A4_sngl_mul[]     = ([add_op:xor_op],no_op => mul_op);

            // #A5 single-cycle operation after multiply
            bins A5_mul_sngl[]     = (mul_op => [add_op:xor_op], no_op);

            // #A6 two operations in row
            bins A6_twoops[]       = ([add_op:mul_op] [* 2]);

            // bins manymult = (mul_op [* 3:5]);
        }

    endgroup

// Covergroup checking for min and max arguments of the ALU
    covergroup zeros_or_ones_on_ops;

        option.name = "cg_zeros_or_ones_on_ops";

        all_ops : coverpoint op_set {
            ignore_bins null_ops = {rst_op, no_op};
        }

        a_leg: coverpoint A {
            bins zeros = {'h00};
            bins others= {['h01:'hFE]};
            bins ones  = {'hFF};
        }

        b_leg: coverpoint B {
            bins zeros = {'h00};
            bins others= {['h01:'hFE]};
            bins ones  = {'hFF};
        }

        B_op_00_FF: cross a_leg, b_leg, all_ops {

            // #B1 simulate all zero input for all the operations

            bins B1_add_00          = binsof (all_ops) intersect {add_op} &&
                (binsof (a_leg.zeros) || binsof (b_leg.zeros));

            bins B1_and_00          = binsof (all_ops) intersect {and_op} &&
                (binsof (a_leg.zeros) || binsof (b_leg.zeros));

            bins B1_xor_00          = binsof (all_ops) intersect {xor_op} &&
                (binsof (a_leg.zeros) || binsof (b_leg.zeros));

            bins B1_mul_00          = binsof (all_ops) intersect {mul_op} &&
                (binsof (a_leg.zeros) || binsof (b_leg.zeros));

            // #B2 simulate all one input for all the operations

            bins B2_add_FF          = binsof (all_ops) intersect {add_op} &&
                (binsof (a_leg.ones) || binsof (b_leg.ones));

            bins B2_and_FF          = binsof (all_ops) intersect {and_op} &&
                (binsof (a_leg.ones) || binsof (b_leg.ones));

            bins B2_xor_FF          = binsof (all_ops) intersect {xor_op} &&
                (binsof (a_leg.ones) || binsof (b_leg.ones));

            bins B2_mul_FF          = binsof (all_ops) intersect {mul_op} &&
                (binsof (a_leg.ones) || binsof (b_leg.ones));

            bins B2_mul_max         = binsof (all_ops) intersect {mul_op} &&
                (binsof (a_leg.ones) && binsof (b_leg.ones));

            ignore_bins others_only =
                binsof(a_leg.others) && binsof(b_leg.others);
        }

    endgroup

    op_cov                      oc;
    zeros_or_ones_on_ops        c_00_FF;

    initial begin : coverage
        oc      = new();
        c_00_FF = new();
        forever begin : sample_cov
            @(posedge clk);
            if(start || !reset_n) begin
                oc.sample();
                c_00_FF.sample();

                /* #1step delay is necessary before checking for the coverage
                 * as the .sample methods run in parallel threads
                 */
                #1step;
                if($get_coverage() == 100) break; //disable, if needed

                // you can print the coverage after each sample
//            $strobe("%0t coverage: %.4g\%",$time, $get_coverage());
            end
        end
    end : coverage

//------------------------------------------------------------------------------
// Clock generator
//------------------------------------------------------------------------------

    initial begin : clk_gen_blk
        clk = 0;
        forever begin : clk_frv_blk
            #10;
            clk = ~clk;
        end
    end

//------------------------------------------------------------------------------
// Tester
//------------------------------------------------------------------------------

//---------------------------------
// Random data generation functions

    function operation_t get_op();
        bit [2:0] op_choice;
        op_choice = 3'($random);
        case (op_choice)
            3'b000 : return no_op;
            3'b001 : return add_op;
            3'b010 : return and_op;
            3'b011 : return xor_op;
            3'b100 : return mul_op;
            3'b101 : return no_op;
            3'b110 : return rst_op;
            3'b111 : return rst_op;
        endcase // case (op_choice)
    endfunction : get_op

//---------------------------------
    function byte get_data();

        bit [1:0] zero_ones;

        zero_ones = 2'($random);

        if (zero_ones == 2'b00)
            return 8'h00;
        else if (zero_ones == 2'b11)
            return 8'hFF;
        else
            return 8'($random);
    endfunction : get_data

//------------------------
// Tester main

    initial begin : tpgen
        reset_alu();
        repeat (10000) begin : tpgen_main_blk
            @(negedge clk);
            op_set = get_op();
            A      = get_data();
            B      = get_data();
            start  = 1'b1;
            case (op_set) // handle the start signal
                no_op: begin : case_no_op_blk
                    @(negedge clk);
                    start                             = 1'b0;
                end
                rst_op: begin : case_rst_op_blk
                    reset_alu();
                end
                default: begin : case_default_blk
                    wait(done);
                    @(negedge clk);
                    start                             = 1'b0;
                end : case_default_blk
            endcase // case (op_set)
        end : tpgen_main_blk
        $finish;
    end : tpgen

//------------------------------------------------------------------------------
// reset task
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
// calculate expected result
//------------------------------------------------------------------------------

    function logic [15:0] get_expected(
            bit [7:0] A,
            bit [7:0] B,
            operation_t op_set
        );
        bit [15:0] ret;
    `ifdef DEBUG
        $display("%0t DEBUG: get_expected(%0d,%0d,%0d)",$time, A, B, op_set);
    `endif
        case(op_set)
            and_op : ret    = A & B;
            add_op : ret    = A + B;
            mul_op : ret    = A * B;
            xor_op : ret    = A ^ B;
            default: begin
                $display("%0t INTERNAL ERROR. get_expected: unexpected case argument: %s", $time, op_set);
                test_result = TEST_FAILED;
                return -1;
            end
        endcase
        return(ret);
    endfunction : get_expected

//------------------------------------------------------------------------------
// Temporary. The scoreboard will be later used for checking the data
    final begin : finish_of_the_test
        print_test_result(test_result);
    end

//------------------------------------------------------------------------------
// Other functions
//------------------------------------------------------------------------------

// used to modify the color of the text printed on the terminal
    function void set_print_color ( print_color_t c );
        string ctl;
        case(c)
            COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m";
            COLOR_BOLD_BLACK_ON_RED : ctl    = "\033\[1;30m\033\[101m";
            COLOR_BOLD_BLACK_ON_YELLOW : ctl = "\033\[1;30m\033\[103m";
            COLOR_BOLD_BLUE_ON_WHITE : ctl   = "\033\[1;34m\033\[107m";
            COLOR_BLUE_ON_WHITE : ctl        = "\033\[0;34m\033\[107m";
            COLOR_DEFAULT : ctl              = "\033\[0m\n";
            default : begin
                $error("set_print_color: bad argument");
                ctl                          = "";
            end
        endcase
        $write(ctl);
    endfunction

    function void print_test_result (test_result_t r);
        if(r == TEST_PASSED) begin
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

//-------------------------------------------------------------------
// Scoreboard, part 1 – command receiver and reference model function
//-------------------------------------------------------------------
    bit                         start_prev;
    typedef struct packed {
        bit [7:0] A;
        bit [7:0] B;
        operation_t op_set;
    } data_packet_t;

    data_packet_t               sb_data_q   [$];

    always @(posedge clk) begin:scoreboard_fe_blk
        if(start == 1 && start_prev == 0)begin
            case(op_set)
                add_op, and_op, mul_op, xor_op : begin
                    sb_data_q.push_front(
                        data_packet_t'({A,B,op_set})
                    );
                end
            endcase
        end
        start_prev = start;
    end

//---------------------------------------------------------------
// Scoreboard, part 2 - data checker
//---------------------------------------------------------------

    always @(negedge clk) begin : scoreboard_be_blk

        logic [15:0] expected;

        if(done) begin:verify_result
            data_packet_t dp;

            dp = sb_data_q.pop_back();
            expected = get_expected(dp.A, dp.B, dp.op_set);

            CHK_RESULT: assert(result === expected ) begin
           `ifdef DEBUG
                $display("%0t Test passed for A=%0d B=%0d op_set=%0d", $time, dp.A, dp.B, dp.op_set);
           `endif
            end
            else begin
                test_result = TEST_FAILED;
                $error("%0t Test FAILED for A=%0d B=%0d op_set=%0d\nExpected: %d  received: %d",
                    $time, dp.A, dp.B, dp.op_set, expected, result);
            end;

        end
    end : scoreboard_be_blk

endmodule : top
