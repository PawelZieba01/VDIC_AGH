// ============================================================================
//  Class: scoreboard
//  Description:
//      Functional scoreboard for the UART switch testbench.
//      Converted from module form with identical behavior.
//      Uses execute() as main entry point.
// ============================================================================

class scoreboard;
    

    // Handle to the testbench BFM interface
    virtual switch_bfm bfm;

    // Constructor
    function new(virtual switch_bfm bfm);   
        this.bfm = bfm;
    endfunction


    // =========================================================================
    //  Main comparison process (was initial block)
    // =========================================================================
    function void execute();
        fork
            automatic fifomult_tb_pkg::uart_transaction_t gen_tr, mon_tr;
            begin : scoreboard_blk
                bfm.test_result = TEST_PASSED; 
 
                `ifdef DEBUG
                $display("[%0t] [SB] Scoreboard started", $time);
                `endif

                // Wait until both mailboxes are properly initialized
                wait (bfm.gen2sb_mb != null && bfm.mon2sb_mb != null);

                // -----------------------------------------------------------------
                // Infinite comparison loop
                // -----------------------------------------------------------------
                forever begin
                    bfm.gen2sb_mb.get(gen_tr);
                    bfm.mon2sb_mb.get(mon_tr);

                    // Handle simulation finish request
                    if (gen_tr.finish_sim) begin
                        `ifdef DEBUG
                        $display("[%0t] [SB] Finish_sim received — scoreboard exiting", $time);
                        `endif                        
                        $finish;
                    end

                    // -----------------------------------------------------------
                    // Case 1: Invalid packet (GEN says invalid)
                    // -----------------------------------------------------------
                    if (gen_tr.valid == 1'b0) begin
                        if (!mon_tr.empty_packet) begin
                            bfm.test_result = TEST_FAILED;
                            `ifdef DEBUG
                            $display("[%0t] [SB] ERROR: GEN marked packet INVALID but MON provided a non-empty packet", $time);
                            `endif
                            print_mismatch(gen_tr, mon_tr);
                        end
                    end

                    // -----------------------------------------------------------
                    // Case 2: Valid packet (GEN expects valid MON result)
                    // -----------------------------------------------------------
                    else begin
                        if (mon_tr.empty_packet) begin
                            bfm.test_result = TEST_FAILED;
                            `ifdef DEBUG
                            $display("[%0t] [SB] ERROR: GEN marked packet VALID but MON reported EMPTY packet", $time);
                            `endif
                            print_mismatch(gen_tr, mon_tr);
                        end
                        else begin
                            if ((gen_tr.switch_packet.addr.data  != mon_tr.switch_packet.addr.data)  ||
                                (gen_tr.switch_packet.data.data  != mon_tr.switch_packet.data.data)  ||
                                (gen_tr.port                    != mon_tr.port)                     ||
                                (gen_tr.switch_packet.addr.start != mon_tr.switch_packet.addr.start) ||
                                (gen_tr.switch_packet.addr.parity!= mon_tr.switch_packet.addr.parity)||
                                (gen_tr.switch_packet.addr.stop  != mon_tr.switch_packet.addr.stop)  ||
                                (gen_tr.switch_packet.data.start != mon_tr.switch_packet.data.start) ||
                                (gen_tr.switch_packet.data.parity!= mon_tr.switch_packet.data.parity)||
                                (gen_tr.switch_packet.data.stop  != mon_tr.switch_packet.data.stop)) begin
                                bfm.test_result = TEST_FAILED;
                                print_mismatch(gen_tr, mon_tr);
                            end
                        end
                    end
                end
            end
        join_none
    endfunction


    // =========================================================================
    //  Helper task: pretty-print mismatch details
    // =========================================================================
    task automatic print_mismatch(input uart_transaction_t gen_tr, input uart_transaction_t mon_tr);
        print_scoreboard_comparison_str(gen_tr, mon_tr);
    endtask


    // =========================================================================
    //  Pretty printing utility
    // =========================================================================
    function automatic void print_scoreboard_comparison_str(
        input uart_transaction_t gen_tr,
        input uart_transaction_t mon_tr
    );
        string gen_addr_s, gen_data_s, gen_port_s;
        string mon_addr_s, mon_data_s, mon_port_s;
        string yellow_on = "\033\[1;37m\033\[103m";
        string red_on    = "\033\[1;31m";
        string color_off = "\033\[0m";

        $write("[%0t] [SB] %s------------------------- ERROR: Mismatch between GEN and MON! -------------------------%s\n",
            $time, red_on, color_off);

        gen_addr_s = $sformatf("0x%02h", gen_tr.switch_packet.addr.data);
        gen_data_s = $sformatf("0x%02h", gen_tr.switch_packet.data.data);
        case(gen_tr.port)
            SOUT0: gen_port_s = "SOUT0";
            SOUT1: gen_port_s = "SOUT1";
            SOUTX: gen_port_s = "SOUTX";
            default: gen_port_s = "???";
        endcase

        mon_addr_s = $sformatf("0x%02h", mon_tr.switch_packet.addr.data);
        mon_data_s = $sformatf("0x%02h", mon_tr.switch_packet.data.data);
        case(mon_tr.port)
            SOUT0: mon_port_s = "SOUT0";
            SOUT1: mon_port_s = "SOUT1";
            SOUTX: mon_port_s = "SOUTX";
            default: mon_port_s = "???";
        endcase

        $write("[%0t] [SB] %s     %-12s %-12s %-8s %-8s %-15s %-16s %-6s%s\n",
            $time, yellow_on, "ADDR", "DATA", "PORT", "VALID", "", "DETAILS", "", color_off);

        $write("[%0t] [SB] %sGEN: %-12s %-12s %-8s %-0b     |     ADDR(s=%b,p=%b,t=%b) DATA(s=%b,p=%b,st=%b)%s\n",
            $time, yellow_on,
            gen_addr_s, gen_data_s, gen_port_s, gen_tr.valid,
            gen_tr.switch_packet.addr.start, gen_tr.switch_packet.addr.parity, gen_tr.switch_packet.addr.stop,
            gen_tr.switch_packet.data.start, gen_tr.switch_packet.data.parity, gen_tr.switch_packet.data.stop,
            color_off);

        $write("[%0t] [SB] %sMON: %-12s %-12s %-8s %-0b     |     ADDR(s=%b,p=%b,t=%b) DATA(s=%b,p=%b,st=%b)%s\n",
            $time, yellow_on,
            mon_addr_s, mon_data_s, mon_port_s, mon_tr.valid,
            mon_tr.switch_packet.addr.start, mon_tr.switch_packet.addr.parity, mon_tr.switch_packet.addr.stop,
            mon_tr.switch_packet.data.start, mon_tr.switch_packet.data.parity, mon_tr.switch_packet.data.stop,
            color_off);
    endfunction 


    // =========================================================================
    //  Final phase: print test result
    // =========================================================================
    function automatic void report();
        print_test_result(bfm.test_result);
    endfunction


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
