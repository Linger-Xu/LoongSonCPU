`timescale 1ns / 1ps
module mult(
    input wire clk,
    input wire reset,
    input wire signed_mult_i,       
    input wire[31:0] opdata1_mult,//被乘数
    input wire[31:0] opdata2_mult,//乘数    
    output reg[63:0] mult_result //结果
    );         
    reg[31:0] mult_op1;
    reg[31:0] mult_op2;
    wire [63:0] mult_temp;
    always @ (*) begin
        if(signed_mult_i == 1'b1 && opdata1_mult[31] == 1'b1) begin
           mult_op1 <= ~opdata1_mult + 1;
        end else begin
            mult_op1 <= opdata1_mult ;
        end
        if(signed_mult_i == 1'b1 && opdata2_mult[31] == 1'b1) begin 
            mult_op2 <= ~opdata2_mult + 1;
        end else begin
            mult_op2 <= opdata2_mult;
        end
    end
    assign mult_temp = mult_op1 * mult_op2;
    always @(*) begin
        if(reset) begin
            mult_result <= 64'd0;
    end
    else if(signed_mult_i == 1'b1) begin
        if(opdata1_mult[31] ^ opdata2_mult[31] == 1'b1) begin
            mult_result <= ~mult_temp + 1;
        end
        else begin
            mult_result <= mult_temp;
        end
    end
    else begin
        mult_result <= mult_temp;
    end
end
endmodule
