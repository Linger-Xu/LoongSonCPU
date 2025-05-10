`timescale 1ns / 1ps
module div(
    input wire clk,
    input wire rst,
    input wire signed_div_i,//是否为有符号除法       
    input wire[31:0] opdata1_i,//被除数
    input wire[31:0] opdata2_i,//除数    
    input wire start_i,//是否开始除法运算       
    input wire annul_i,//是否取消除法运算 
    //input wire ws_ex,
   // input wire ws_eret,   
    output reg[63:0] result_o,//除法运算结果 
    output reg ready_o       //除法运算是否结束      
    );
    wire[32:0] div_temp;
    reg[5:0] cnt;//记录了试商法进行了几轮                   
    reg[64:0] dividend;//最低位保存每次迭代的结果，高32位保存每次迭代时的被减数
    reg[1:0] state;
    reg[31:0] divisor;//除数
    reg[31:0] temp_op1;
    reg[31:0] temp_op2;
    assign div_temp = {1'b0, dividend[63:32]} - {1'b0, divisor};
    always @ (*) begin
        if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin//有符号除法，并且操作数为负数
            temp_op1 <= ~opdata1_i + 1;//取补码
        end else begin
            temp_op1 <= opdata1_i;
        end
        if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1) begin 
            temp_op2 <= ~opdata2_i + 1;
        end else begin
            temp_op2 <= opdata2_i;
        end
    end
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            state <= 2'b00;
            ready_o <= 1'b0;
            result_o <= {32'h00000000, 32'h00000000};
        end begin 
            case (state)
                2'b00: begin//DivFree状态
                        if(start_i == 1'b1 && annul_i == 1'b0) begin
                            if(opdata2_i == 32'h00000000) begin
                                state <= 2'b01; 
                            end else begin
                                state <= 2'b10;    //进入DivOn状态   
                                cnt <= 6'b000000;
                                dividend <= {32'h00000000, 32'h00000000};
                                dividend[32:1] <= temp_op1;
                                divisor <= temp_op2;
                            end
                        end else begin//没有开始除法运算
                            ready_o <= 1'b0;
                            result_o <= {32'h00000000, 32'h00000000};
                        end
                    end
                    2'b01: begin//DivByZero状态
                        dividend <= {32'h00000000, 32'h00000000};
                        state <= 2'b11;
                    end
                    2'b10: begin//DivOn状态
                        if (annul_i == 1'b0) begin
                            if(cnt != 6'b100000) begin
                                if(div_temp[32] == 1'b1) begin//减法结果为负数
                                    dividend <= {dividend[63:0], 1'b0};
                                end else begin
                                    dividend <= {div_temp[31:0], dividend[31:0], 1'b1};
                                end
                                cnt <= cnt + 1;
                            end else begin
                                if((signed_div_i == 1'b1) 
                                    && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin 
                                    dividend[31:0] <= (~dividend[31:0] + 1);
                                end
                                if((signed_div_i == 1'b1)
                                    && ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin
                                    dividend[64:33] <= (~dividend[64:33] + 1);
                                end
                                state <= 2'b11;
                                cnt <= 6'b000000;
                            end
                        end else begin
                            state <= 2'b00;
                        end
                    end
                    2'b11: begin//DivEnd状态
                        result_o<= {dividend[64:33], dividend[31:0]};
                        ready_o <= 1'b1;
                        if (start_i == 1'b0) begin
                            state <= 2'b00;
                            ready_o <= 1'b0;
                            result_o <= {32'h00000000, 32'h00000000};
                        end
                    end
                endcase
            end
        end
endmodule

