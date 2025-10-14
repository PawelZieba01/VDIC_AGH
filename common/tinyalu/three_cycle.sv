/******************************************************************************
 * (C) Copyright 2023 AGH University of Krakow, All Rights Reserved
 *
 * MODULE:    three_cycle_mult
 * DEVICE:
 * PROJECT:   VDIC
 * AUTHOR:    szczygie
 * DATE:      2023 15:28:07
 *
 * ABSTRACT:  DUT component
 *
 *******************************************************************************/

module three_cycle(
    input  logic [7:0]  A,
    input  logic [7:0]  B,
    input  logic        clk,
    input  logic        reset_n,
    input  logic        start,
    output logic        done_mult,
    output logic [15:0] result_mult
);

logic [15:0] mult1;
logic [15:0] mult2;
logic        done1;
logic        done2;

always_ff @(posedge clk) begin : run_blk
    if(!reset_n) begin
        result_mult <= '0;
        mult1       <= '0;
        mult2       <= '0;
        done_mult   <= '0;
        done1       <= '0;
        done2       <= '0;
    end
    else begin
        mult2       <= A * B;
        mult1       <= mult2;
        result_mult <= mult1;
        done2       <= start & ~(done2 | done1);
        done1       <= done2;
        done_mult   <= done1;
    end
end

endmodule
