// ============================================================================
//  Module: coverage
//  Description:
//      Functional coverage collection module for the UART switch testbench.
//      This block tracks various behavioral aspects of the DUT including:
//        - Routing table programming
//        - Packet forwarding behavior
//        - Data and address activity
//        - Error condition occurrences
//        - Reset behavior
//
//  Responsibilities:
//      - Collect transactions from generator via gen2cov_mb
//      - Sample dedicated covergroups for address, routing, data, and reset
//      - Provide coverage metrics mapped to specification points (A1–A9)
//      - Report final coverage summary at simulation end
//
//  Author: PZ
//  ----------------------------------------------------------------------------
//  Dependencies:
//      - tb_pkg.sv (defines uart_transaction_t, constants, macros)
//      - tb_if.sv  (interface containing gen2cov_mb and DUT signals)
// ============================================================================

module coverage (tb_if tb);
    import tb_pkg::*;

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
    // -------------------------------------------------------------------------
    //  ✅ Covers:
    //      (A1) Programming routing table to SOUT0 and verifying frame output
    //      (A2) Programming routing table to SOUT1 and verifying frame output
    // =========================================================================
    covergroup address_cov;
        option.name = "cg_address";

        // Address coverage bins differentiate between programmed vs. non-programmed
        coverpoint addr_cov {
            bins all_addrs_prog[]    = {[0:255]} iff (prog_cov == 1);
            bins all_addrs_nonprog[] = {[0:255]} iff (prog_cov == 0);
        }
    endgroup
    address_cov addr_cg;


    // =========================================================================
    //  Routing & Data Coverage — Packet Forwarding and Error Conditions
    // -------------------------------------------------------------------------
    //  ✅ Covers:
    //      (A4) Forward valid packet to SOUT0 — identical output
    //      (A5) Forward valid packet to SOUT1 — identical output
    //      (A6) Forward invalid packet to SOUT0 — no output
    //      (A7) Forward invalid packet to SOUT1 — no output
    //      (A8) Forward packet with incorrect stop bit — no output
    //      (A9) Forward packet with incorrect parity bit — no output
    // =========================================================================
    covergroup routing_data_cov;
        option.name = "cg_routing_and_data";

        // -------------------------------------------------------------
        // Port configuration coverage (A1, A2 indirectly verified)
        // -------------------------------------------------------------
        cp_programmed: coverpoint port_cov {
            bins sout0_programmed = {8'h00} iff (prog_cov == 1); // SOUT0 programmed
            bins sout1_programmed = {8'h01} iff (prog_cov == 1); // SOUT1 programmed
        }

        // -------------------------------------------------------------
        // Valid/Invalid packet routing coverage (A4–A7)
        // -------------------------------------------------------------
        cp_valid_to_port: coverpoint packet_valid_cov {
            bins valid_sout0   = {1'b1} iff (port_cov == 8'h00); // A4
            bins valid_sout1   = {1'b1} iff (port_cov == 8'h01); // A5
            bins invalid_sout0 = {1'b0} iff (port_cov == 8'h00); // A6
            bins invalid_sout1 = {1'b0} iff (port_cov == 8'h01); // A7
        }

        // -------------------------------------------------------------
        // Error condition coverage (A8–A9)
        // -------------------------------------------------------------
        cp_invalid_types: coverpoint invalid_type_cov {
            bins no_error     = {3'b000}; // Normal valid case
            bins stop_error   = {3'b010}; // A8 — Stop bit incorrect
            bins parity_error = {3'b001}; // A9 — Parity bit incorrect
            bins stop_parity  = {3'b011}; // Combined parity + stop error (extension)
        }

        // -------------------------------------------------------------
        // Data payload coverage — exercise all possible byte values
        // -------------------------------------------------------------
        cp_all_data: coverpoint data_cov {
            bins all_data_values[] = {[0:255]} iff (prog_cov == 0);
        }
    endgroup
    routing_data_cov rout_data_cg;


    // =========================================================================
    //  Reset Coverage — Verifies Correct Reset Transitions
    // -------------------------------------------------------------------------
    //  ✅ Covers:
    //      (A3) Module reset behavior: both SOUT0 and SOUT1 inactive during reset
    // =========================================================================
    covergroup reset_cov;
        option.name = "cg_reset";
        coverpoint tb.rst_n {
            bins rst_low2high[] = (0 => 1); // Reset release
            bins rst_high2low[] = (1 => 0); // Reset assertion
        }
    endgroup
    reset_cov reset_cg;


    // =========================================================================
    //  Sampling Process
    // -------------------------------------------------------------------------
    //  Description:
    //      - Continuously receives transactions from gen2cov_mb
    //      - Samples covergroups in response to generator activity
    //      - Periodically monitors reset signal
    // =========================================================================
    initial begin : coverage_from_generator
        tb_pkg::uart_transaction_t tr;

        // Initialize covergroups
        addr_cg      = new();
        rout_data_cg = new();
        reset_cg     = new();

        fork
            // ---------------------------------------------------------
            // Transaction-driven sampling
            // ---------------------------------------------------------
            begin
                // Synchronization delay — allow stimulus setup
                repeat (50*CLKS_PER_BIT) @(posedge tb.clk);

                forever begin
                    tb.gen2cov_mb.get(tr);

                    // Extract fields from transaction
                    addr_cov         = tr.switch_packet.addr.data;
                    prog_cov         = tr.prog;
                    packet_valid_cov = tr.valid;
                    port_cov         = tr.switch_packet.data.data;
                    invalid_type_cov = {(!tr.valid_start), (!tr.valid_stop), (!tr.valid_parity)};
                    data_cov         = tr.switch_packet.data.data;

                    // Sample all covergroups associated with this transaction
                    addr_cg.sample();
                    rout_data_cg.sample();
                end
            end

            // ---------------------------------------------------------
            // Continuous reset signal sampling
            // ---------------------------------------------------------
            begin
                forever begin
                    @(posedge tb.clk);
                    reset_cg.sample();
                end
            end
        join_none
    end


    // =========================================================================
    //  Final Coverage Summary
    // -------------------------------------------------------------------------
    //  Prints percentage coverage from each group at simulation end
    // =========================================================================
    final begin
        $display("============================================================");
        $display(" Functional Coverage Summary:");
        $display(" -----------------------------------------------------------");
        $display("  Address coverage        : %.2f%%", addr_cg.get_coverage());
        $display("  Routing & Data coverage : %.2f%%", rout_data_cg.get_coverage());
        $display("  Reset coverage          : %.2f%%", reset_cg.get_coverage());
        $display(" -----------------------------------------------------------");
        $display("============================================================");
    end

endmodule : coverage
