`timescale 1ns / 1ps

module instr_mem_tb;
    reg addr;
    wire out;
    instr_mem dut(addr,out);
    
    initial begin
        addr=0;
        while(addr<9) begin
            #5 addr = addr + 1;
        end
    end 
endmodule