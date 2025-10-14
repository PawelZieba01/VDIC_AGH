/******************************************************************************
 * (C) Copyright 2023 AGH University of Krakow, All Rights Reserved
 *
 * MODULE:    single_cycle
 * DEVICE:
 * PROJECT:   VDIC
 * AUTHOR:    szczygie
 * DATE:      2023 15:28:07
 *
 * ABSTRACT:  DUT component
 *
 *******************************************************************************/

module single_cycle
import tinyalu_pkg::*;
(
    input  logic    [7:0] A,
    input  logic    [7:0] B,
    input  logic          clk,
    input  OPCODE_T       opcode,
    input  logic          reset_n,
    input  logic          start,
    output logic          done_aax,
    output logic    [8:0] result_aax
);

always_ff @(posedge clk) begin : result_blk
    if(!reset_n) begin
        result_aax <= '0;
    end
    else begin
        if(start)begin
            case(opcode)
                OP_ADD: result_aax  <= A + B;
                OP_AND: result_aax  <= A & B;
                OP_XOR: result_aax  <= A ^ B;
                default: result_aax <= '0;
            endcase
        end
    end
end

always_ff @(posedge clk) begin : done_blk
    if(!reset_n) begin
        done_aax <= '0;
    end
    else begin
        if(start && (opcode != OP_NOP)) begin
            done_aax <= '1;
        end
        else begin
            done_aax <= '0;
        end
    end
end

endmodule
