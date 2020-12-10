`timescale 1ns / 1ps
`define OPCODEADD 00010

module pc(input rst, input clk, input[31:0] next_instr, output reg[31:0] cur_instr);
// simple program counter without jumps (just a 32 bit reg that increments and resets)
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            cur_instr <= 0;
        end
        else begin
            cur_instr <= next_instr;
        end
    end
    
    initial cur_instr = 0;
endmodule

module instr_mem 
        #(parameter program_depth=9)
        (input[31:0] addr, output reg[31:0] read_data);
    reg [31:0] mem32X32 [0:program_depth];
    
    always @(addr) read_data <= mem32X32[addr];
   
    initial begin
        $readmemh("program.txt",mem32X32);
    end
endmodule

// some utilities that will be useful later on
module adder(input [31:0] a, b,
            output [31:0] y);
    assign y=a+b;
endmodule

module signext(input [15:0] a,
               output [31:0] y);
    assign y = {{16{a[15]}}, a};
endmodule

module flop #(parameter WIDTH=8)
        (input clk, reset,
        input [WIDTH-1:0] d,
        output reg [WIDTH-1:0] q);
    always @ (posedge clk, posedge reset)
        if (reset) q <= 0;
        else q <= d;
endmodule

module mux2 #(parameter WIDTH=8)
        (input [WIDTH-1:0] d0, d1,
         input s,
         output reg [WIDTH-1:0] y);
    always
        if (s) y <= d1;
        else y <= d0;
endmodule

module data_mem(input clk, WE,
            input [31:0] WD, A,
            output [31:0] RD);
    reg [31:0] RAM[63:0];
    
    assign RD = RAM[A[31:2]]; // word aligned
    
    always @ (posedge clk)
        if (WE) RAM[A[31:2]] <= WD;
endmodule 
             

module regfile(
            input clk,
            input WE3,
            input [4:0] RA1,RA2,WA3,
            input [31:0] WD3,
            output [31:0] RD1, RD2); 
    reg [31:0] RF[31:0];
    
    always @(posedge clk)
        if (WE3) RF[WA3] <= WD3;
    
    assign RD1 = RF[RA1];
    assign RD2 = RF[RA2]; 
endmodule

module maindec(
        input [5:0] opcode,
        output [2:0] ALUcontrol,
        output [1:0] ALUop,
        output branch, mem_write, mem2reg, ALUsrc, reg_dst, reg_write, jump
        );
    
    reg [8:0] controls;
    assign {reg_write, reg_dst, ALUsrc, branch, mem_write, mem2reg, ALUop} = controls;
            
    always @(*) begin
        case (opcode)
            000000: controls <= 9'b110000100; //R-type
            100011: controls <= 9'b101001000; //lw
            101011: controls <= 9'b0x101x000; //sw
            000100: controls <= 9'b0x010x010; //beq
            000100: controls <= 9'b101000000; //addi
            000010: controls <= 9'b0xxx0xxx1; //J-type
            default: controls <= 9'bxxxxxxxxx;
        endcase
    end
endmodule


module main(
    
    );
endmodule
