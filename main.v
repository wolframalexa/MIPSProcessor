`timescale 1ns / 1ps
`define OPCODEADD 00010

module pc(input rst, input clk, input[31:0] next_instr, output reg[31:0] cur_instr);
//simple program counter without jumps (just a 32 bit reg that increments and resets)
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



module main(

    );
endmodule
