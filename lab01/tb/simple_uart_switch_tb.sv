//`define DEBUG  // Uncomment to enable debug printing

module top;

//------------------------------------------------------------------------------
// Type definitions
//------------------------------------------------------------------------------

    localparam int CLKS_PER_BIT = 16;

    typedef enum bit {
        TEST_PASSED, 
        TEST_FAILED
    } test_result_t;

    typedef enum {
        COLOR_BOLD_BLACK_ON_GREEN,
        COLOR_BOLD_BLACK_ON_RED,
        COLOR_BOLD_BLACK_ON_YELLOW,
        COLOR_BOLD_BLUE_ON_WHITE,
        COLOR_BLUE_ON_WHITE,
        COLOR_DEFAULT
    } print_color_t;

    typedef struct packed {
        logic start;      // start bit
        logic [7:0] data; // 8 bits of data
        logic parity;     // parity bit
        logic stop;       // stop bit
    } uart_frame_t;
    
    typedef struct packed{
        uart_frame_t addr;      // B0: address
        uart_frame_t data;      // B1: port / data
    } switch_packet_t;
    
    typedef enum {UART_OK, UART_PARITY_ERR, UART_START_ERR, UART_STOP_ERR} uart_status_t;
    typedef enum int {SOUT0, SOUT1, SOUTX} uart_port_t;

    typedef struct {
        logic  [7:0] addr;        // address
        uart_port_t  port;        // programmed port
    } mem_entry_t;

    typedef struct packed {
        switch_packet_t  switch_packet;     // actual UART packet (address + data + port, etc.)
        bit              prog;              // programming signal
        bit              valid;             // 1 = packet correct / expected
        bit              empty_packet;      // 1 = empty packet
        bit              finish_sim;        // 1 = end of simulation (e.g., last packet)
        uart_port_t      port;              // expected port after programming
    } uart_transaction_t;

//------------------------------------------------------------------------------
// Local variables
//------------------------------------------------------------------------------
    logic                  clk;
    logic                  rst_n;
    logic                  prog;
    logic                  sin;
    logic                  sout0;
    logic                  sout1;

    test_result_t test_result;

    // Queues (mailboxes)
    mailbox #(uart_transaction_t) gen2drv_mb;   // generator → driver
    mailbox #(uart_transaction_t) gen2sb_mb;    // generator → scoreboard (expected)
    mailbox #(uart_transaction_t) mon2sb_mb;    // monitor → scoreboard (actual)

    event monitor_start_evt;
    int unsigned prog_pkt_count = 0;            // number of sent programming packets 

    mem_entry_t mem_table [0:255];  // Storage for [addr,port] programming pairs

    logic debug;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
    simple_switch_uart dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .prog   (prog),
        .sin    (sin),
        .sout0  (sout0),
        .sout1  (sout1)
    );

//------------------------------------------------------------------------------
// Clock generator
//------------------------------------------------------------------------------
    initial begin : clk_gen_blk
        rst_n = 1; 
        sin = 1;
        prog = 0;
        clk = 0;
        forever begin : clk_frv_blk
            #10;
            clk = ~clk;
        end
    end

