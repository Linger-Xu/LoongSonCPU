
module ID_stage(
  input  clk,
  input  reset,
  input  EX_allow_in,
  input  IF_to_ID_valid,
  input  [65:0]IF_ID_bus,
  input  [37:0]WB_rf_bus,
  input  [37:0]WB_rf_bus0,
  
  input  [ 4:0]EX_dest,
  input  [ 4:0]EX_dest_rj,
  input  [ 31:0]EX_time_w_rj,
  input  EX_need_time_rj,
  input  [ 4:0]MEM_dest,
  input  [ 4:0]MEM_dest_rj,
  input  [ 31:0]MEM_time_w_rj,
  input  MEM_need_time_rj,
  input  [ 4:0]WB_dest,
  input  [ 4:0]WB_dest_rj,
  input  [ 31:0]WB_time_w_rj,
  input  WB_need_time_rj,

  output ID_allow_in,
  output [33:0]br_bus,
  output [332:0]ID_EX_bus,
  output ID_to_EX_valid,
  output to_EX_inst_bl,
  //前递
  input  EX_load,
  input  [110:0]forwarding,
  
  output [13:0]ID_to_csr_raddr,
  input  [31:0]csr_to_ID_rdata,
  
  input [13:0]EX_csr_addr,
  input [13:0]MEM_csr_addr,
  input [13:0]WB_csr_addr,
  input [31:0]EX_csr_data,
  input [31:0]MEM_csr_data,
  input [31:0]WB_csr_data,
  input EX_only_csr_r,
  input MEM_only_csr_r,
  input WB_only_csr_r,
  //64位计数
  input [63:0]time_64,
  input [31:0]time_tid,
  //中断
  input has_int,
  
  
  input [1:0]crmd_plv,
  input excp_flush,
  input ertn_flush
  
    ); 
 
wire [2:0] mem_type;

reg if_excp_num;
reg if_excp;
reg  [31:0] ID_pc;
reg  [31:0] ID_inst;
reg  ID_valid;
wire ID_ready_go;
reg delay_slot;
 
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        src_reg_is_rd;
wire        src_reg_is_rj;
wire        src_reg_is_rk;
wire need_csr_reg;
wire        dst_is_r1;
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] op_9_5;

wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
 
wire rf_we  ;
wire [4:0]rf_waddr;
wire [31:0]rf_wdata;
wire [4:0]rf_raddr1;
wire [31:0]rf_rdata1;
wire [4:0]rf_raddr2;
wire [31:0]rf_rdata2;
 
wire [11:0] alu_op;
wire op_div_w;
wire op_div_wu;
wire op_mod_w;
wire op_mod_wu;
wire op_mul_w;
wire op_mulh_w;
wire op_mulh_wu;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        res_from_mem_w;
wire        res_from_mem_b;
wire        res_from_mem_bu;
wire        res_from_mem_h;
wire        res_from_mem_hu;
wire        gr_we;
wire        mem_we;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
//time
wire [98:0] w_time;
wire [4:0]time_rd;
wire [4:0]time_rj; 
wire time_rj_we;
wire [31:0]time_rj_data;
wire [4:0]time_rj_addr;
 
wire br_stall;
wire br_taken;
wire [31:0]br_target;
 
wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [4:0]  op_9_5_d;
wire [31:0] rj_d;
wire [31:0] rk_d;
wire [31:0] rd_d;
 
wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire inst_pcaddu12i;
wire inst_slti;
wire inst_sltui;
wire inst_andi;
wire inst_ori;
wire inst_xori;
wire inst_sll_w;
wire inst_sra_w;
wire inst_srl_w;

wire inst_div_w;
wire inst_div_wu;
wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;
wire inst_mod_w;
wire inst_mod_wu;

wire inst_blt;
wire inst_bge;
wire inst_bltu;
wire inst_bgeu;

wire inst_ld_b;
wire inst_ld_h;
wire inst_ld_bu;
wire inst_ld_hu;
wire inst_st_b;
wire inst_st_h;

//exception
wire inst_csr_rd;
wire inst_csr_wr;
wire inst_csr_xchg;
wire inst_ertn;
wire inst_syscall;
wire inst_break;

wire inst_rdtime_l_w;
wire inst_rdtime_h_w;
wire inst_rdtime_d;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
 
wire [31:0]alu_src1;
wire [31:0]alu_src2;

