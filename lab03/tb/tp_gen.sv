//-----------------------------------------------------------------------------
//  Module: tp_gen
//  Author: PZ
//  Description:
//      Test pattern generator (transaction producer) for the UART-based
//      simple switch DUT.
//
//      This module is responsible for generating and dispatching UART
//      transactions to other components in the verification environment.
//      It initializes DUT configuration, sends programming packets, generates
//      normal/random transactions, and signals simulation completion.
//
//      Main flow:
//        1. Wait for stabilization.
//        2. Program DUT with random address-to-port mappings.
//        3. Generate and send random or sequential packets.
//        4. Notify scoreboard about simulation end.
//
//      Communication is done via mailboxes and signals in `tb_if`.
//
//  Mailboxes used:
//      - gen2drv_mb : transactions for driver (stimulus)
//      - gen2sb_mb  : transactions for scoreboard (expected results)
//      - gen2cov_mb : transactions for coverage
//
//  Notes:
//      - UART frame: start(0) + 8 data bits + parity(even) + stop(1)
//      - Errors can be injected randomly in start, stop, and parity bits
//      - Controlled via bias functions
//      - Debug messages are available if `DEBUG` macro is defined
//-----------------------------------------------------------------------------

module tp_gen (switch_bfm bfm);
    import fifomult_tb_pkg::*;

    //--------------------------------------------------------------------------
    // Main generator initial block
    //--------------------------------------------------------------------------
    initial begin : tp_gen_blk
        static uart_transaction_t tr_finish = '{default:0};

        bfm.prog_pkt_count = 0;

        `ifdef DEBUG
        $display("------------ TP_GEN START ------------");
        $display("--------------------------------------");
        `endif

        // Wait for DUT reset and UART line stabilization
        repeat (50*CLKS_PER_BIT) @(posedge bfm.clk);

        // Step 1: Program DUT with random address-port mapping
        program_dut();

        // Step 2: Start monitor
        -> bfm.monitor_start_evt;

        
        // Step 3: Generate and send random UART packets
        send_random_packets(5000);
        // Alternative: send_seq_packets(2000);

        // Step 4: Notify scoreboard about simulation end
        tr_finish.finish_sim = 1;
        bfm.gen2sb_mb.put(tr_finish);
    end


    //--------------------------------------------------------------------------
    // Task: program_dut
    // Programs the DUT by sending 256 programming transactions (address + port)
    //--------------------------------------------------------------------------
    task automatic program_dut();
        int unsigned i;
        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT start -----------", $time);
        `endif

        // Initialize memory table
        for (i = 0; i < 256; i++) begin
            bfm.mem_table[i].addr = i[7:0];
            bfm.mem_table[i].port = ($urandom_range(0,1) == 0) ? SOUT0 : SOUT1;
        end

        // Send programming packets
        for (i = 0; i < 256; i++) begin
            create_and_send_transaction(
                bfm.mem_table[i].addr,        // Address
                bfm.mem_table[i].port,        // Port as data
                bfm.mem_table[i].port,        // Expected port
                1'b1, 1'b1, 1'b1,            // addr frame valid
                1'b1, 1'b1, 1'b1,            // data frame valid
                1'b1,                        // packet valid
                1'b1                         // prog mode
            );
        end

        // Wait proportional to number of programming transactions
        repeat (bfm.prog_pkt_count*44*CLKS_PER_BIT) @(posedge bfm.clk);

        `ifdef DEBUG
        $display("[%0t] ----------- Programming DUT done -----------", $time);
        `endif
    endtask


    //--------------------------------------------------------------------------
    // Task: send_seq_packets
    // Sends a sequence of valid packets with sequential addresses and data
    //--------------------------------------------------------------------------
    task automatic send_seq_packets(input int number_of_packets);
        int unsigned i;
        int unsigned addr;
        int unsigned data;
        for (i = 0; i < number_of_packets; i++) begin
            addr = i % 256; // Wrap addresses every 256
            data = i % 256; // Sequential data

            create_and_send_transaction(
                addr[7:0],
                data[7:0],
                bfm.mem_table[addr].port,
                1'b1, 1'b1, 1'b1,
                1'b1, 1'b1, 1'b1,
                1'b1, 1'b0
            );
        end
    endtask


    //--------------------------------------------------------------------------
    // Task: send_random_packets
    // Sends random UART packets (valid or corrupted) to test robustness
    //--------------------------------------------------------------------------
    task automatic send_random_packets(input int num_packets);
        int unsigned i;
        byte unsigned addr, data;
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
            exp_port = bfm.mem_table[addr].port;

            // Address frame bits (possibly invalid)
            addr_start_v  = (rand_biased_start_bit(1) == 1'b0);
            addr_stop_v   = (rand_biased_stop_bit(0)  == 1'b1);
            parity_bit    = rand_biased_parity_bit(addr, 0);
            addr_parity_v = (parity_bit == (^addr));

            // Data frame bits (possibly invalid)
            data_start_v  = (rand_biased_start_bit(1) == 1'b0);
            data_stop_v   = (rand_biased_stop_bit(0)  == 1'b1);
            parity_bit    = rand_biased_parity_bit(data, 0);
            data_parity_v = (parity_bit == (^data));

            pkt_valid = addr_start_v && addr_parity_v && addr_stop_v &&
                        data_start_v && data_parity_v && data_stop_v;

            `ifdef DEBUG
            $display("[%0t] exp_port for addr=0x%02h is %0d", $time, addr, exp_port);
            `endif

            create_and_send_transaction(
                addr[7:0], data[7:0], exp_port,
                addr_start_v, addr_parity_v, addr_stop_v,
                data_start_v, data_parity_v, data_stop_v,
                pkt_valid, 1'b0
            );
        end

        `ifdef DEBUG
        $display("[%0t] ----------- Random packets generation done -----------", $time);
        `endif
    endtask


    //--------------------------------------------------------------------------
    // Task: uart_send_frame
    // Sends UART frame bit-by-bit on 'sin' synchronized with bfm.clk
    //--------------------------------------------------------------------------
    task automatic uart_send_frame(
        input uart_frame_t frame,
        ref logic sin
    );
        int i;
        sin = frame.start;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        for (i = 0; i < 8; i++) begin
            sin = frame.data[i];
            repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        end
        sin = frame.parity;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        sin = frame.stop;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
    endtask


    //--------------------------------------------------------------------------
    // Task: reset_dut
    // Performs synchronous reset of DUT
     //--------------------------------------------------------------------------
    task automatic reset_dut();
    begin
        `ifdef DEBUG
        $display("[%0t] ----------- DUT reset start -----------", $time);
        `endif
        bfm.rst_n = 0;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        bfm.rst_n = 1;
        repeat(CLKS_PER_BIT) @(posedge bfm.clk);
        `ifdef DEBUG
        $display("[%0t] ----------- DUT reset done -----------", $time);
        `endif
    end
    endtask


    //--------------------------------------------------------------------------
    // Task: create_and_send_transaction
    // Builds a UART transaction and puts it into mailboxes for driver/scoreboard
    //--------------------------------------------------------------------------
    task automatic create_and_send_transaction(
        input  byte unsigned addr,
        input  byte unsigned data,
        input  uart_port_t port,
        input  bit  addr_start_valid,
        input  bit  addr_parity_valid,
        input  bit  addr_stop_valid,
        input  bit  data_start_valid,
        input  bit  data_parity_valid,
        input  bit  data_stop_valid,
        input  bit  packet_valid,
        input  bit  prog_sig
    );
        uart_transaction_t tr;
        uart_frame_t addr_frame, data_frame;

        addr_frame = make_uart_frame(addr);
        data_frame = make_uart_frame(data);

        // Inject intentional bit errors if not programming
        if (!prog_sig) begin
            if (!addr_start_valid)  addr_frame.start  = 1'b1;
            if (!addr_parity_valid) addr_frame.parity = ~addr_frame.parity;
            if (!addr_stop_valid)   addr_frame.stop   = 1'b0;

            if (!data_start_valid)  data_frame.start  = 1'b1;
            if (!data_parity_valid) data_frame.parity = ~data_frame.parity;
            if (!data_stop_valid)   data_frame.stop   = 1'b0;
        end

        // Populate transaction
        tr.switch_packet.addr = addr_frame;
        tr.switch_packet.data = data_frame;
        tr.valid       = prog_sig ? 1'b1 : packet_valid;
        tr.finish_sim  = 0;
        tr.prog = prog_sig;
        tr.port = port;
        tr.valid_start  = addr_start_valid && data_start_valid;
        tr.valid_parity = addr_parity_valid && data_parity_valid;
        tr.valid_stop   = addr_stop_valid && data_stop_valid;

        // Send to respective mailboxes
        bfm.gen2drv_mb.put(tr);
        bfm.gen2cov_mb.put(tr);
        if (!prog_sig)
            bfm.gen2sb_mb.put(tr);
        else
            bfm.prog_pkt_count++;

        `ifdef DEBUG
        $display("[%0t] [GEN] Queued packet addr=0x%02h data=0x%02h prog=%0b "
                 "addr(s=%0b,p=%0b,t=%0b) data(s=%0b,p=%0b,t=%0b) valid=%0b",
                 $time, addr, data, prog_sig,
                 addr_start_valid, addr_parity_valid, addr_stop_valid,
                 data_start_valid, data_parity_valid, data_stop_valid,
                 packet_valid);
        `endif
    endtask


    //--------------------------------------------------------------------------
    // Function: make_uart_frame
    // Creates a valid UART frame with even parity
    //--------------------------------------------------------------------------
    function automatic uart_frame_t make_uart_frame(input byte unsigned data);
        uart_frame_t frame;
        frame.start  = 0;
        frame.data   = data;
        frame.parity = (^data); // even parity
        frame.stop   = 1;
        return frame;
    endfunction


    //--------------------------------------------------------------------------
    // Function: make_switch_packet
    // Creates a two-frame (address + data) UART packet
    //--------------------------------------------------------------------------
    function automatic switch_packet_t make_switch_packet(byte unsigned addr, byte unsigned data);
        switch_packet_t pkt;
        pkt.addr = make_uart_frame(addr);
        pkt.data = make_uart_frame(data);
        return pkt;
    endfunction


    //--------------------------------------------------------------------------
    // Random helper functions (biased randomization for test diversity)
    //--------------------------------------------------------------------------

    // Returns random 8-bit value, biased to 0x00 or 0xFF for edge coverage
    function automatic byte unsigned rand_biased_byte();
        int r;
        byte unsigned val;
        int unsigned tmp;
        r = $urandom_range(0,9);
        case (r)
            0: val = 8'h00;    // 10% -> 0x00
            1: val = 8'hFF;    // 10% -> 0xFF
            default: begin
                tmp = $urandom_range(1,254); // 80% -> others
                val = tmp[7:0];
            end
        endcase
        return val;
    endfunction

    // Returns random biased address (same as byte)
    function automatic byte unsigned rand_biased_addr();
        return rand_biased_byte();
    endfunction

    // Random start bit (0 = correct). 20% chance of error unless forced.
    function automatic bit rand_biased_start_bit(input bit force_correct);
        int r;
        if (force_correct) return 1'b0;
        r = $urandom_range(0,9);
        case (r)
            0,1: return 1'b1; // 20% -> error
            default: return 1'b0; // 80% -> correct
        endcase
    endfunction

    // Random stop bit (1 = correct). 20% chance of error unless forced.
    function automatic bit rand_biased_stop_bit(input bit force_correct);
        int r;
        if (force_correct) return 1'b1;
        r = $urandom_range(0,9);
        case (r)
            0,1: return 1'b0; // 20% -> error
            default: return 1'b1; // 80% -> correct
        endcase
    endfunction

    // Random parity bit (even). 30% chance of error unless forced.
    function automatic bit rand_biased_parity_bit(input byte unsigned data, input bit force_correct);
        int r;
        bit correct = (^data); // even parity
        if (force_correct) return correct;
        r = $urandom_range(0,9);
        case (r)
            0,1,2: return ~correct; // 30% -> incorrect
            default: return correct; // 70% -> correct
        endcase
    endfunction
    
endmodule : tp_gen
