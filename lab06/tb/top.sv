// ============================================================================
//  MODULE: top
//  ----------------------------------------------------------------------------
//  UVM-compliant top-level module. 
//  No manual creation of testbench or components.
//  BFM is registered in the UVM configuration database.
//  run_test() creates the environment and launches the test.
// ============================================================================




module top;
import uvm_pkg::*;
`include "uvm_macros.svh"
import fifomult_tb_pkg::*;
    // ------------------------------------------------------------------------
    // Interface / BFM — shared with DUT
    // ------------------------------------------------------------------------
    switch_bfm bfm();

    // ------------------------------------------------------------------------
    // Device Under Test
    // ------------------------------------------------------------------------
    simple_switch_uart dut (
        .clk    (bfm.clk),
        .rst_n  (bfm.rst_n),
        .prog   (bfm.prog),
        .sin    (bfm.sin),
        .sout0  (bfm.sout0),
        .sout1  (bfm.sout1)
    );

    // ------------------------------------------------------------------------
    // MAIN: UVM entry point
    // ------------------------------------------------------------------------
    initial begin
        // Put BFM into UVM config DB so env/test can retrieve it
        uvm_config_db#(virtual switch_bfm)::set(
            null,                // no specific component
            "*",                 // available to all components
            "bfm",               // lookup key
            bfm                  // value
        );

        // This triggers UVM to:
        // - create test class (by +UVM_TESTNAME)
        // - build env
        // - run phases
        run_test();   
    end

endmodule : top
