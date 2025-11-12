// ============================================================================
//  Class: driver
//  Description:
//      UART Driver class — converted from original module version.
//      Drives the DUT UART input line (`sin`) using transactions from generator.
//      Uses execute() as main entry point.
// ============================================================================
import fifomult_tb_pkg::*;
class driver;
   

    // Handle do interfejsu BFM
    virtual switch_bfm bfm; 

    // Konstruktor
    function new(virtual switch_bfm bfm);
        this.bfm = bfm;
    endfunction


    // =========================================================================
    //  Main driver process (was 'initial begin')
    // =========================================================================
    function void execute();
        fork
            begin : drv_blk
                uart_transaction_t tr;

                `ifdef DEBUG
                $display("[%0t] [DRV] Driver started", $time);
                `endif

                // UART line idle high (default)
                bfm.sin = 1'b1;

                // Perform two resets to ensure stable DUT outputs
                bfm.reset_dut();
                bfm.reset_dut();

                // Basic post-reset check — outputs must be idle high
                assert (bfm.sout0 == 1'b1 && bfm.sout1 == 1'b1)
                    else begin
                        `ifdef DEBUG
                        $display("[%0t] [DRV] sout0 or sout1 not 1'b1 after reset", $time);
                        `endif
                        bfm.test_result = TEST_FAILED;
                    end

                //----------------------------------------------------------------------
                // Main driver loop
                //----------------------------------------------------------------------
                forever begin
                    // Wait for a transaction from the generator
                    bfm.gen2drv_mb.get(tr);

                    // Stop condition (end of simulation)
                    if (tr.finish_sim) begin
                        `ifdef DEBUG
                        $display("[%0t] [DRV] Finish_sim received — driver exiting", $time);
                        `endif
                        break;
                    end

                    // Print debug info
                    `ifdef DEBUG
                    $display("[%0t] [DRV] Sending packet addr=0x%02h data=0x%02h, port=%0d prog=%0b",
                            $time, tr.switch_packet.addr.data, tr.switch_packet.data.data, tr.port, tr.prog);
                    `endif

                    // Drive DUT
                    bfm.prog = tr.prog;
                    bfm.uart_send_frame(tr.switch_packet.addr, bfm.sin);  // Send address frame
                    bfm.uart_send_frame(tr.switch_packet.data, bfm.sin);  // Send data frame
                    bfm.prog = 0;                                         // Disable programming after packet
                end

                //----------------------------------------------------------------------
                // Simulation finished
                //----------------------------------------------------------------------
                `ifdef DEBUG
                $display("[%0t] [DRV] Driver finished", $time);
                `endif
            end
        join_none
    endfunction

endclass : driver
