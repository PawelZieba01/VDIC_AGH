// ============================================================================
//  Class: coverage
//  Description:
//      Functional coverage collection class for the UART switch testbench.
//      Converted from module form with identical functionality.
//      Collects coverage on address, routing/data, and reset behavior.
//
//  Responsibilities:
//      - Receives transactions from gen2cov_mb
//      - Samples covergroups for various DUT behaviors
//      - Reports final coverage summary at simulation end
// ============================================================================
import fifomult_tb_pkg::*;
class coverage;
   

    // Handle do interfejsu BFM
    virtual switch_bfm bfm;

    // =========================================================================
    //  Coverage storage variables
    // =========================================================================
    byte unsigned addr_cov;           // Current address value under coverage
    bit           prog_cov;           // Indicates programming phase

    byte unsigned port_cov;           // Target port observed
    byte unsigned data_cov;           // Data byte observed
    bit           packet_valid_cov;   // Indicates valid/invalid packet
    bit [2:0]     invalid_type_cov;   // Error flags: {start_err, stop_err, parity_err}


    // =========================================================================
    //  Address Coverage — Routing Table Programming
    // =========================================================================
    covergroup address_cov ();
        option.name = "cg_address";

        coverpoint addr_cov {
            bins all_addrs_prog[]    = {[0:255]} iff (prog_cov == 1);
            bins all_addrs_nonprog[] = {[0:255]} iff (prog_cov == 0);
        }
    endgroup
    //address_cov addr_cg;


    // =========================================================================
    //  Routing & Data Coverage — Packet Forwarding and Error Conditions
    // =========================================================================
    covergroup routing_data_cov ();
        option.name = "cg_routing_and_data";

        cp_programmed: coverpoint port_cov {
            bins sout0_programmed = {8'h00} iff (prog_cov == 1);
            bins sout1_programmed = {8'h01} iff (prog_cov == 1);
        }

        cp_valid_to_port: coverpoint packet_valid_cov {
            bins valid_sout0   = {1'b1} iff (port_cov == 8'h00);
            bins valid_sout1   = {1'b1} iff (port_cov == 8'h01);
            bins invalid_sout0 = {1'b0} iff (port_cov == 8'h00);
            bins invalid_sout1 = {1'b0} iff (port_cov == 8'h01);
        }

        cp_invalid_types: coverpoint invalid_type_cov {
            bins no_error     = {3'b000};
            bins stop_error   = {3'b010};
            bins parity_error = {3'b001};
            bins stop_parity  = {3'b011};
        }

        cp_all_data: coverpoint data_cov {
            bins all_data_values[] = {[0:255]} iff (prog_cov == 0);
        }
    endgroup
    //routing_data_cov rout_data_cg;


    // =========================================================================
    //  Reset Coverage — Verifies Correct Reset Transitions
    // =========================================================================
    covergroup reset_cov ();
        option.name = "cg_reset";
        coverpoint bfm.rst_n {
            bins rst_low2high[] = (0 => 1);
            bins rst_high2low[] = (1 => 0);
        }
    endgroup
    //reset_cov reset_cg;


    // =========================================================================
    //  Konstruktor
    // =========================================================================
    function new(virtual switch_bfm bfm);
        this.bfm = bfm;
        address_cov      = new();
        routing_data_cov = new();
        reset_cov     = new();
    endfunction


    // =========================================================================
    //  Główna funkcja execute() — uruchamia procesy pokrycia
    // =========================================================================
    function void execute();
        fork
            begin : coverage_from_generator
                fifomult_tb_pkg::uart_transaction_t tr;

                // Synchronizacja — początkowe opóźnienie
                repeat (50*CLKS_PER_BIT) @(posedge bfm.clk);

                forever begin
                    bfm.gen2cov_mb.get(tr);

                    // Wyodrębnienie pól z transakcji
                    addr_cov         = tr.switch_packet.addr.data;
                    prog_cov         = tr.prog;
                    packet_valid_cov = tr.valid;
                    port_cov         = tr.switch_packet.data.data;
                    invalid_type_cov = {(!tr.valid_start), (!tr.valid_stop), (!tr.valid_parity)};
                    data_cov         = tr.switch_packet.data.data;

                    // Próbkowanie grup pokrycia
                    address_cov.sample();
                    routing_data_cov.sample();
                end
            end

            // Ciągłe próbkowanie resetu
            begin
                forever begin
                    @(posedge bfm.clk);
                    reset_cov.sample();
                end
            end
        join_none
    endfunction


    // =========================================================================
    //  Final Coverage Summary — wywoływane po zakończeniu symulacji
    // =========================================================================
    function void report();
        $display("============================================================");
        $display(" Functional Coverage Summary:");
        $display(" -----------------------------------------------------------");
        $display("  Address coverage        : %.2f%%", address_cov.get_coverage());
        $display("  Routing & Data coverage : %.2f%%", routing_data_cov.get_coverage());
        $display("  Reset coverage          : %.2f%%", reset_cov.get_coverage());
        $display(" -----------------------------------------------------------");
        $display("============================================================");
    endfunction

endclass : coverage
