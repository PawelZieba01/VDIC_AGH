// ============================================================================
//  Class: scoreboard
//  Description:
//      Functional scoreboard for the UART switch testbench.
//      Converted from module form with identical behavior.
//      Uses execute() as main entry point.
// ============================================================================

class scoreboard extends uvm_subscriber #(result_transaction);
    `uvm_component_utils(scoreboard)
    

    
    uvm_tlm_analysis_fifo #(command_transaction) cmd_f;



    typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result_t;



    local test_result_t test_res = TEST_PASSED; // the result of the current test



    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new


    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        cmd_f = new ("cmd_f", this);
    endfunction : build_phase



    //------------------------------------------------------------------------------
    // report phase
    //------------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        print_test_result(test_res);
    endfunction : report_phase



    //------------------------------------------------------------------------------
    // function to calculate the expected ALU result
    //------------------------------------------------------------------------------

    local function result_transaction predict_result(command_transaction cmd);
        result_transaction predicted;

        predicted = new("predicted");
        
        predicted.result.empty_packet           = !(cmd.start_bit_valid &&
                                                    cmd.parity_bit_valid && 
                                                    cmd.stop_bit_valid);

        predicted.result.switch_packet.addr     = predicted.result.empty_packet ? '0 : cmd.addr;
        predicted.result.switch_packet.data     = predicted.result.empty_packet ? '0 : cmd.data;
        predicted.result.valid_start            = predicted.result.empty_packet ? '0 : cmd.start_bit_valid;
        predicted.result.valid_parity           = predicted.result.empty_packet ? '0 : cmd.parity_bit_valid;
        predicted.result.valid_stop             = predicted.result.empty_packet ? '0 : cmd.stop_bit_valid;
        predicted.result.port                   = predicted.result.empty_packet ? SOUTX : cmd.port;

        return predicted;

    endfunction : predict_result



    //------------------------------------------------------------------------------
    // subscriber write function
    //------------------------------------------------------------------------------
    function void write(result_transaction t);
        command_transaction cmd;
        result_transaction predicted;
        string data_str;
        int timeout;

        timeout = 0;
        do
            if (!cmd_f.try_get(cmd)) begin
                timeout++;
                if (timeout > 4) return;
            end
        while ((cmd.op == prog_op) || (cmd.op == rst_op));


        predicted = predict_result(cmd);

        data_str  = {"\n==>  Command           ", cmd.convert2string(),
            "\n==>  Actual    " , t.convert2string(),
            "\n==>  Predicted ",predicted.convert2string()};

        if (!predicted.compare(t)) begin
            `uvm_error(print_color("SELF CHECKER", COLOR_BOLD_BLACK_ON_YELLOW), {print_color("FAIL:", COLOR_BOLD_BLACK_ON_RED), " ", print_color(data_str, COLOR_BLUE_ON_WHITE), "\n"})
            test_res = TEST_FAILED;
        end
        else begin
            `uvm_info (print_color("SELF CHECKER", COLOR_BOLD_BLACK_ON_YELLOW), {print_color("PASS:", COLOR_BOLD_BLACK_ON_GREEN), " ", print_color(data_str, COLOR_BLUE_ON_WHITE),"\n"}, UVM_HIGH)
        end
    endfunction : write



    function string print_color (string s, print_color_t c );
        string ctl;
        case(c)
            COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m"; 
            COLOR_BOLD_BLACK_ON_RED   : ctl  = "\033\[1;30m\033\[101m";
            COLOR_BOLD_BLACK_ON_YELLOW: ctl  = "\033\[1;30m\033\[103m";
            COLOR_BOLD_BLUE_ON_WHITE  : ctl  = "\033\[1;34m\033\[107m";
            COLOR_BLUE_ON_WHITE       : ctl  = "\033\[1;34m";
            COLOR_DEFAULT             : ctl  = "\033\[0m";
            default : begin
                `uvm_warning("SELF CHECKER","set_print_color: invalid color code")
                ctl = "";
            end
        endcase
        return {ctl, s, "\033\[0m"};
    endfunction



    // =========================================================================
    //  Utility: formatted PASS/FAIL banner printout
    // =========================================================================
    function void print_test_result (test_result_t r);
        $write("\n");
        if (r == TEST_PASSED)
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
        else
            set_print_color(COLOR_BOLD_BLACK_ON_RED);

        $write("-----------------------------------");
        set_print_color(COLOR_DEFAULT);
        $write("\n");

        if (r == TEST_PASSED) begin
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
            $write("----------- Test PASSED -----------");
        end else begin
            set_print_color(COLOR_BOLD_BLACK_ON_RED);
            $write("----------- Test FAILED -----------");
        end

        set_print_color(COLOR_DEFAULT);
        $write("\n");

        if (r == TEST_PASSED)
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
        else
            set_print_color(COLOR_BOLD_BLACK_ON_RED);

        $write("-----------------------------------");
        set_print_color(COLOR_DEFAULT);
        $write("\n");
    endfunction

endclass : scoreboard
