module EX_stage(
    input         clk,
    input         reset,
    input  MEM_allow_in,
    input  ID_to_EX_valid,
    output EX_allow_in,
    input  [332:0]ID_EX_bus,
    input   inst_bl,
    //input  [31:0] data_sram_rdata,
    output [240:0]EX_MEM_bus,
    output  EX_to_MEM_valid,
    
    
    output read_data_req,
    output [2:0]read_data_size,
    output [31:0]read_data_addr,
    input  read_data_addr_ok,

    output write_req,
    output [2:0]write_data_size,
    output [3:0]write_data_wstrb,
    output [31:0]write_data_addr,
    output [31:0]write_data_data,
    input  write_ok,
    input write_addr_ok,
    
    output [ 4:0] EX_dest_reg,
    output [ 4:0] EX_dest_rj,
    output [31:0] EX_time_w_rj,
    output EX_need_time_rj,
    
    output [13:0] EX_csr_addr,
    output [31:0] EX_csr_data,
    output EX_only_csr_r,
    //前递
    output EX_load,
    output [36:0]EX_to_ID_reg_result,
    
    input excp_flush,
    input ertn_flush,
    input no_we
    );
 
    reg  [31:0] EX_pc;
    
    wire EX_res_from_mem;
    
    reg EX_valid;
    wire EX_ready_go;
    reg  [11:0] EX_alu_op;
    reg         EX_src1_is_pc;
    reg         EX_src2_is_imm;
    reg         EX_src2_is_4;
    
    reg [98:0]w_time;
    reg [4:0] time_rj;
    reg [4:0] time_rd;
    reg [2:0]mem_type;
    reg ID_excp;
    reg [4:0] ID_excp_num;
    reg EX_ertn;
    wire [5:0]EX_excp_num;
    wire EX_excp;
    reg         EX_csr_we;
    reg EX_csr_me;
    reg EX_csr;
    reg [13:0]EX_csr_waddr;
    reg [31:0]EX_csr_rdata;
    reg         EX_res_from_mem_w;
    reg         EX_res_from_mem_b;
    reg         EX_res_from_mem_bu;
    reg         EX_res_from_mem_h;
    reg         EX_res_from_mem_hu;
    reg         EX_inst_st_w;
    reg         EX_inst_st_b;
    reg         EX_inst_st_h;   
    reg         EX_gr_we;
    reg         EX_mem_we;
    reg  [4: 0] EX_dest;
    reg  [31:0] EX_rj_value;
    reg  [31:0] EX_rkd_value;
    reg  [31:0] EX_imm;
    wire [31:0] alu_result;
    wire [31:0] EX_result;
    reg EX_inst_bl;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    reg  [31:0] EX_chose_wdata;
    
    reg EX_inst_div_w;
    reg EX_inst_div_wu;
    reg EX_inst_mod_w;
    reg EX_inst_mod_wu;
    reg EX_inst_mul_w;
    reg EX_inst_mulh_w;
    reg EX_inst_mulh_wu;
    
    wire need_run_div;
    wire run_mul;
    wire need_hilo_reg;
    
    //CSR
    wire [31:0]EX_csr_wdata;
    wire [31:0]EX_for_result;
    
    //例外
    wire excp_ale;
    
    wire [31:0]data_sram_addr;
    wire [1:0]ld_style;
    wire [1:0]st_style;
    wire all_st;
    assign EX_dest_rj=time_rj&{5{EX_valid}};
    assign EX_need_time_rj=w_time[98:96]!=3'b000;
    assign EX_time_w_rj=w_time[96]?w_time[31:0]:
                        w_time[97]?w_time[31:0]:
                        w_time[95:64];
                        
    assign read_data_req=EX_res_from_mem && EX_valid;
    assign all_st=EX_inst_st_b | EX_inst_st_h |EX_inst_st_w;
    assign EX_res_from_mem=EX_res_from_mem_w|EX_res_from_mem_b|EX_res_from_mem_bu|EX_res_from_mem_h|EX_res_from_mem_hu;
    
    assign EX_result=(EX_inst_div_w||EX_inst_div_wu)?div_result_i[31:0]:
                         (EX_inst_mod_w||EX_inst_mod_wu)?div_result_i[63:32]:
                         (EX_inst_mulh_w||EX_inst_mulh_wu)?mult_result_i[63:32]:
                          EX_inst_mul_w                    ?mult_result_i[31:0]:
                          EX_csr                           ?EX_csr_rdata       :alu_result;
    assign EX_ready_go    =EX_res_from_mem ? read_data_addr_ok && EX_valid || excp_ale :
                           all_st ? (write_ok && EX_valid ) || excp_ale:
                           EX_valid && (~need_run_div| (need_run_div&&(div_ready_i== 1'b1)));
    assign EX_allow_in     = !EX_valid || EX_ready_go && MEM_allow_in;
    assign EX_to_MEM_valid =  EX_valid && EX_ready_go;
    
    //例外
    assign excp_ale=(mem_type[0]|mem_type[1]|mem_type[2])&(
                                                            (mem_type[1]&alu_result[0])|
                                                            (mem_type[2]&(alu_result[1]|alu_result[0]))
                                                            );
    assign EX_excp_num={excp_ale,ID_excp_num};
    assign EX_excp=ID_excp|excp_ale;
    assign EX_MEM_bus = {
                        
                        time_rj,//236-240
                        time_rd,//231-235
                        w_time,//132-230
                        EX_ertn,//131
                        EX_excp_num,//125-130
                        EX_excp,//124
                        EX_csr_wdata,//92-123
                        EX_csr_waddr,//78-91
                        EX_csr_we,//77
                        data_sram_addr[1:0],//75-76
                        EX_pc,//74
                        EX_gr_we,//42
                        EX_dest,//37-41
                        EX_result,//5-36
                        EX_res_from_mem_w,//4
                        EX_res_from_mem_b,
                        EX_res_from_mem_bu,
                        EX_res_from_mem_h,
                        EX_res_from_mem_hu 
    };
    assign EX_dest_reg = EX_dest & {5{EX_valid}};
    assign EX_csr_addr=EX_csr_waddr&{14{EX_valid}};
    assign EX_csr_data=EX_csr_wdata;
    assign EX_only_csr_r=EX_csr_we;
always @(posedge clk) begin
    if (reset||excp_flush||ertn_flush) begin
        EX_valid <= 1'b0;
    end
    else if (EX_allow_in) begin
        EX_valid <= ID_to_EX_valid;
    end
    if (ID_to_EX_valid && EX_allow_in) begin
        {
        
        time_rj,//328-332
        time_rd,//323-327
        w_time,//224-322
        mem_type,//221-223
        EX_ertn,//220
        ID_excp_num,//215-219
        ID_excp,//214
        EX_csr,
        EX_csr_waddr,
        EX_csr_rdata,
        EX_csr_me,
        EX_csr_we,
        EX_inst_mod_wu,
        EX_inst_mod_w,
        EX_inst_div_wu,
        EX_inst_div_w,
        EX_inst_mulh_wu,
        EX_inst_mulh_w,
        EX_inst_mul_w,
        EX_pc ,
        EX_alu_op ,
        EX_src2_is_4,
        EX_src1_is_pc,
        EX_src2_is_imm,
        EX_gr_we,
        EX_mem_we,
        EX_dest,
        EX_imm,
        EX_rj_value,
        EX_rkd_value,
        EX_res_from_mem_w,
        EX_res_from_mem_b,
        EX_res_from_mem_bu,
        EX_res_from_mem_h,
        EX_res_from_mem_hu,
        EX_inst_st_h,
        EX_inst_st_b,//1
        EX_inst_st_w//0
        } <= ID_EX_bus;
        EX_inst_bl <= inst_bl;
    end
end
assign EX_load = EX_res_from_mem;
alu u_alu(
    .alu_op     (EX_alu_op ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );
    
assign need_run_div=EX_inst_div_w
                   |EX_inst_div_wu
                   |EX_inst_mod_w
                   |EX_inst_mod_wu;
assign need_hilo_reg=EX_inst_div_w
                    |EX_inst_div_wu
                    |EX_inst_mod_w
                    |EX_inst_mod_wu
                    |EX_inst_mul_w
                    |EX_inst_mulh_w
                    |EX_inst_mulh_wu;
assign run_mul=EX_inst_mul_w
              |EX_inst_mulh_w
              |EX_inst_mulh_wu;
//div
wire [63:0] div_result_i;//除法运算结果
wire div_ready_i;//除法运算是否结束
wire div_start_o;//除法运算是否开始
wire signed_div_o;//是否为有符号除法
assign div_start_o  = (need_run_div && div_ready_i == 1'b0) ? 1'b1 : 1'b0;
assign signed_div_o = (EX_inst_div_w||EX_inst_mod_w)?1'b1:
                      (EX_inst_div_wu||EX_inst_mod_wu)?1'b0:1'b0;
                        
div div0 (
  .clk(clk),                    
  .rst(~reset),    
  .signed_div_i(signed_div_o), 
  .opdata1_i(alu_src1),  
  .opdata2_i(alu_src2),  
  .start_i(div_start_o),
  .annul_i(1'b0),
  .result_o(div_result_i),   
  .ready_o(div_ready_i) 
);

//mul
wire [63:0] mult_result_i;
wire signed_mult_o;
assign signed_mult_o=(EX_inst_mul_w||EX_inst_mulh_w)?1'b1:
                     (EX_inst_mulh_wu)?1'b0:1'b0;
mult mult0(
    .clk(clk),
    .reset(reset),
    .signed_mult_i(signed_mult_o),       
    .opdata1_mult(alu_src1),
    .opdata2_mult(alu_src2),  
    .mult_result(mult_result_i) 
);

assign alu_src1 = EX_src1_is_pc  ? EX_pc : EX_rj_value;
assign alu_src2 = EX_src2_is_imm ? EX_imm : (EX_inst_bl ? 32'd4 : EX_rkd_value);
//assign data_sram_en = 1'b1;
//assign data_sram_we    = EX_mem_we && EX_valid&&~no_we&&~excp_ale ? 4'b1111 : 4'b0000;
assign data_sram_addr  = alu_result;

/*always @(*) begin
    if(EX_inst_st_w)begin
        EX_chose_wdata=EX_rkd_value;
    end
    if(EX_inst_st_b)begin
        case(alu_result[1:0])
        2'b00: EX_chose_wdata={data_sram_rdata[31:8],EX_rkd_value[7:0]};
        2'b01: EX_chose_wdata={data_sram_rdata[31:16],EX_rkd_value[7:0],data_sram_rdata[7:0]};
        2'b10: EX_chose_wdata={data_sram_rdata[31:24],EX_rkd_value[7:0],data_sram_rdata[15:0]};
        2'b11: EX_chose_wdata={EX_rkd_value[7:0],data_sram_rdata[23:0]};
        default: ;
        endcase
    end
    if(EX_inst_st_h)begin
        case(alu_result[1:0])
        2'b00: EX_chose_wdata={data_sram_rdata[31:16],EX_rkd_value[15:0]};
        2'b10: EX_chose_wdata={EX_rkd_value[15:0],data_sram_rdata[15:0]};
        default: ;
        endcase
    end
end*/
//assign data_sram_wdata = EX_chose_wdata;

assign read_data_size=EX_res_from_mem_w?3'b010:
                      EX_res_from_mem_h || EX_res_from_mem_hu ? 3'b001:
                      EX_res_from_mem_b || EX_res_from_mem_bu ? 3'b000:
                      3'b010;
assign read_data_addr=alu_result;
                      
assign ld_style = {
                   EX_res_from_mem_h || EX_res_from_mem_hu,
                   EX_res_from_mem_b || EX_res_from_mem_bu
                   };
//写
assign st_style={
                 EX_inst_st_h,
                 EX_inst_st_b
                 };
wire [1:0]w_data_size={
                  EX_inst_st_w,
                  EX_inst_st_h
                  };
wire [3:0]trb_b_low2={
                 alu_result[1:0]==2'b11,
                 alu_result[1:0]==2'b10,
                 alu_result[1:0]==2'b01,
                 alu_result[1:0]==2'b00
                 };
wire [3:0]trb_h_low2={
                 alu_result[1:0]==2'b10,
                 alu_result[1:0]==2'b10,
                 alu_result[1:0]==2'b00,
                 alu_result[1:0]==2'b00
                 };
wire [3:0]trb_w_low2=4'b1111;
wire [3:0]w_data_trb={
                      {4{w_data_size[1]}} & trb_w_low2 |
                      {4{w_data_size[0]}} & trb_h_low2 |
                      {4{w_data_size==2'b00}} & trb_b_low2
                      };
wire [31:0] stb_wdata;
wire [31:0] sth_wdata;
assign stb_wdata={
                 {8{trb_b_low2[3]}} & EX_rkd_value[7:0],
                 {8{trb_b_low2[2]}} & EX_rkd_value[7:0],
                 {8{trb_b_low2[1]}} & EX_rkd_value[7:0],
                 {8{trb_b_low2[0]}} & EX_rkd_value[7:0]
                  };
assign sth_wdata={
                 {16{trb_h_low2[3]}} & EX_rkd_value[15:0],
                 {16{trb_h_low2[0]}} & EX_rkd_value[15:0]
                  };
reg [1:0]no_we_state;
localparam no_we_idle=2'b00;
localparam no_we_ing = 2'b01;
always @(posedge clk)begin
    if(reset)begin
        no_we_state <= no_we_idle;
    end
    else
    case (no_we_state)
        no_we_idle:begin
            if(no_we)begin
               no_we_state <= no_we_ing; 
            end
        end
        no_we_ing:begin
            if(excp_flush || ertn_flush)begin
                no_we_state <= no_we_idle;
            end
        end
    endcase
end
assign write_req= ~write_addr_ok && all_st && EX_valid && ~(no_we_state == no_we_ing) && ~no_we&& ~excp_ale;
assign write_data_size=EX_inst_st_w ? 3'b010:
                       EX_inst_st_h ? 3'b001:
                       EX_inst_st_b ? 3'b000:
                       3'b010;
assign write_data_wstrb=w_data_trb;
assign write_data_addr=alu_result;
assign write_data_data=EX_inst_st_b ? stb_wdata :
                       EX_inst_st_h ? sth_wdata :
                       EX_rkd_value;
assign EX_csr_wdata=EX_csr_me?((EX_rj_value & EX_rkd_value) | (~EX_rj_value & EX_csr_rdata)):EX_rkd_value;
//前递
assign EX_for_result=EX_result;
assign EX_to_ID_reg_result = {
                               EX_dest&{5{EX_valid}},  //36:32
                               EX_for_result//31:0
                              };

endmodule