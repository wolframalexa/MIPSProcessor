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

module sl2(input [31:0] a,
           output [31:0] y);
         // shift left by 2
         
         assign y = {a[29:01], 2'b00}; 
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
            6'b000000: controls <= 9'b110000100; //R-type
            6'b100011: controls <= 9'b101001000; //lw
            6'b101011: controls <= 9'b0x101x000; //sw
            6'b000100: controls <= 9'b0x010x010; //beq
            6'b000100: controls <= 9'b101000000; //addi
            6'b000010: controls <= 9'b0xxx0xxx1; //J-type
            default: controls <= 9'bxxxxxxxxx;
        endcase
    end
endmodule

module controller(input [5:0] op, funct,
                  input     zero,
                  output    memtoreg, memwrite,
                  output    pcsrc, alusrc,
                  output    regdst, regwrite,
                  output    jump,
                  output    [2:0] alucontrol);

    wire [1:0] aluop;
    wire       branch;

    maindec md(op, memtoreg, memwrite, branch, alusrc,
           regdst, regwrite, jump, aluop);                    
    aludec ad(funct, aluop, alucontrol);

    assign pcsrc = branch && zero;
endmodule

module aludec(input     [5:0] funct,
              input     [1:0] aluop,
              output reg [2:0] alucontrol);
              
always @(*)
    case(aluop)
      2'b00: alucontrol <= 3'b010; // add
      2'b01: alucontrol <= 3'b110; // subtract
      default: case(funct)
        6'b100000: alucontrol <= 3'b010; // ADD
        6'b100010: alucontrol <= 3'b110; // SUB
        6'b100100: alucontrol <= 3'b000; // AND
        6'b100101: alucontrol <= 3'b001; // OR
        6'b101010: alucontrol <= 3'b111; // SLT
        default:   alucontrol <= 3'bxxx; // ???
      endcase
    endcase      
endmodule              

module datapath (input clk, reset,
                 input memtoreg, pcsrc,
                 input alusrc, regdst,
                 input regwrite, jump,
                 input [2:0] alucontrol,
                 output zero,
                 output [31:0] pc,
                 input [31:0] instr,
                 output [31:0] aluout, writedata,
                 input [31:0] readdata);

    wire [4:0] writereg;
    wire [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
    wire [31:0] signimm, signimmsh;
    wire [31:0] srca, srcb;
    wire [31:0] result;

    // next PC logic
    flopr #(32) pcreg(clk, reset, pcnext, pc);
    adder pcadd1 (pc, 32'b100, pcplus4);
    
    sl2 immsh(signimm, signimmsh);
    adder pcadd2(pcplus4, signimmsh, pcbranch);
    mux2 #(32) pcbrmux(pcplus4, pcbranch, pcsrc,
                       pcnextbr);
    mux2 #(32) pcmux(pcnextbr, {pcplus4[31:28],
    instr[25:0], 2'b00}, jump, pcnext);

    // register file logic
    regfile rf(clk, regwrite, instr[25:21],
            instr[20:16], writereg, result, srca, writedata);
    mux2 #(5) wrmux(instr[20:16], instr[15:11],
            regdst, writereg);
    mux2 #(32) resmux(aluout, readdata,
            memtoreg, result);
    signext se(instr[15:0], signimm);

    // ALU logic
    mux2 #(32) srcbmux(writedata, signimm, alusrc, srcb);
    alu alu(srca, srcb, alucontrol, aluout, zero);

endmodule

module main(input       clk, reset,
            output [31:0]   pc,
            input [31:0]    instr,
            output          memwrite,
            output [31:0]   aluout, writedata,
            input [31:0]    readdata);
    
    wire    memtoreg, branch,
            alusrc, regdst, regwrite, jump;
    wire [2:0]  alucontrol;
    
    controller c(instr[31:26], instr[5:0], zero, memtoreg, memwrite,
                 memwrite, pcsrc, alusrc, regdst, regwrite, jump,
                 alucontrol);
                 
    datapath dp(clk, reset, memtoreg, pcsrc, alusrc, regdst, regwrite, jump,
                 alucontrol, zero, pc, instr, aluout, writedata, readdata);
endmodule
