`include "CSR.vh"
module WB_stage(
  input  clk,
  input  reset,
  output WB_allow_in,
  input  MEM_to_WB_valid,
  input  [265:0] MEM_WB_bus,
  output [37:0] WB_rf_bus,
  output [37:0] WB_rf_bus0,
  output [31:0] debug_wb_pc,
  output [ 3:0] debug_wb_rf_we,
  output [ 4:0] debug_wb_rf_wnum,
  output [31:0] debug_wb_rf_wdata,
  output [ 4:0] WB_dest_reg,
  
  output [ 4:0] WB_dest_rj,
  output [31:0] WB_time_w_rj,
  output WB_need_time_rj,
  
  output [13:0] WB_csr_addr,
  output [31:0] WB_csr_data,
  output WB_only_csr_r,
  
  output [36:0]WB_to_ID_reg_result,
  output WB_to_csr_we,
  output [13:0]WB_to_csr_waddr,
  output [31:0]WB_to_csr_wdata,
  
  //例外
  output excp_flush,
  output ertn_flush,
  output [5:0]csr_ecode,
  output [8:0]csr_esubcode,
  output [31:0]pc_to_era,
  
  output error_badv,
  output [31:0] error_badv_pc

  );

reg [31:0] WB_pc;
reg WB_valid;
wire WB_ready_go;

reg [98:0]w_time;
reg [4:0] time_rj;
reg [4:0] time_rd;
reg [31:0]mem_error_addr; 
reg WB_ertn;
reg [5:0]WB_excp_num;
reg WB_excp;
reg [31:0]WB_csr_wdata;
reg [13:0]WB_csr_waddr;
reg WB_csr_we;
reg WB_gr_we;
reg [4:0]WB_dest;
reg [31:0]WB_final_result;
wire rf_we   ;
wire [4:0]rf_waddr;
wire [31:0]rf_wdata;
wire is_mul_more;
//例外

//time
wire [4:0]rf_time_rd;
wire [4:0]rf_time_rj;
wire rf_time_we;
wire [31:0]time_h;
wire [31:0]time_l;
wire time_h_we;
wire time_l_we;
wire time_64_we;
wire [31:0]time_tid;
assign {time_64_we,time_h_we,time_l_we,{time_h,time_l},time_tid}=w_time;
assign WB_time_w_rj=w_time[96]?w_time[31:0]:
                        w_time[97]?w_time[31:0]:
                        w_time[95:64];

assign WB_to_csr_we=WB_csr_we&&WB_valid;
assign WB_to_csr_waddr=WB_csr_waddr;
assign WB_to_csr_wdata=WB_csr_wdata;

assign WB_ready_go = WB_rf_bus[37] && WB_rf_bus0[37] ? rj_rf_write==wait2 :
                     1'b1;
assign WB_allow_in  = !WB_valid || WB_ready_go;
assign WB_dest_reg = WB_dest & {5{WB_valid}};
assign WB_dest_rj=  time_rj  & {5{WB_valid}};
assign WB_need_time_rj=time_64_we|time_h_we|time_l_we;
reg [1:0]rj_rf_write;
localparam wait1=2'b00;
localparam wait2=2'b01;
always @(posedge clk)begin
    if(reset)begin
        rj_rf_write <= wait1;
    end
    else
    case (rj_rf_write)
        wait1:begin
            if(WB_rf_bus[37] && WB_rf_bus0[37])begin
                rj_rf_write <= wait2;
            end
        end
        wait2:begin
            rj_rf_write <=wait1;
        end
    endcase
        
end
assign WB_csr_addr=WB_csr_waddr&{14{WB_valid}};
assign WB_csr_data=WB_csr_wdata;
assign WB_only_csr_r=WB_csr_we;
always @(posedge clk) begin
    if (reset||excp_flush||ertn_flush) begin
        WB_valid <= 1'b0;
    end
    else if (WB_allow_in) begin
        WB_valid <= MEM_to_WB_valid;
    end

    if (MEM_to_WB_valid && WB_allow_in) begin
      {
       
       time_rj,//261-265
       time_rd,//256-260
       w_time,//157-255
       mem_error_addr,//125-156
       WB_ertn,//124
       WB_excp_num,//118-123
       WB_excp,//117      
       WB_csr_wdata,//85-116
       WB_csr_waddr,//71-84
       WB_csr_we,//70
       WB_pc,//69
       WB_gr_we,
       WB_dest,
       WB_final_result} <= MEM_WB_bus;
       
    end
end
 
assign rf_we    = WB_gr_we && WB_valid&~excp_flush;
assign rf_waddr = WB_dest;
assign rf_wdata = (time_64_we|time_l_we)?time_l:
                   time_h_we            ?time_h:
                   WB_final_result;
 
assign WB_rf_bus = {
                    rf_we && WB_valid,//37
                    rf_waddr,//36:32
                    rf_wdata//31:0
                    };
assign WB_rf_bus0 = {
                    (time_64_we|time_h_we|time_l_we) && WB_valid,//37
                    time_rj,//36:32
                    ({32{time_64_we}}&time_h)|
                    ({32{time_h_we}}&time_tid)|
                    ({32{time_l_we}}&time_tid)//31:0
                    };
assign debug_wb_pc       = rf_we ? WB_pc : debug_wb_pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = WB_valid && rf_we ? WB_dest : debug_wb_rf_wnum;
assign debug_wb_rf_wdata = WB_valid && rf_we ? WB_final_result : debug_wb_rf_wdata;

//例外信号
assign excp_flush=WB_excp&WB_valid;
assign ertn_flush=WB_ertn&WB_valid;
assign {
        csr_ecode,
        csr_esubcode,
        error_badv,
        error_badv_pc
        }=
          
          WB_excp_num[0]?{`ECODE_INT ,9'b0,1'b0,32'b0}:
          WB_excp_num[1]?{`ECODE_ADEF,9'b0,WB_valid,WB_pc}:
          WB_excp_num[2]?{`ECODE_SYS ,9'b0,1'b0,32'b0}:
          WB_excp_num[3]?{`ECODE_BRK ,9'b0,1'b0,32'b0}:
          WB_excp_num[4]?{`ECODE_INE ,9'b0,1'b0,32'b0}:
          WB_excp_num[5]?{`ECODE_ALE ,9'b0,WB_valid,mem_error_addr}:
          48'b0;
assign pc_to_era=WB_pc;

assign WB_to_ID_reg_result={
                            WB_dest,
                            rf_wdata
                            };
 
endmodule