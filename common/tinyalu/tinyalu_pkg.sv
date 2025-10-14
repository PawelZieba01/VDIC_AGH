package tinyalu_pkg;

    typedef enum bit [2:0]{
        OP_NOP   = 3'b000,
        OP_ADD   = 3'b001,
        OP_AND   = 3'b010,
        OP_XOR   = 3'b011,
        OP_MULT  = 3'b100,
        OP_IGNORED = 3'b111
    } OPCODE_T;

    function OPCODE_T logic_to_opcode (
            input logic [2:0] op
        );
        case (op)
            3'b000 : return OP_NOP;
            3'b001 : return OP_ADD;
            3'b010 : return OP_AND;
            3'b011 : return OP_XOR;
            3'b100 : return OP_MULT;
            default : begin
                return OP_IGNORED;
            end
        endcase

    endfunction

endpackage 