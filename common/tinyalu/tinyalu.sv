
/******************************************************************************
 * (C) Copyright 2024 AGH University of Krakow, All Rights Reserved
 *
 * MODULE:    tinyalu
 * DEVICE:
 * PROJECT:   VDIC
 * AUTHOR:    szczygie
 * DATE:      2024-10-04
 *
 * ABSTRACT:  DUT component
 *
 *******************************************************************************/

module tinyalu (
    input  logic [7:0]  A,
    input  logic [7:0]  B,
    input  logic        clk,
    input  logic [2:0]  op,
    input  logic        reset_n,
    input  logic        start,
    output logic        done,
    output logic [15:0] result
);

import tinyalu_pkg::*;

wire            start_single;
wire            start_mult;
wire            done_aax;
wire     [8:0]  result_aax;
wire            done_mult;
wire     [15:0] result_mult;

OPCODE_T        opcode;
wire            is_single_cycle;
wire            is_multi_cycle;

assign opcode          = logic_to_opcode(op);
assign is_single_cycle = (opcode == OP_ADD || opcode == OP_AND || opcode == OP_XOR);
assign is_multi_cycle  = (opcode == OP_MULT);

assign start_single    = start & is_single_cycle;
assign start_mult      = start & is_multi_cycle;
assign result          = is_multi_cycle ? result_mult : {7'd0, result_aax};
assign done            = is_multi_cycle ? done_mult : done_aax;

single_cycle u_single_cycle (
    .A,
    .B,
    .clk,
    .done_aax,
    .opcode(opcode),
    .reset_n,
    .result_aax,
    .start (start_single)
);

three_cycle u_three_cycle (
    .A,
    .B,
    .clk,
    .done_mult,
    .reset_n,
    .result_mult,
    .start(start_mult)
);

endmodule
