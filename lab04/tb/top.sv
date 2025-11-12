// ============================================================================
//  MODULE: top
//  ----------------------------------------------------------------------------
//  Object-oriented top-level testbench module that creates the DUT and
//  launches the testbench class.
// ============================================================================

module top;
    import fifomult_tb_pkg::*;

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

    // // Clock generation
    // initial begin
    //     bfm.clk = 0;
    //     forever #5 bfm.clk = ~bfm.clk;  // 100 MHz clock
    // end

    // // Reset sequence
    // initial begin
    //     bfm.rst_n = 0;
    //     repeat (10) @(posedge bfm.clk);
    //     bfm.rst_n = 1;
    // end

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
