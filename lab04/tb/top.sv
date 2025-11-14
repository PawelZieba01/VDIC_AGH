// ============================================================================
//  MODULE: top
//  ----------------------------------------------------------------------------
//  Object-oriented top-level testbench module that creates the DUT and
//  launches the testbench class.
// ============================================================================
import fifomult_tb_pkg::*;
module top;
     
        

    // Shared interface 
    switch_bfm bfm();

    // Device Under Test
    simple_switch_uart dut (
        .clk    (bfm.clk),
        .rst_n  (bfm.rst_n),
        .prog   (bfm.prog),
        .sin    (bfm.sin),
        .sout0  (bfm.sout0),
        .sout1  (bfm.sout1)
    );

    // Testbench object handle 
    testbench tb;


    // Main simulation flow
    initial begin 
        tb = new(bfm);     // create environment
        tb.run_test();     // start all components
    end

    // Final reporting
    final begin
        tb.finish_test();
    end

endmodule : top