//crs
wire ID_csr_we;
wire ID_csr_me;
wire ID_csr;
wire [13:0]ID_csr_waddr;

//发生例外所需信号

wire ID_excp;
wire [4:0]ID_excp_num;
wire excp_ine;

wire block;
assign no_we=inst_syscall;

assign op_31_26  = ID_inst[31:26];
assign op_25_22  = ID_inst[25:22];
assign op_21_20  = ID_inst[21:20];
assign op_19_15  = ID_inst[19:15];
assign op_9_5    = ID_inst[9:5];
assign rd   = ID_inst[ 4: 0];
assign rj   = ID_inst[ 9: 5];
assign rk   = ID_inst[14:10];
 
wire same_rj;
wire same_rk;
wire same_rd;
wire inst_no_dest_reg;
wire same_csr_reg;
wire same_csr_tid;
wire same_time_rj;
wire same_time_rk;
wire same_time_rd;

wire [31:0]final_csr_data;
wire [31:0]final_csr_tid;
assign same_time_rd=src_reg_is_rd&&rd != 5'b0&&(((rd==EX_dest_rj)&&EX_need_time_rj)|((rd==MEM_dest_rj)&&MEM_need_time_rj)|((rd==WB_dest_rj)&&WB_need_time_rj));
assign same_time_rj=src_reg_is_rj&&rj != 5'b0&&(((rj==EX_dest_rj)&&EX_need_time_rj)|((rj==MEM_dest_rj)&&MEM_need_time_rj)|((rj==WB_dest_rj)&&WB_need_time_rj));
assign same_time_rk=src_reg_is_rk&&rk != 5'b0&&(((rk==EX_dest_rj)&&EX_need_time_rj)|((rk==MEM_dest_rj)&&MEM_need_time_rj)|((rk==WB_dest_rj)&&WB_need_time_rj));
assign same_rd = (src_reg_is_rd && rd != 5'b0 &&((rd == EX_dest) || (rd == MEM_dest) || (rd == WB_dest))); 
assign same_rj = (src_reg_is_rj && rj != 5'b0 &&((rj == EX_dest) || (rj == MEM_dest) || (rj == WB_dest))); 
assign same_rk = (src_reg_is_rk && rk != 5'b0 &&((rk == EX_dest) || (rk == MEM_dest) || (rk == WB_dest))); 
assign same_csr_tid=((14'h40==EX_csr_addr)&EX_only_csr_r)||((14'h40==MEM_csr_addr)&MEM_only_csr_r)||((14'h40==WB_csr_addr)&WB_only_csr_r);
assign same_csr_reg=need_csr_reg && ID_to_csr_raddr!=14'b0&&(((ID_to_csr_raddr==EX_csr_addr)&EX_only_csr_r)||((ID_to_csr_raddr==MEM_csr_addr)&MEM_only_csr_r)||((ID_to_csr_raddr==WB_csr_addr)&WB_only_csr_r));
assign inst_no_dest_reg = inst_st_w | inst_b | inst_beq | inst_bne|inst_st_b|inst_st_h;
assign block=((forward_priority[0]|| forward_priority[1] ) && EX_load);
wire [2:0]forward_priority;//EX is 1st MEM is sec WB is 3rd
wire [2:0]forward_priority_csr;
wire [2:0]forward_priority_rj;
wire [2:0]forward_priority_time;
assign forward_priority[0] = (rd == forwarding[110:106] & same_rd) || (rj == forwarding[110:106] & same_rj) || (rk == forwarding[110:106] & same_rk);
assign forward_priority[1] = (rd == forwarding[73:69]   & same_rd) || (rj == forwarding[73:69]   & same_rj) || (rk == forwarding[73:69]   & same_rk);
assign forward_priority[2] = (rd == forwarding[36:32]   & same_rd) || (rj == forwarding[36:32]   & same_rj) || (rk == forwarding[36:32]   & same_rk);
assign forward_priority_csr[0]=(ID_to_csr_raddr == EX_csr_addr)&same_csr_reg;
assign forward_priority_csr[1]=(ID_to_csr_raddr == MEM_csr_addr)&same_csr_reg;
assign forward_priority_csr[2]=(ID_to_csr_raddr == WB_csr_addr)&same_csr_reg;
assign forward_priority_time[0]=(14'h40 == EX_csr_addr);
assign forward_priority_time[1]=(14'h40 == MEM_csr_addr);
assign forward_priority_time[2]=(14'h40 == WB_csr_addr);
assign forward_priority_rj[0]=((rd == EX_dest_rj & same_time_rd)||(rj == EX_dest_rj & same_time_rj)||(rk == EX_dest_rj & same_time_rk))&EX_need_time_rj;
assign forward_priority_rj[1]=((rd == MEM_dest_rj & same_time_rd)||(rj == MEM_dest_rj & same_time_rj)||(rk == MEM_dest_rj & same_time_rk))&MEM_need_time_rj;
assign forward_priority_rj[2]=((rd == WB_dest_rj & same_time_rd)||(rj == WB_dest_rj & same_time_rj)||(rk == WB_dest_rj & same_time_rk))&WB_need_time_rj;
assign rj_value = same_rj ?   (forward_priority[0] && (rj == forwarding[110:106])? forwarding[105:74] :
                                            (forward_priority[1]  && (rj == forwarding[73:69])? forwarding[68:37]  : forwarding[31:0])):
                  same_time_rj? (forward_priority_rj[0] && (rj == EX_dest_rj)? EX_time_w_rj :
                                            (forward_priority_rj[1]  && (rj == MEM_dest_rj)? MEM_time_w_rj  : WB_time_w_rj)): rf_rdata1;
assign rkd_value = same_rd ? (forward_priority[0] && (rd == forwarding[110:106])? forwarding[105:74] :
                                          (forward_priority[1] && (rd == forwarding[73:69])? forwarding[68:37]  : forwarding[31:0])) : 
                   same_time_rd? (forward_priority_rj[0] && (rd == EX_dest_rj)? EX_time_w_rj :
                                          (forward_priority_rj[1]  && (rd == MEM_dest_rj)? MEM_time_w_rj  : WB_time_w_rj)):
                   same_rk ? (forward_priority[0] && (rk == forwarding[110:106])? forwarding[105:74] :
                                          (forward_priority[1] && (rk == forwarding[73:69])? forwarding[68:37]  : forwarding[31:0])) :
                   same_time_rk? (forward_priority_rj[0] && (rk == EX_dest_rj)? EX_time_w_rj :
                                          (forward_priority_rj[1]  && (rk == MEM_dest_rj)? MEM_time_w_rj  : WB_time_w_rj)):rf_rdata2;
assign final_csr_data=same_csr_reg?(forward_priority_csr[0]?EX_csr_data:
                                   (forward_priority_csr[1]?MEM_csr_data:WB_csr_data)
                                   ):csr_to_ID_rdata;
assign final_csr_tid=same_csr_tid?(forward_priority_time[0]?EX_csr_data:
                                   forward_priority_time[1]?MEM_csr_data:WB_csr_data
                                   ):time_tid;
assign i12  = ID_inst[21:10];
assign i20  = ID_inst[24: 5];
assign i16  = ID_inst[25:10];
assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_5_32 u_dec4(.in(op_9_5 ), .out(op_9_5_d ));
decoder_5_32 u_dec5(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec6(.in(rj  ), .out(rj_d  ));
decoder_5_32 u_dec7(.in(rk  ), .out(rk_d  ));

//指令译码
assign inst_rdtime_l_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h0]&op_19_15_d[5'h00]&rk_d[5'h18];
assign inst_rdtime_h_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h0]&op_19_15_d[5'h00]&rk_d[5'h19];
assign inst_rdtime_d=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h0]&op_19_15_d[5'h00]&rk_d[5'h1a];

assign inst_break=op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_ertn= op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk_d[5'h0e] & rj_d[5'h00] & rd_d[5'h00];
assign inst_syscall=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h2]&op_19_15_d[5'h16];

assign inst_csr_rd=op_31_26_d[6'h01]&~ID_inst[25]&~ID_inst[24]&op_9_5_d[5'h00];
assign inst_csr_wr=op_31_26_d[6'h01]&~ID_inst[25]&~ID_inst[24]&op_9_5_d[5'h01];
assign inst_csr_xchg=op_31_26_d[6'h01]&~ID_inst[25]&~ID_inst[24]& (~rj_d[5'h00] & ~rj_d[5'h01]);

assign inst_blt=op_31_26_d[6'h18];
assign inst_bge=op_31_26_d[6'h19];
assign inst_bltu=op_31_26_d[6'h1a];
assign inst_bgeu=op_31_26_d[6'h1b];
assign inst_ld_b=op_31_26_d[6'h0a]&op_25_22_d[4'h0];
assign inst_ld_h=op_31_26_d[6'h0a]&op_25_22_d[4'h1];
assign inst_ld_bu=op_31_26_d[6'h0a]&op_25_22_d[4'h8];
assign inst_ld_hu=op_31_26_d[6'h0a]&op_25_22_d[4'h9];
assign inst_st_b=op_31_26_d[6'h0a]&op_25_22_d[4'h4];
assign inst_st_h=op_31_26_d[6'h0a]&op_25_22_d[4'h5];

assign inst_pcaddu12i=op_31_26_d[6'h07]&&~ID_inst[25];
assign inst_slti=op_31_26_d[6'h00]&op_25_22_d[4'h8];
assign inst_sltui=op_31_26_d[6'h00]&op_25_22_d[4'h9];
assign inst_andi=op_31_26_d[6'h00]&op_25_22_d[4'hd];
assign inst_ori=op_31_26_d[6'h00]&op_25_22_d[4'he];
assign inst_xori=op_31_26_d[6'h00]&op_25_22_d[4'hf];
assign inst_sll_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h1]&op_19_15_d[5'h0e];
assign inst_sra_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h1]&op_19_15_d[5'h10];
assign inst_srl_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h1]&op_19_15_d[5'h0f];

assign inst_div_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h2]&op_19_15_d[5'h00];
assign inst_div_wu=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h2]&op_19_15_d[5'h02];
assign inst_mul_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h1]&op_19_15_d[5'h18];
assign inst_mulh_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h1]&op_19_15_d[5'h19];
assign inst_mulh_wu=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h1]&op_19_15_d[5'h1a];
assign inst_mod_w=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h2]&op_19_15_d[5'h01];
assign inst_mod_wu=op_31_26_d[6'h00]&op_25_22_d[4'h0]&op_21_20_d[2'h2]&op_19_15_d[5'h03];

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ID_inst[25];
assign to_EX_inst_bl = inst_bl;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl|inst_pcaddu12i|inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu|inst_st_b|inst_st_h;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt|inst_slti;
assign alu_op[ 3] = inst_sltu|inst_sltui;
assign alu_op[ 4] = inst_and|inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or|inst_ori;
assign alu_op[ 7] = inst_xor|inst_xori;
assign alu_op[ 8] = inst_slli_w|inst_sll_w;
assign alu_op[ 9] = inst_srli_w|inst_srl_w;
assign alu_op[10] = inst_srai_w|inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

assign op_div_w=inst_div_w;
assign op_div_wu=inst_div_wu;
assign op_mod_w=inst_mod_w;
assign op_mod_wu=inst_mod_wu;
assign op_mul_w=inst_mul_w;
assign op_mulh_w=inst_mulh_w;
assign op_mulh_wu=inst_mulh_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_ui12  =  inst_ori|inst_xori|inst_andi;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w|inst_slti|inst_sltui|inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu|inst_st_b|inst_st_h;
assign need_si16  =  inst_jirl | inst_beq | inst_bne|inst_blt|inst_bge|inst_bltu|inst_bgeu;
assign need_si20  =  inst_lu12i_w|inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;

assign src2_is_4  =  inst_jirl | inst_bl;
assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {{20'b0},i12[11:0]}             :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;
assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
 
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w|inst_st_b|inst_st_h|inst_blt|inst_bge|inst_bltu|inst_bgeu|inst_csr_rd|inst_csr_wr|inst_csr_xchg;
assign src_reg_is_rj = ~(inst_b | inst_bl | inst_lu12i_w|inst_pcaddu12i|inst_csr_rd|inst_csr_wr|inst_ertn);
assign src_reg_is_rk = ~(inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | 
                      inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w|inst_pcaddu12i|inst_slti|inst_sltui|inst_andi|inst_ori|inst_xori
                      |inst_blt|inst_bge|inst_bltu|inst_bgeu|inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu|inst_st_b|inst_st_h|
                      inst_csr_rd|inst_csr_wr|inst_csr_xchg|inst_ertn);
assign need_csr_reg=inst_csr_rd|inst_csr_wr|inst_csr_xchg;        
assign src1_is_pc    = inst_jirl | inst_bl|inst_pcaddu12i;
assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_ld_b   |
                       inst_ld_bu  |
                       inst_ld_h   |
                       inst_ld_hu  |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu12i|
                       inst_ori|
                       inst_slti|
                       inst_sltui|
                       inst_andi|
                       inst_xori;
 
assign res_from_mem_w  = inst_ld_w;
assign res_from_mem_b  = inst_ld_b;
assign res_from_mem_bu = inst_ld_bu;
assign res_from_mem_h  = inst_ld_h;
assign res_from_mem_hu = inst_ld_hu;

//使能信号等
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b&~inst_blt&~inst_bge&~inst_bltu&~inst_bgeu&~inst_st_b&~inst_st_h;
assign mem_we        = inst_st_w|inst_st_b|inst_st_h;
assign dest          = inst_no_dest_reg ? 5'b0 :
                                        dst_is_r1 ? 5'd1 : rd;
assign ID_csr_we=inst_csr_wr|inst_csr_xchg;
assign ID_csr_me=inst_csr_xchg;
assign ID_csr=inst_csr_rd|inst_csr_wr|inst_csr_xchg;
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
 
assign {rf_we, rf_waddr, rf_wdata} = WB_rf_bus;
assign {time_rj_we,time_rj_addr,time_rj_data}=WB_rf_bus0;
wire all_we;
assign all_we=(write_rj_state==write_rj_we) ? 1'b1:rf_we;
wire [4:0]all_waddr;
assign all_waddr=(write_rj_state==write_rj_we)?write_rj_bus[36:32]:rf_waddr;
wire [31:0]all_wdata;
assign all_wdata=(write_rj_state==write_rj_we)?write_rj_bus[31:0]:rf_wdata;
reg [1:0]write_rj_state;
reg block2;
reg [37:0] write_rj_bus;
localparam write_rj_idle=2'b00;
localparam write_rj_we=2'b11;
always @(posedge clk)begin
    if(reset || excp_flush || ertn_flush)begin
        write_rj_state <= write_rj_idle;
        write_rj_bus <=38'b0;
        block2 <= 1'b0;
    end
    else begin
    case(write_rj_state)
       write_rj_idle:begin
            if(rf_we && time_rj_we)begin
                block2 <=1'b1;
                write_rj_state <= write_rj_we;
                write_rj_bus <= WB_rf_bus0;
            end
       end
       write_rj_we:begin
           block2 <=1'b0;
           write_rj_state <= write_rj_idle;
           write_rj_bus <= 38'b0;
       end
    endcase
    end
end
regfile u_regfile(
    .clk    (clk      ),
    .reset  (reset    ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (all_we    ),
    .waddr  (all_waddr ),
    .wdata  (all_wdata )
    
    /*.we0(time_rj_we),
    .waddr0(time_rj_addr),
    .wdata0(time_rj_data)*/
    );
 
//发生例外信号
assign mem_type[2]=inst_ld_w|inst_st_w;
assign mem_type[1]=inst_ld_h|inst_ld_hu|inst_st_h;
assign mem_type[0]=inst_ld_b|inst_ld_bu|inst_st_b;

assign ID_excp =inst_break||inst_syscall||if_excp||has_int||excp_ine;
assign ID_excp_num={excp_ine,inst_break,inst_syscall,if_excp_num,has_int};
assign excp_ine=~(
                    inst_add_w|
                    inst_sub_w|
                    inst_slt|
                    inst_sltu|
                    inst_nor|
                    inst_and|
                    inst_or|
                    inst_xor|
                    inst_slli_w|
                    inst_srli_w|
                    inst_srai_w|
                    inst_addi_w|
                    inst_ld_w|
                    inst_st_w|
                    inst_jirl|
                    inst_b|
                    inst_bl|
                    inst_beq|
                    inst_bne|
                    inst_lu12i_w|
                    inst_pcaddu12i|
                    inst_slti|
                    inst_sltui|
                    inst_andi|
                    inst_ori|
                    inst_xori|
                    inst_sll_w|
                    inst_sra_w|
                    inst_srl_w|
                    inst_div_w|
                    inst_div_wu|
                    inst_mul_w|
                    inst_mulh_w|
                    inst_mulh_wu|
                    inst_mod_w|
                    inst_mod_wu|
                    inst_blt|
                    inst_bge|
                    inst_bltu|
                    inst_bgeu|
                    inst_ld_b|
                    inst_ld_h|
                    inst_ld_bu|
                    inst_ld_hu|
                    inst_st_b|
                    inst_st_h|
                    inst_csr_rd|
                    inst_csr_wr|
                    inst_csr_xchg|
                    inst_ertn|
                    inst_syscall|
                    inst_rdtime_l_w|
                    inst_rdtime_h_w|
                    inst_rdtime_d|
                    inst_break
                    );
//状态寄存器修改
assign ID_csr_waddr=ID_inst[23:10];
assign ID_to_csr_raddr=ID_inst[23:10];
//time
assign w_time={inst_rdtime_d,inst_rdtime_h_w,inst_rdtime_l_w,time_64,final_csr_tid};
assign time_rd=rd;
assign time_rj=rj;
assign ID_EX_bus = {
                    
                    time_rj,//328-332
                    time_rd,//323-327
                    w_time,//224-322
                    mem_type,//221-223
                    inst_ertn,//220
                    ID_excp_num,//215-219
                    ID_excp,//214
                    ID_csr,//213
                    ID_csr_waddr,//199-212
                    final_csr_data,//167-198
                    ID_csr_me,//166
                    ID_csr_we,//165
                    op_mod_wu,//164
                    op_mod_w,//163
                    op_div_wu,//162
                    op_div_w,//161
                    op_mulh_wu,//160
                    op_mulh_w,//159
                    op_mul_w,//158
                    ID_pc,//126-157
                    alu_op,//114-125
                    src2_is_4,//113
                    src1_is_pc,//112
                    src2_is_imm,//111
                    gr_we,//110
                    mem_we,//109
                    dest,//104-108
                    imm,//72-103
                    rj_value,//40-71
                    rkd_value,//8-39
                    res_from_mem_w,//7
                    res_from_mem_b,//6
                    res_from_mem_bu,//5
                    res_from_mem_h,//4
                    res_from_mem_hu,//3
                    inst_st_h,//2
                    inst_st_b,//1
                    inst_st_w//0
                    
};

//条件跳转
wire s_co_out;
wire u_co_out;
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;
assign adder_a   = rj_value;
assign adder_b   = ~rkd_value ;  //src1 - src2 rj-rk
assign adder_cin =  1'b1;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
assign s_co_out    = (rj_value[31] & ~rkd_value[31])
                        | ((rj_value[31] ~^ rkd_value[31]) & adder_result[31]);
assign u_co_out    = ~adder_cout;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                   || inst_blt &&  s_co_out
                   || inst_bge && (~s_co_out || rj_eq_rd)
                   || inst_bltu&& u_co_out
                   || inst_bgeu&& (~u_co_out||rj_eq_rd)
                  ) && ID_valid && !delay_slot && ~block;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b||inst_blt||inst_bge||inst_bltu||inst_bgeu) ? (ID_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
assign br_bus = {
                br_stall, //33
                br_taken,//32
                br_target //31:0
                };
assign br_stall = br_taken && EX_load && ID_valid;

//ID阶段信号定义
assign ID_ready_go    =~( block2 || time_rj_we) && (~ block||excp_flush);
assign ID_allow_in     = !ID_valid || ID_ready_go && EX_allow_in||excp_flush||ertn_flush;
assign ID_to_EX_valid = ID_valid && ID_ready_go && !delay_slot;
reg [1:0]slot_state;
localparam idle=2'b0;
localparam wait_if_to_id=2'b01;
localparam wait_id_valid=2'b10;
always @(posedge clk)begin
    if(reset || excp_flush ||ertn_flush)begin
        delay_slot <= 1'b0;
        slot_state <= idle;
    end
    case (slot_state)
    idle:begin
        delay_slot <=1'b0;
        if(br_taken && ~block)begin
            delay_slot <= 1'b1;
            slot_state <= wait_if_to_id;
        end
    end
    wait_if_to_id:begin
        if(IF_to_ID_valid)begin
            slot_state <= wait_id_valid;
        end
    end
    wait_id_valid:begin
        if(ID_valid)begin
            delay_slot <=1'b0;
            slot_state <=idle;
        end
    end
    endcase
end
always @(posedge clk) begin
    if (reset||excp_flush||ertn_flush) begin
        ID_valid <= 1'b0;
    end
    else if (ID_allow_in) begin
        ID_valid <= IF_to_ID_valid;
    end
 
    if (IF_to_ID_valid && ID_allow_in) begin
        {
        if_excp_num,
        if_excp,
        ID_pc,
        ID_inst} <= IF_ID_bus;
    end
end
 
 
endmodule