// ============================================================================
//  CLASS: testbench
//  ----------------------------------------------------------------------------
//  Description:
//      Object-oriented top-level testbench class that orchestrates the entire
//      UART switch verification environment.
//
//      Components:
//        - Generator
//        - Driver
//        - Monitor
//        - Scoreboard
//        - Coverage
//
//      Responsibilities:
//        - Initialize all components
//        - Allocate mailboxes
//        - Spawn and manage execution threads
//        - Handle test start and completion
// ============================================================================

class testbench;

    
    // Shared interface
    virtual switch_bfm bfm;

    // Environment components 
    tp_gen     gen;
    driver     drv;
    monitor    mon;
    scoreboard sb; 
    coverage   cov; 
 
    // =========================================================================
    //  Constructor — initializes interface and allocates mailboxes
    // =========================================================================
    function new(virtual switch_bfm bfm);
        this.bfm = bfm;

        // Allocate all mailboxes used for communication
        // bfm.gen2drv_mb = new();
        // bfm.gen2sb_mb  = new();
        // bfm.mon2sb_mb  = new();
        // bfm.gen2cov_mb = new();

        // Default initial states
        bfm.prog_pkt_count = 0;
        bfm.debug = 1'b0;

        `ifdef DEBUG
        $display("[%0t] [TB] Testbench created", $time);
        `endif
    endfunction


    // =========================================================================
    //  run_test — creates, starts, and manages all verification components
    // =========================================================================
    task run_test();
        `ifdef DEBUG
        $display("[%0t] [TB] Starting simulation...", $time);
        `endif

        // Create component instances
        gen = new(bfm);
        drv = new(bfm);
        mon = new(bfm);
        sb  = new(bfm);
        cov = new(bfm);

        // Spawn concurrent processes for each component
        fork
            gen.execute();
            drv.execute();
            mon.execute();
            sb.execute();
            cov.execute();
        join
    endtask


    // =========================================================================
    //  finish_test — called at simulation end to summarize results
    // =========================================================================
    function automatic void finish_test();
        `ifdef DEBUG
        $display("[%0t] [TB] Simulation completed. Generating reports...", $time);
        `endif
        sb.report();
        cov.report();
    endfunction

endclass : testbench
