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
                `ifdef DEBUG
                //$display("[%0t] [SB] Waiting for command from GEN...", $time);
                `endif
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
            `uvm_info (print_color("SELF CHECKER", COLOR_BOLD_BLACK_ON_YELLOW), {print_color("PASS:", COLOR_BOLD_BLACK_ON_GREEN), " ", print_color(data_str, COLOR_BLUE_ON_WHITE),"\n"}, UVM_LOW)
        end

        // mon_tr = t.restult_tr;
        // gen_tr = cmd.tr;

        // // -----------------------------------------------------------
        // // Case 1: Invalid packet (GEN says invalid)
        // // -----------------------------------------------------------
        // if (gen_tr.valid == 1'b0) begin
        //     if (!mon_tr.empty_packet) begin
        //         test_res = TEST_FAILED;
        //         `ifdef DEBUG
        //         $display("[%0t] [SB] ERROR: GEN marked packet INVALID but MON provided a non-empty packet", $time);
        //         `endif
        //         print_mismatch(gen_tr, mon_tr);
        //     end
        // end

        // // -----------------------------------------------------------
        // // Case 2: Valid packet (GEN expects valid MON result)
        // // -----------------------------------------------------------
        // else begin
        //     if (mon_tr.empty_packet) begin
        //         test_res = TEST_FAILED;
        //         `ifdef DEBUG
        //         $display("[%0t] [SB] ERROR: GEN marked packet VALID but MON reported EMPTY packet", $time);
        //         `endif
        //         print_mismatch(gen_tr, mon_tr);
        //     end
        //     else begin
        //         if ((gen_tr.switch_packet.addr.data  != mon_tr.switch_packet.addr.data)  ||
        //             (gen_tr.switch_packet.data.data  != mon_tr.switch_packet.data.data)  ||
        //             (gen_tr.port                    != mon_tr.port)                     ||
        //             (gen_tr.switch_packet.addr.start != mon_tr.switch_packet.addr.start) ||
        //             (gen_tr.switch_packet.addr.parity!= mon_tr.switch_packet.addr.parity)||
        //             (gen_tr.switch_packet.addr.stop  != mon_tr.switch_packet.addr.stop)  ||
        //             (gen_tr.switch_packet.data.start != mon_tr.switch_packet.data.start) ||
        //             (gen_tr.switch_packet.data.parity!= mon_tr.switch_packet.data.parity)||
        //             (gen_tr.switch_packet.data.stop  != mon_tr.switch_packet.data.stop)) begin
        //             test_res = TEST_FAILED;
        //             print_mismatch(gen_tr, mon_tr);
        //         end
        //     end
        // end

        
    endfunction : write


    
    // =========================================================================
    //  Helper task: pretty-print mismatch details
    // =========================================================================
    // function automatic void print_mismatch(input uart_transaction_t gen_tr, input uart_transaction_t mon_tr);
    //     print_scoreboard_comparison_str(gen_tr, mon_tr);
    // endfunction


    // =========================================================================
    //  Pretty printing utility
    // =========================================================================
    // function automatic void print_scoreboard_comparison_str(
    //     input uart_transaction_t gen_tr,
    //     input uart_transaction_t mon_tr
    // );
    //     string gen_addr_s, gen_data_s, gen_port_s;
    //     string mon_addr_s, mon_data_s, mon_port_s;
    //     string yellow_on = "\033\[1;37m\033\[103m";
    //     string red_on    = "\033\[1;31m";
    //     string color_off = "\033\[0m";

    //     $write("[%0t] [SB] %s------------------------- ERROR: Mismatch between GEN and MON! -------------------------%s\n",
    //         $time, red_on, color_off);

    //     gen_addr_s = $sformatf("0x%02h", gen_tr.switch_packet.addr);
    //     gen_data_s = $sformatf("0x%02h", gen_tr.switch_packet.data);
    //     case(gen_tr.port)
    //         SOUT0: gen_port_s = "SOUT0";
    //         SOUT1: gen_port_s = "SOUT1";
    //         SOUTX: gen_port_s = "SOUTX";
    //         default: gen_port_s = "???";
    //     endcase

    //     mon_addr_s = $sformatf("0x%02h", mon_tr.switch_packet.addr);
    //     mon_data_s = $sformatf("0x%02h", mon_tr.switch_packet.data);
    //     case(mon_tr.port)
    //         SOUT0: mon_port_s = "SOUT0";
    //         SOUT1: mon_port_s = "SOUT1";
    //         SOUTX: mon_port_s = "SOUTX";
    //         default: mon_port_s = "???";
    //     endcase

    //     $write("[%0t] [SB] %s     %-12s %-12s %-8s %-8s %-15s %-16s %-6s%s\n",
    //         $time, yellow_on, "ADDR", "DATA", "PORT", "VALID", "", "DETAILS", "", color_off);

    //     $write("[%0t] [SB] %sGEN: %-12s %-12s %-8s %-0s     |     ADDR(s=%b,p=%b,t=%b) DATA(s=%b,p=%b,st=%b)%s\n",
    //         $time, yellow_on,
    //         gen_addr_s, gen_data_s, gen_port_s, "V",
    //         gen_tr.switch_packet.addr.start, gen_tr.switch_packet.addr.parity, gen_tr.switch_packet.addr.stop,
    //         gen_tr.switch_packet.data.start, gen_tr.switch_packet.data.parity, gen_tr.switch_packet.data.stop,
    //         color_off);

    //     $write("[%0t] [SB] %sMON: %-12s %-12s %-8s %-0s     |     ADDR(s=%b,p=%b,t=%b) DATA(s=%b,p=%b,st=%b)%s\n",
    //         $time, yellow_on,
    //         mon_addr_s, mon_data_s, mon_port_s, "V",
    //         mon_tr.switch_packet.addr.start, mon_tr.switch_packet.addr.parity, mon_tr.switch_packet.addr.stop,
    //         mon_tr.switch_packet.data.start, mon_tr.switch_packet.data.parity, mon_tr.switch_packet.data.stop,
    //         color_off);
    // endfunction 




    // =========================================================================
    //  Utility: ANSI color control
    // =========================================================================
    function void set_print_color ( print_color_t c );
        string ctl;
        case(c)
            COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m";
            COLOR_BOLD_BLACK_ON_RED   : ctl  = "\033\[1;30m\033\[101m";
            COLOR_BOLD_BLACK_ON_YELLOW: ctl  = "\033\[1;30m\033\[103m";
            COLOR_BOLD_BLUE_ON_WHITE  : ctl  = "\033\[1;34m\033\[107m";
            COLOR_BLUE_ON_WHITE       : ctl  = "\033\[0;34m\033\[107m";
            COLOR_DEFAULT             : ctl  = "\033\[0m";
            default : begin
                $error("set_print_color: invalid color code");
                ctl = "";
            end
        endcase
        $write(ctl);
    endfunction

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
                $error("set_print_color: invalid color code");
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