//------------------------------------------------------------------------------
// Tester
//------------------------------------------------------------------------------

    task automatic send_random_packets(input int num_packets);
        int unsigned i;
        byte addr, data;
        uart_port_t exp_port;
        bit addr_start_v, addr_parity_v, addr_stop_v;
        bit data_start_v, data_parity_v, data_stop_v;
        bit pkt_valid;
        bit parity_bit;

        `ifdef DEBUG
        $display("[%0t] ----------- Sending %0d random packets -----------", $time, num_packets);
        `endif

        for (i = 0; i < num_packets; i++) begin
            addr = rand_biased_addr();
            data = rand_biased_byte();
            exp_port = mem_table[addr].port; // Look up expected port from programming table

            // Generate biased per-frame bit correctness (0 = correct start, 1 = error)
            addr_start_v  = (rand_biased_start_bit(0) == 1'b0);
            addr_stop_v   = (rand_biased_stop_bit(0)  == 1'b1);
            parity_bit    = rand_biased_parity_bit(addr, 0);
            addr_parity_v = (parity_bit == (^addr));

            data_start_v  = (rand_biased_start_bit(0) == 1'b0);
            data_stop_v   = (rand_biased_stop_bit(0)  == 1'b1);
            parity_bit    = rand_biased_parity_bit(data, 0);
            data_parity_v = (parity_bit == (^data));

            // packet valid if both frames bits appear valid
            pkt_valid = addr_start_v && addr_parity_v && addr_stop_v &&
                       data_start_v && data_parity_v && data_stop_v;

            create_and_send_transaction(
                addr, data, exp_port,
                addr_start_v, addr_parity_v, addr_stop_v,
                data_start_v, data_parity_v, data_stop_v,
                pkt_valid, 1'b0
            );
        end

        `ifdef DEBUG
        $display("[%0t] ----------- Random packets generation done -----------", $time);
        `endif
    endtask

    task automatic send_seq_packets(input int number_of_packets);
        int unsigned i;

        for (i = 0; i < number_of_packets; i++) begin
            //send packet i
            create_and_send_transaction(
                i[7:0], 8'hAA, mem_table[i[7:0]].port,
                1'b0, 1'b1, 1'b1,
                1'b0, 1'b1, 1'b1, 
                1'b0, 1'b0
            );
        end
    endtask

    initial begin : tp_gen_blk
        static uart_transaction_t tr_finish = '{default:0};
        gen2drv_mb = new();
        gen2sb_mb  = new();
        mon2sb_mb  = new();
        prog_pkt_count = 0;

        `ifdef DEBUG
        $display("------------ TP_GEN START ------------");
        $display("--------------------------------------");
        `endif

        repeat (50*CLKS_PER_BIT) @(posedge clk);

        // Program DUT with random port assignments
        program_dut();
        
        -> monitor_start_evt;

        // Send random packets
        send_random_packets(256);

        //send finish_sim
        tr_finish.finish_sim = 1;
        gen2sb_mb.put(tr_finish);        
    end

    initial begin : drv_blk
        uart_transaction_t tr;

        `ifdef DEBUG
        $display("[%0t] [DRV] Driver started", $time);
        `endif
        sin = 1'b1; // UART line idle high

        // #1 DUT reset -> sout0 = 1, sout1 = 1
        reset_dut();
        assert (sout0 == 1'b1 && sout1 == 1'b1) 
            else begin
                `ifdef DEBUG
                $display("sout0 or sout1 not 1'b1 after reset");
                `endif
                test_result = TEST_FAILED;
            end

        forever begin
            // wait for transaction from generator
            gen2drv_mb.get(tr);

            // if end-of-simulation signal
            if (tr.finish_sim) begin
                `ifdef DEBUG
                $display("[%0t] [DRV] Finish_sim received — driver exiting", $time);
                `endif
                break;
            end

            // send packet unconditionally
            `ifdef DEBUG
            $display("[%0t] [DRV] Sending packet addr=0x%02h data=0x%02h", 
                    $time, tr.switch_packet.addr.data, tr.switch_packet.data.data);
            `endif

            prog = tr.prog;
            uart_send_frame(tr.switch_packet.addr, sin);
            uart_send_frame(tr.switch_packet.data, sin);
            prog = 0;
        end

        `ifdef DEBUG
        $display("[%0t] [DRV] Driver finished", $time);
        `endif
    end

    initial begin : monitor_blk
        uart_transaction_t tr0, tr1;
        int timeout_counter;

        @monitor_start_evt;
        repeat (11*CLKS_PER_BIT) @(posedge clk);

        `ifdef DEBUG
        $display("[%0t] [MON] Monitor started", $time);
        `endif

        forever begin
            fork
                begin
                    forever begin
                        @(negedge sout0 or negedge sout1);
                        timeout_counter = 0;
                    end
                end

                begin
                    // task monitors sout0
                    monitor_switch_packet(sout0, "sout0", tr0);
                    repeat (CLKS_PER_BIT/2) @(posedge clk);
                    tr0.port = SOUT0;
                    mon2sb_mb.put(tr0);
                end

                begin
                    // task monitors sout1
                    monitor_switch_packet(sout1, "sout1", tr1);
                    repeat (CLKS_PER_BIT/2) @(posedge clk);
                    tr1.port = SOUT1;
                    mon2sb_mb.put(tr1);
                end

                begin 
                    timeout_counter = 0;
                    // timeout for monitoring
                     forever begin
                        @(posedge clk);
                        timeout_counter = timeout_counter + 1;

                        if (timeout_counter >= 22*CLKS_PER_BIT) break;
                     end

                    `ifdef DEBUG
                    $display("[%0t] [MON] INFO: Monitor timeout!", $time);
                    `endif

                    tr1.empty_packet = 1'b1;
                    tr1.port = SOUTX;
                    mon2sb_mb.put(tr1);
                end
            join_any   // ends fork when **one task finishes**
            disable fork; // stops the other task if still running
        end
    end

    initial begin : scoreboard_blk
        uart_transaction_t gen_tr, mon_tr;

        test_result = TEST_PASSED;

        `ifdef DEBUG
        $display("[%0t] [SB] Scoreboard started", $time);
        `endif

        forever begin
            // Get packets from generator and monitor
            gen2sb_mb.get(gen_tr);
            mon2sb_mb.get(mon_tr);

            if (gen_tr.finish_sim) begin
                `ifdef DEBUG
                $display("[%0t] [SB] Finish_sim received — scoreboard exiting", $time);
                `endif
                $finish;
            end

            // If generator indicates packet is invalid -> expect empty packet from monitor
            if (gen_tr.valid == 1'b0) begin
                if (!mon_tr.empty_packet) begin
                    test_result = TEST_FAILED;
                    `ifdef DEBUG
                    $display("[%0t] [SB] ERROR: GEN marked packet INVALID but MON provided a non-empty packet", $time);
                    `endif
                    print_scoreboard_comparison(gen_tr, mon_tr);
                end
                // else: expected empty packet received -> OK
            end
            else begin
                // gen says packet is valid -> monitor must provide a non-empty packet and contents must match
                if (mon_tr.empty_packet) begin
                    test_result = TEST_FAILED;
                    `ifdef DEBUG
                    $display("[%0t] [SB] ERROR: GEN marked packet VALID but MON reported EMPTY packet", $time);
                    `endif
                    print_scoreboard_comparison(gen_tr, mon_tr);
                end
                else begin
                    // Compare addr, data, port and frame bits
                    if ((gen_tr.switch_packet.addr.data != mon_tr.switch_packet.addr.data) ||
                        (gen_tr.switch_packet.data.data != mon_tr.switch_packet.data.data) ||
                        (gen_tr.port != mon_tr.port) ||
                        // Compare address frame bits
                        (gen_tr.switch_packet.addr.start != mon_tr.switch_packet.addr.start) ||
                        (gen_tr.switch_packet.addr.parity != mon_tr.switch_packet.addr.parity) ||
                        (gen_tr.switch_packet.addr.stop != mon_tr.switch_packet.addr.stop) ||
                        // Compare data frame bits
                        (gen_tr.switch_packet.data.start != mon_tr.switch_packet.data.start) ||
                        (gen_tr.switch_packet.data.parity != mon_tr.switch_packet.data.parity) ||
                        (gen_tr.switch_packet.data.stop != mon_tr.switch_packet.data.stop)) begin
                        test_result = TEST_FAILED;
                        print_scoreboard_comparison(gen_tr, mon_tr);
                    end
                end
            end
        end
    end

    final begin : finish_of_the_test
        print_test_result(test_result);
    end

//------------------------------------------------------------------------------
// tasks
//------------------------------------------------------------------------------

    task automatic uart_send_frame(
        input uart_frame_t frame,
        ref logic sin
    );
        int i;

        // Start bit
        sin = frame.start;
        repeat(CLKS_PER_BIT) @(posedge clk);

        // 8 bits of data LSB-first
        for (i = 0; i < 8; i++) begin
            sin = frame.data[i];
            repeat(CLKS_PER_BIT) @(posedge clk);
        end

        // Parity bit
        sin = frame.parity;
        repeat(CLKS_PER_BIT) @(posedge clk);

        // Stop bit
        sin = frame.stop;
        repeat(CLKS_PER_BIT) @(posedge clk);
    endtask

    task automatic reset_dut();
    begin
        `ifdef DEBUG
        $display("[%0t] ----------- DUT reset start -----------", $time);
        `endif
        rst_n = 0;                
        repeat(CLKS_PER_BIT) @(posedge clk);
        rst_n = 1;
        repeat(CLKS_PER_BIT) @(posedge clk);
        `ifdef DEBUG
        $display("[%0t] ----------- DUT reset done -----------", $time);
        `endif
    end
    endtask

    task automatic uart_capture_frame(
        ref logic sout,                         // signal to monitor
        output uart_frame_t frame
    );
        int i;

        // Wait for start bit (0)
        @(negedge sout);                        // falling edge = start
        repeat(CLKS_PER_BIT/2) @(posedge clk);  // synchronize to middle of the start bit

        frame.start = 0;

        // Read 8 data bits LSB-first
        for (i = 0; i < 8; i++) begin
            repeat(CLKS_PER_BIT) @(posedge clk);
            frame.data[i] = sout;
        end

        // Parity
        repeat(CLKS_PER_BIT) @(posedge clk);
        frame.parity = sout;

        // Stop bit
        repeat(CLKS_PER_BIT) @(posedge clk);
        frame.stop = sout;
    endtask

    task automatic monitor_switch_packet(ref logic sout, input string name, output uart_transaction_t tr);
        switch_packet_t pkt;
        byte data;
        uart_status_t status;

        // Receive address (frame 0)
        uart_capture_frame(sout, pkt.addr);
        status = decode_uart_frame(pkt.addr, data);
        `ifdef DEBUG
        if (status == UART_OK)
            $display("[%0t] [MON] %s ADDR = 0x%02h", $time, name, data);
        else
            $display("[%0t] [MON] %s ADDR frame error: %0d", $time, name, status);
        `endif

        // Receive data / port (frame 1)
        uart_capture_frame(sout, pkt.data);
        status = decode_uart_frame(pkt.data, data);
        `ifdef DEBUG
        if (status == UART_OK)
            $display("[%0t] [MON] %s DATA = 0x%02h", $time, name, data);
        else
            $display("[%0t] [MON] %s DATA frame error: %0d", $time, name, status);
        `endif

        // Assemble transaction
        tr.switch_packet = pkt;
        tr.prog = 0;
        tr.valid = (status == UART_OK) ? 1'b1 : 1'b0;
        tr.empty_packet = 1'b0;
        tr.finish_sim = 1'b0;
    endtask

    task automatic create_and_send_transaction(
        input  byte addr,
        input  byte data,
        input  uart_port_t port,
        // Address frame validation bits
        input  bit  addr_start_valid,    // address frame start bit
        input  bit  addr_parity_valid,   // address frame parity
        input  bit  addr_stop_valid,     // address frame stop bit
        // Data frame validation bits
        input  bit  data_start_valid,    // data frame start bit
        input  bit  data_parity_valid,   // data frame parity
        input  bit  data_stop_valid,     // data frame stop bit
        input  bit  packet_valid,        // whether the whole packet is logically correct
        input  bit  prog_sig             // programming signal
    );
        uart_transaction_t tr;
        uart_frame_t addr_frame, data_frame;

        // Create UART frames
        addr_frame = make_uart_frame(addr);
        data_frame = make_uart_frame(data);

        // During programming all frames must be valid
        if (!prog_sig) begin
            // Introduce errors in address frame if requested
            if (!addr_start_valid)  addr_frame.start  = 1'b1;  // invalid start (should be 0)
            if (!addr_parity_valid) addr_frame.parity = ~addr_frame.parity;
            if (!addr_stop_valid)   addr_frame.stop   = 1'b0;

            // Introduce errors in data frame if requested
            if (!data_start_valid)  data_frame.start  = 1'b1;
            if (!data_parity_valid) data_frame.parity = ~data_frame.parity;
            if (!data_stop_valid)   data_frame.stop   = 1'b0;
        end

        // Build transaction
        tr.switch_packet.addr = addr_frame;
        tr.switch_packet.data = data_frame;
        tr.valid       = prog_sig ? 1'b1 : packet_valid;  // Always valid during programming
        tr.finish_sim  = 0;
        tr.prog = prog_sig;
        tr.port = port;

        // Send to driver and scoreboard
        gen2drv_mb.put(tr);
        
        if (!prog_sig) begin
            gen2sb_mb.put(tr);
        end
        else begin
            prog_pkt_count = prog_pkt_count + 1;
        end 

        `ifdef DEBUG
        $display("[%0t] [GEN] Queued packet addr=0x%02h data=0x%02h prog=%0b addr(s=%0b,p=%0b,t=%0b) data(s=%0b,p=%0b,t=%0b) valid=%0b",
                $time, addr, data, prog_sig,
                addr_start_valid, addr_parity_valid, addr_stop_valid,
                data_start_valid, data_parity_valid, data_stop_valid,
                packet_valid);
        `endif
    endtask

    //------------------------------------------------------------------------------ 
    // functions
    //------------------------------------------------------------------------------

    function automatic uart_frame_t make_uart_frame(input byte data);
        uart_frame_t frame;
        frame.start  = 0;
        frame.data   = data;
        frame.parity = (^data); // even parity
        frame.stop   = 1;
        return frame;
    endfunction

    function automatic switch_packet_t make_switch_packet(byte addr, byte data);
        switch_packet_t pkt;
        pkt.addr = make_uart_frame(addr);
        pkt.data = make_uart_frame(data);
        return pkt;
    endfunction

    function automatic uart_status_t decode_uart_frame(
        input uart_frame_t frame,
        output byte data
    );
        // default: no error
        uart_status_t status = UART_OK;
        data = 8'h00;

        // Check start bit
        if (frame.start !== 0) begin
            status = UART_START_ERR;
            return status;
        end

        // Read data
        data = frame.data;

        // Check parity (even parity)
        if (frame.parity !== (^frame.data)) begin
            status = UART_PARITY_ERR;
            return status;
        end

        // Check stop bit
        if (frame.stop !== 1) begin
            status = UART_STOP_ERR;
            return status;
        end

        return status;
    endfunction

    // used to modify the color of the text printed on the terminal
    function void set_print_color ( print_color_t c );
        string ctl;
        case(c)
            COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m";
            COLOR_BOLD_BLACK_ON_RED : ctl    = "\033\[1;30m\033\[101m";
            COLOR_BOLD_BLACK_ON_YELLOW : ctl = "\033\[1;30m\033\[103m";
            COLOR_BOLD_BLUE_ON_WHITE : ctl   = "\033\[1;34m\033\[107m";
            COLOR_BLUE_ON_WHITE : ctl        = "\033\[0;34m\033\[107m";
            COLOR_DEFAULT : ctl              = "\033\[0m";
            default : begin
                $error("set_print_color: bad argument");
                ctl                          = "";
            end
        endcase
        $write(ctl);
    endfunction

    function void print_test_result (test_result_t r);
        $write("\n");
        if (r == TEST_PASSED) begin
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
        end else begin
            set_print_color(COLOR_BOLD_BLACK_ON_RED);
        end
        $write("-----------------------------------");
        set_print_color(COLOR_DEFAULT);
        $write("\n");
        if(r == TEST_PASSED) begin
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
            $write("----------- Test PASSED -----------");
        end
        else begin
            set_print_color(COLOR_BOLD_BLACK_ON_RED);
            $write("----------- Test FAILED -----------"); 
        end
        set_print_color(COLOR_DEFAULT);
        $write("\n");
        if (r == TEST_PASSED) begin
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN); 
        end else begin
            set_print_color(COLOR_BOLD_BLACK_ON_RED);
        end
        $write("-----------------------------------");
        set_print_color(COLOR_DEFAULT);
        $write("\n");
    endfunction

    function automatic void print_scoreboard_comparison(
        input uart_transaction_t gen_tr,
        input uart_transaction_t mon_tr
    );
        // Prepare strings for nice alignment
        string gen_addr_s, gen_data_s, gen_port_s;
        string mon_addr_s, mon_data_s, mon_port_s;
        string yellow_on  = "\033\[1;37m\033\[103m"; 
        string color_off = "\033\[0m";
        string red_on = "\033\[1;31m";

        // Print error message in orange
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

        // Print header and data lines with additional frame info
        $write("[%0t] [SB] %s     %-12s %-12s %-8s %-8s %-15s %-16s %-6s%s\n", 
            $time, yellow_on, "ADDR", "DATA", "PORT", "VALID", "", "DETAILS", "", color_off);
            
        // Generator expected values
        $write("[%0t] [SB] %sGEN: %-12s %-12s %-8s %-0b     |     ADDR(s=%b,p=%b,t=%b) DATA(s=%b,p=%b,st=%b)%s\n",
            $time, yellow_on, 
            gen_addr_s, gen_data_s, gen_port_s, gen_tr.valid,
            gen_tr.switch_packet.addr.start, gen_tr.switch_packet.addr.parity, gen_tr.switch_packet.addr.stop,
            gen_tr.switch_packet.data.start, gen_tr.switch_packet.data.parity, gen_tr.switch_packet.data.stop,
            color_off);
            
        // Monitor actual values
        $write("[%0t] [SB] %sMON: %-12s %-12s %-8s %-0b     |     ADDR(s=%b,p=%b,t=%b) DATA(s=%b,p=%b,st=%b)%s\n",
            $time, yellow_on, 
            mon_addr_s, mon_data_s, mon_port_s, mon_tr.valid,
            mon_tr.switch_packet.addr.start, mon_tr.switch_packet.addr.parity, mon_tr.switch_packet.addr.stop,
            mon_tr.switch_packet.data.start, mon_tr.switch_packet.data.parity, mon_tr.switch_packet.data.stop,
            color_off);
    endfunction

    task automatic program_dut();
        int unsigned i;
        
        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT start -----------", $time);
        `endif

        // Initialize memory table with random port assignments
        for (i = 0; i < 256; i++) begin
            mem_table[i].addr = i;
            mem_table[i].port = ($urandom_range(0,1) == 0) ? SOUT0 : SOUT1;
        end

        // Send programming frames
        for (i = 0; i < 256; i++) begin
            // Create and send programming transaction
            create_and_send_transaction(
                mem_table[i].addr,        // Address
                mem_table[i].port,        // Port as data
                mem_table[i].port,        // Expected port
                1'b1, 1'b1, 1'b1,        // addr frame valid
                1'b1, 1'b1, 1'b1,        // data frame valid
                1'b1,                     // packet valid
                1'b1                      // prog mode
            );
        end

        // Wait for all programming transactions to complete
        repeat (prog_pkt_count*44*CLKS_PER_BIT) @(posedge clk);

        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT done -----------", $time);
        `endif
    endtask

    // Biased random byte generator:
    // - higher chance to return boundary values 0x00 or 0xFF
    // - otherwise returns uniform 1..254
    function automatic byte rand_biased_byte();
        int r;
        byte val;
        r = $urandom_range(0,9); // 0..9
        case (r)
            0: val = 8'h00;    // 10% -> 0x00
            1: val = 8'hFF;    // 10% -> 0xFF
            default: val = $urandom_range(1,254); // 80% -> other values
        endcase
        return val;
    endfunction

    // Biased random address (same distribution as data)
    function automatic byte rand_biased_addr();
        return rand_biased_byte();
    endfunction

    // Biased start bit generator:
    // - prefers correct UART start bit (0). If force_correct==1 returns 0.
    // - otherwise ~80% returns 0, ~20% returns 1 (error)
    function automatic bit rand_biased_start_bit(input bit force_correct);
        int r;
        if (force_correct) return 1'b0;
        r = $urandom_range(0,9);
        case (r)
            0,1: return 1'b1; // 20% -> error (1)
            default: return 1'b0; // 80% -> correct (0)
        endcase
    endfunction

    // Biased stop bit generator:
    // - prefers correct UART stop bit (1). If force_correct==1 returns 1.
    // - otherwise ~80% returns 1, ~20% returns 0 (error)
    function automatic bit rand_biased_stop_bit(input bit force_correct);
        int r;
        if (force_correct) return 1'b1;
        r = $urandom_range(0,9);
        case (r)
            0,1: return 1'b0; // 20% -> error (0)
            default: return 1'b1; // 80% -> correct (1)
        endcase
    endfunction

    // Biased parity generator:
    // - if force_correct==1 returns even parity of data
    // - otherwise ~70% returns correct parity, ~30% returns incorrect (inverted)
    function automatic bit rand_biased_parity_bit(input byte data, input bit force_correct);
        int r;
        bit correct = (^data); // even parity (xor of bits)
        if (force_correct) return correct;
        r = $urandom_range(0,9);
        case (r)
            0,1,2: return ~correct; // 30% -> incorrect
            default: return correct; // 70% -> correct
        endcase
    endfunction

endmodule : top
