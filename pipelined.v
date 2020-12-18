module pipelineFD(
        input clk,
        input [31:0] instrF, pcplus4F, 
        output reg[31:0] instrD, pcplus4D
        );
    always @(posedge clk) begin
        instrD<=instrF;
        pcplus4D<=pcplus4F;
    end
endmodule

module pipelineDE(
    input clk,
    input [31:0] Rd1D, Rd2D, signextD, pcplus4D,
    input [8:0] controlsD,
    input [4:0] RtD, RdD,
    output reg[31:0] Rd1E, Rd2E, signextE, pcplus4E,
    output reg[4:0] RtE, RdE,
    output reg[8:0] controlsE
    );
    //controls is all the outputs of the control unit
    
    always @(posedge clk) begin
        {Rd1E, Rd2E, signextE, pcplus4E, RtE, RdE, controlsE} <= {Rd1D, Rd2D, signextD, pcplus4D, RtD, RdD, controlsD};
    end
endmodule

module pipelineEM(
    input clk, zeroE, 
    input [3:0] controlsE,
    input [31:0] ALUoutE, writedataE, pcbranchE,
    input [4:0] writeregE,
    output reg zeroM,
    output reg[3:0] controlsM,
    output reg[31:0] ALUoutM, writedataM, pcbranchM,
    output reg[4:0] writeregM
    );
    //controls is outputs of control unit
    // not used in execute stage (regwrite, mem2reg, memwrite, branch)
    always @(posedge clk) begin
        {zeroM, controlsM, ALUoutM, writedataM, pcbranchM, writeregM} <= {zeroE, controlsE, ALUoutE, writedataE, pcbranchE, writeregE};
    end
endmodule

module pipelineMW(
    input clk, regwriteM, mem2regM,
    input [31:0] readdataM, ALUoutM,
    input [4:0] writeregM,
    output reg regwriteW, mem2regW,
    output reg[31:0] readdataW, ALUoutW,
    output reg[4:0] writeregW);
    
    always @(posedge clk) begin
        {regwriteW, mem2regW, readdataW, ALUoutW, writeregW} <= {regwriteM, mem2regM, readdataM, ALUoutM, writeregM};
    end
endmodule

module pip_controller(input [5:0] op, funct,
                  output    mem2reg, memwrite,
                  output    alusrc,
                  output    regdst, regwrite,
                  output    branch,
                  output    [2:0] alucontrol);
    //seperate controller bc pcsrc is assigned in memory stage
    
    wire jump; //not implemented but needed as output of maindec
    wire [1:0] aluop;

    maindec md(op, aluop, branch, memwrite, mem2reg,
           alusrc, regdst, regwrite, jump);                    
    aludec ad(funct, aluop, alucontrol);

endmodule

module pipelined_mips(
    input clk, reset,
    output [31:0] writedata, dataadr,
    output memwrite
    );
    
    wire [31:0] resultW;
    //control wires (need individual to work with controller module)
    wire regwriteD, mem2regD, memwriteD, branchD, ALUcontrolD, ALUsrcD, RegDstD, jump;
    wire ALUsrcE, RegDstE;
    wire [2:0] ALUcontrD, ALUcontrE;
    wire [8:0] controlsD, controlsE;
    wire [3:0] controlsM;
    wire regwriteM, mem2regM, memwriteM, branchM;
    wire regwriteW, mem2regW;
    assign {regwriteD, mem2regD, memwriteD, branchD, ALUcontrolD, ALUsrcD, RegDstD} = controlsD;
    
    //Fetch internals - prog. counter, instr. 
    wire [31:0] pcnext, pc, instrF, pcplus4F;
    flopr #(32) pcreg(clk, reset, pcnext, pc); //program counter
    imem imem (pc[7:2], instrF); //instruction memory
    adder pcadd1 (pc, 32'b100, pcplus4F);
//    mux2 #(32) pcbrmux(pcplus4F, pcbranch, pcsrc,
//                       pcnextbr);
    
    //Fetch --> Decode
    wire [31:0] instrD, pcplus4D, signextD;
    pipelineFD pipFD(clk, instrF, pcplus4F, instrD, pcplus4D);
    
    //Decode internals - sign extension, reg file
    signext se(instrD[15:0], signextD);
    wire [31:0] Rd1D, Rd2D;
    wire [4:0] writeRegW;
    regfile regf(clk, regwriteW, instrD[25:21], instrD[20:16], writeRegW, resultW, Rd1D, Rd2D);
    
    //Decode --> Execute wires
    wire [31:0] Rd1E, Rd2E, signextE, pcplus4E;
    wire [4:0] RtD, RdD, RtE, RdE; //writeRegW is used as input to register file
    pipelineDE pipDE(clk, Rd1D, Rd2D, signextD, pcplus4D, controlsD, RtD, RdD, Rd1E, Rd2E, signextE, pcplus4E, RtE, RdE, controlsE);
    
    //Execute internals - ALU, left shift, mux2
    wire [31:0] SrcB, signimmx4, ALUoutE, pcbranchE;
    wire [4:0] writeRegE;
    wire zeroE;
    wire [2:0] ALUcontrolE;
    assign ALUcontrolE = controlsE[4:2];
    assign {ALUsrcE, RegDstE} = controlsE[1:0];

    mux2 #(5) Regdst(RtE, RdE, RegDstE, writeRegE);
    mux2 #(32) alusrc(Rd2E, signextE, ALUsrcE, SrcB);
    alu ALU(Rd1E, SrcB, ALUcontrolE, ALUoutE, zeroE);
    sl2 immsh(signextE, signimmx4);
    adder pcadd2(pcplus4E, signimmx4, pcbranchE);
    
    
    //Execute --> Memory
    wire zeroM;
    wire [31:0] ALUoutM, writeDataE, writeDataM, pcbranchM, readdataM;
    wire [4:0] writeRegM;
    pipelineEM pipEM(clk, zeroE, controlsE[8:5], ALUoutE, writeDataE, pcbranchE, writeRegE,
               zeroM, controlsM, ALUoutM, writeDataM, pcbranchM, writeRegM);
    
    assign {regwriteM, mem2regM, memwriteM, branchM} = controlsM; 
    
    
    //Memory internals - data memory
    wire pcSrc;
    assign pcSrc = branchM && zeroM;
    dmem dmem (clk, memwriteM, ALUoutM, writeDataM,
            readdataM);
    mux2 pcbrmux(pcplus4F, pcbranchM, pcSrc, pcnext);
    
    //Memory --> Writeback
    wire [31:0] readdataW, ALUoutW;
    pipelineMW pipMW(clk, regwriteM, mem2regM, readdataM, ALUoutM, writeRegM, 
            regwriteW, mem2regW, readdataW, ALUoutW, writeRegW);
    
    
    //Writeback 
    mux2 #(32) resmux(ALUoutW, readdataW,
            mem2regW, resultW);
    
    //components
    controller c(instrD[31:26], instrD[5:0], ALUsrcD, RegDstD, regwriteD, jump, branchD, ALUcontrolD);
    
endmodule