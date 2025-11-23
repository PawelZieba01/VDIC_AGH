// ----------------------------------------------------------------------------
//  PACKAGE: fifomult_tb_pkg
//  Contains type definitions, constants, and data structures used by all TB
// ----------------------------------------------------------------------------
//`define DEBUG
package fifomult_tb_pkg;
    // UART protocol timing constant
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    localparam int CLKS_PER_BIT = 16;

    

    typedef enum bit [1:0] {
        rst_op               = 2'b00,
        normal_op              = 2'b01,
        prog_op                = 2'b10
        } operation_t;

    // Text color formatting for pretty console output
    typedef enum {
        COLOR_BOLD_BLACK_ON_GREEN,  
        COLOR_BOLD_BLACK_ON_RED,
        COLOR_BOLD_BLACK_ON_YELLOW,
        COLOR_BOLD_BLUE_ON_WHITE,
        COLOR_BLUE_ON_WHITE,
        COLOR_DEFAULT
    } print_color_t;

    // UART frame definition (start, data, parity, stop)
    typedef struct packed {
        logic start;
        logic [7:0] data;
        logic parity;
        logic stop;
    } uart_frame_t;

    // Switch packet = two UART frames: address + data
    typedef struct packed {
        uart_frame_t addr;
        uart_frame_t data;
    } switch_packet_t;

    // Status enumerations for UART frame integrity
    typedef enum {UART_OK, UART_PARITY_ERR, UART_START_ERR, UART_STOP_ERR} uart_status_t;

    // Output port identifiers
    typedef enum byte unsigned {SOUT0, SOUT1, SOUTX} uart_port_t;

    // Memory entry: routing table entry (address → output port)
    typedef struct {
        logic [7:0] addr;
        uart_port_t port;
    } mem_entry_t;

    // UART transaction object exchanged between TB components
    typedef struct {
        switch_packet_t  switch_packet;
        bit              prog;           // programming transaction
        bit              valid;          // expected to be valid?
        bit              valid_start;
        bit              valid_parity;
        bit              valid_stop;
        bit              empty_packet;   // monitor saw nothing
        bit              finish_sim;     // end-of-sim signal
        uart_port_t      port;           // expected output port
    } uart_transaction_t;

    typedef struct {
        uart_transaction_t tr;
        operation_t        op;
    } command_s;

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


    `include "coverage.svh"
    `include "scoreboard.svh"
    `include "base_tpgen.svh"
    `include "random_tpgen.svh"
    `include "minmax_tpgen.svh"
    `include "driver.svh"
    `include "command_monitor.svh"
    `include "result_monitor.svh"
    `include "env.svh"
    
    `include "random_test.svh"
    `include "minmax_test.svh"
    

endpackage : fifomult_tb_pkg