`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/29/2020 09:42:28 PM
// Design Name: 
// Module Name: pc_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pc_tb;
    reg rst;
    reg clk;
    reg[31:0] next_instr;
    wire[31:0] cur_instr; 
    pc dut(rst, clk, next_instr, cur_instr);
    
    always begin
        #5 clk <=~clk;
    end
    
    initial begin
        rst=0;
        clk=0;
        next_instr=0;
    
        repeat(32) @(posedge clk) begin
            #5 next_instr = next_instr+1;
        end
        
        rst <= 1;
        
    end
endmodule
