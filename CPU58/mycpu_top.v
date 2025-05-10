module core_top(
    input wire [7:0] intrpt,
    input  wire aclk,
    input  wire aresetn,
    //读请求
    output wire [3:0] arid,
    output wire [31:0] araddr,
    output wire [7:0] arlen,//0
    output wire [2:0] arsize,
    output wire [1:0] arburst,//0b01
    output wire [1:0] arlock,//0
    output wire [3:0] arcache,//0
    output wire [2:0] arprot,//0
    output wire arvalid,
    input  wire arready,
    //读响应            
    input  wire [3:0] rid,
    input  wire [31:0] rdata,
    input  wire [1:0] rresp,//
    input  wire rlast,//
    input  wire rvalid,
    output wire rready,
    //写请求           
    output wire [3:0] awid,//1
    output wire [31:0] awaddr,
    output wire [7:0] awlen,//0
    output wire [2:0] awsize,
    output wire [1:0] awburst,//0b01
    output wire [1:0] awlock,//0
    output wire [3:0] awcache,//0
    output wire [2:0] awprot,//0
    output wire awvalid,
    input  wire awready,
    //写数据请求
    output wire [3:0] wid,//1
    output wire [31:0] wdata,
    output wire [3:0] wstrb,
    output wire wlast,//1
    output wire wvalid,
    input  wire wready,
    //写响应
    input  wire [3:0] bid,//
    input  wire [1:0] bresp,//
    input  wire bvalid,
    output wire bready,

    input wire break_point,
    input wire infor_flag,
    input wire [4:0] reg_num,
    input wire ws_valid,
    input wire rf_rdata,
    
    /*input  wire        clk,
    input  wire        resetn,
   // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,*/
    // trace debug interface
    output wire [31:0] debug0_wb_pc,
    output wire [ 3:0] debug0_wb_rf_wen,
    output wire [ 4:0] debug0_wb_rf_wnum,
    output wire [31:0] debug0_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;
 
 
 
// allow_in
wire ID_allow_in;
wire EX_allow_in;
wire MEM_allow_in;
wire WB_allow_in;
//bus
wire [65:0]IF_ID_bus;
wire [332:0]ID_EX_bus;
wire [240:0]EX_MEM_bus;
wire [265:0]MEM_WB_bus;
wire [33:0]br_bus;
wire [37:0]WB_rf_bus;
wire [37:0]WB_rf_bus0;
//valid
wire IF_to_ID_valid;
wire ID_to_EX_valid;
wire EX_to_MEM_valid;
wire MEM_to_WB_valid;
//inst_bl
wire inst_bl;

//crs

wire [13:0]ID_to_csr_raddr;
wire [31:0]csr_to_ID_rdata;
wire WB_to_csr_we;
wire [13:0]WB_to_csr_waddr;
wire [31:0]WB_to_csr_wdata;

//64位计数
wire [63:0]time_64;
wire [31:0]time_tid;
//例外信号
wire  excp_flush;
wire  ertn_flush;
wire [5:0] csr_ecode;
wire [8:0] csr_esubcode;
wire [31:0]pc_to_era;
wire [31:0]excp_pc;
wire [31:0]ertn_pc;
wire no_we;//发生flush时终止写入
wire [1:0]crmd_plv;

wire error_badv;
wire [31:0] error_badv_pc;

//中断信号
wire has_int;

//block
wire EX_load;
wire [4:0]EX_dest;
wire [4:0]EX_dest_rj;
wire [31:0]EX_time_w_rj;
wire EX_need_time_rj;
wire [4:0]MEM_dest;
wire [4:0]MEM_dest_rj;
wire [31:0]MEM_time_w_rj;
wire MEM_need_time_rj;
wire [4:0]WB_dest;
wire [4:0]WB_dest_rj;
wire [31:0]WB_time_w_rj;
wire WB_need_time_rj;

wire [13:0]EX_csr_addr;
wire [31:0]EX_csr_data;
wire EX_only_csr_r;
wire [13:0]MEM_csr_addr;
wire [31:0]MEM_csr_data;
wire MEM_only_csr_r;
wire [13:0]WB_csr_addr;
wire [31:0]WB_csr_data;
wire WB_only_csr_r;

wire [36:0]EX_to_ID_reg_result;
wire [36:0]MEM_to_ID_reg_result;
wire [36:0]WB_to_ID_reg_result;
wire [110:0]forwarding;

assign forwarding = {EX_to_ID_reg_result,   //110:106EXreg
                                            //105:74EXdata
                     MEM_to_ID_reg_result,  //73:69MEMreg
                                            //68:37MEMdata
                     WB_to_ID_reg_result    //36:32WBreg
                                            //31:0 WBdata
                       };
                       
    wire read_inst_req;
    wire [2:0]read_inst_size;
    wire [31:0]read_inst_addr;
    wire  read_inst_addr_ok;
    wire  read_inst_out_req;
    wire  [31:0] read_inst;
    
    wire read_data_req1;
    wire read_data_req2;
    wire [2:0]read_data_size;
    wire [31:0]read_data_addr;
    wire  read_data_addr_ok;
    wire  read_data_out_req;
    wire  [31:0] read_data;
    
    
    wire write_req;
    wire [2:0]write_data_size;
    wire [3:0]write_data_wstrb;
    wire [31:0]write_data_addr;
    wire [31:0]write_data_data;
    wire  write_ok;
    wire write_addr_ok;
axi_inter axi(
    .clk(aclk),
    .reset(reset),
    
    .read_inst_req(read_inst_req),
    .read_inst_size(read_inst_size),
    .read_inst_addr(read_inst_addr),
    .read_inst_addr_ok(read_inst_addr_ok),
    .read_inst_out_req(read_inst_out_req),
    .read_inst(read_inst),
    
    .read_data_req(read_data_req2 || read_data_req1),
    .read_data_size(read_data_size),
    .read_data_addr(read_data_addr),
    .read_data_addr_ok(read_data_addr_ok),
    .read_data_out_req(read_data_out_req),
    .read_data(read_data),
    
    
    .write_req(write_req),
    .write_data_size(write_data_size),
    .write_data_wstrb(write_data_wstrb),
    .write_data_addr(write_data_addr),
    .write_data_data(write_data_data),
    .write_ok(write_ok),
    .write_addr_ok(write_addr_ok),
    
    .arid(arid),
	.araddr(araddr),
	.arlen(arlen),
	.arsize(arsize),
	.arburst(arburst),
	.arlock(arlock),
	.arcache(arcache),
	.arprot(arprot),
	.arvalid(arvalid),
	.arready(arready),

	//r           
	.rid(rid),
	.rdata(rdata),
	.rresp(rresp),
	.rlast(rlast),
	.rvalid(rvalid),
	.rready(rready),

	//aw          
	.awid(awid),
	.awaddr(awaddr),
	.awlen(awlen),
	.awsize(awsize),
	.awburst(awburst),
	.awlock(awlock),
	.awcache(awcache),
	.awprot(awprot),
	.awvalid(awvalid),
	.awready(awready),

	//w
	.wid(wid),
	.wdata(wdata),
	.wstrb(wstrb),
	.wlast(wlast),
	.wvalid(wvalid),
	.wready(wready),

	//b           
	.bid(bid),
	.bresp(bresp),
	.bvalid(bvalid),
	.bready(bready),
    
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush)
     );
/*IF_stage_tw IF2(
    .clk(aclk),
    .reset(reset),
    .ID_allow_in(ID_allow_in),
    .br_bus(br_bus),

    .read_inst_req(read_inst_req),
    .read_inst_size(read_inst_size),
    .read_inst_addr(read_inst_addr),
    .read_inst_addr_ok(read_inst_addr_ok),
    .read_inst_out_req(read_inst_out_req),
    .read_inst(read_inst),
    
    .IF_ID_bus(IF_ID_bus),
    .IF_to_ID_valid(IF_to_ID_valid),
    
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush),
    .excp_pc(excp_pc),
    .ertn_pc(ertn_pc)       
                
        );*/
IF_stage IF(
    .clk(aclk),
    .reset(reset),
    .ID_allow_in(ID_allow_in),
    .br_bus(br_bus),

    .read_inst_req(read_inst_req),
    .read_inst_size(read_inst_size),
    .read_inst_addr(read_inst_addr),
    .read_inst_addr_ok(read_inst_addr_ok),
    .read_inst_out_req(read_inst_out_req),
    .read_inst(read_inst),
    
    .IF_ID_bus(IF_ID_bus),
    .IF_to_ID_valid(IF_to_ID_valid),
    
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush),
    .excp_pc(excp_pc),
    .ertn_pc(ertn_pc)
    );
ID_stage ID(
   .clk(aclk),
   .reset(reset),
   .EX_allow_in(EX_allow_in),
   .IF_to_ID_valid(IF_to_ID_valid),
   .IF_ID_bus(IF_ID_bus),
   .WB_rf_bus(WB_rf_bus),
   .WB_rf_bus0(WB_rf_bus0),
   .ID_allow_in(ID_allow_in),
   .br_bus(br_bus),
   .ID_EX_bus(ID_EX_bus),
   .ID_to_EX_valid(ID_to_EX_valid),
   .to_EX_inst_bl(inst_bl),
   
   .EX_dest(EX_dest),
   .EX_dest_rj(EX_dest_rj),
   .EX_time_w_rj(EX_time_w_rj),
   .EX_need_time_rj(EX_need_time_rj),
   .MEM_dest(MEM_dest),
   .MEM_dest_rj(MEM_dest_rj),
   .MEM_time_w_rj(MEM_time_w_rj),
   .MEM_need_time_rj(MEM_need_time_rj),
   .WB_dest(WB_dest),
   .WB_dest_rj(WB_dest_rj),
   .WB_time_w_rj(WB_time_w_rj),
   .WB_need_time_rj(WB_need_time_rj),
   //前递
   .EX_load(EX_load),
   .forwarding(forwarding),
   
   .ID_to_csr_raddr(ID_to_csr_raddr),
   .csr_to_ID_rdata(csr_to_ID_rdata),
   
   .EX_csr_addr(EX_csr_addr),
   .MEM_csr_addr(MEM_csr_addr),
   .WB_csr_addr(WB_csr_addr),
   .EX_csr_data(EX_csr_data),
   .MEM_csr_data(MEM_csr_data),
   .WB_csr_data(WB_csr_data),
   .EX_only_csr_r(EX_only_csr_r),
   .MEM_only_csr_r(MEM_only_csr_r),
   .WB_only_csr_r(WB_only_csr_r),
   
   .time_64(time_64),
   .time_tid(time_tid),
   
   .has_int(has_int),
   
   .crmd_plv(crmd_plv),
   
   .excp_flush(excp_flush),
   .ertn_flush(ertn_flush)
    );
EX_stage EX(
    .clk(aclk),
    .reset(reset),
    .MEM_allow_in(MEM_allow_in),
    .ID_to_EX_valid(ID_to_EX_valid),
    .EX_allow_in(EX_allow_in),
    .ID_EX_bus(ID_EX_bus),
    .inst_bl(inst_bl),
    //.data_sram_rdata(data_sram_rdata),
    .EX_MEM_bus(EX_MEM_bus),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    
    .read_data_req(read_data_req1),
    .read_data_size(read_data_size),
    .read_data_addr(read_data_addr),
    .read_data_addr_ok(read_data_addr_ok),

    .write_req(write_req),
    .write_data_size(write_data_size),
    .write_data_wstrb(write_data_wstrb),
    .write_data_addr(write_data_addr),
    .write_data_data(write_data_data),
    .write_ok(write_ok),
    .write_addr_ok(write_addr_ok),
    
    .EX_dest_reg(EX_dest),
    
    .EX_dest_rj(EX_dest_rj),
    .EX_time_w_rj(EX_time_w_rj),
    .EX_need_time_rj(EX_need_time_rj),
    
    .EX_csr_addr(EX_csr_addr),
    .EX_csr_data(EX_csr_data),
    .EX_only_csr_r(EX_only_csr_r),
    
    .EX_load(EX_load),
    .EX_to_ID_reg_result(EX_to_ID_reg_result),
    
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush),
    .no_we(no_we)
);
MEM_stage MEM(
    .clk(aclk),
    .reset(reset),
    .WB_allow_in(WB_allow_in),
    .MEM_allow_in(MEM_allow_in),
    .EX_MEM_bus(EX_MEM_bus),
    
    .read_data_req(read_data_req2),
    .read_data_out_req(read_data_out_req),
    .read_data(read_data),
    
    .EX_to_MEM_valid(EX_to_MEM_valid),    
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .MEM_WB_bus(MEM_WB_bus),
    .MEM_dest_reg(MEM_dest),
    
    .MEM_dest_rj(MEM_dest_rj),
    .MEM_time_w_rj(MEM_time_w_rj),
    .MEM_need_time_rj(MEM_need_time_rj),
    
    .MEM_csr_addr(MEM_csr_addr),
    .MEM_csr_data(MEM_csr_data),
    .MEM_only_csr_r(MEM_only_csr_r),
    
    .MEM_to_ID_reg_result(MEM_to_ID_reg_result),
    
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush),
    .no_we(no_we)
    );
WB_stage WB(
    .clk(aclk),
    .reset(reset),
    .WB_allow_in(WB_allow_in),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .MEM_WB_bus(MEM_WB_bus),
    .WB_rf_bus(WB_rf_bus),
    .WB_rf_bus0(WB_rf_bus0),
    .debug_wb_pc(debug0_wb_pc) ,
    .debug_wb_rf_we(debug0_wb_rf_wen),
    .debug_wb_rf_wnum(debug0_wb_rf_wnum),
    .debug_wb_rf_wdata(debug0_wb_rf_wdata),
    .WB_dest_reg(WB_dest),
    
    .WB_dest_rj(WB_dest_rj),
    .WB_time_w_rj(WB_time_w_rj),
    .WB_need_time_rj(WB_need_time_rj),
    
    .WB_csr_addr(WB_csr_addr),
    .WB_csr_data(WB_csr_data),
    .WB_only_csr_r(WB_only_csr_r),
    
    .WB_to_ID_reg_result(WB_to_ID_reg_result),
    .WB_to_csr_we(WB_to_csr_we),
    .WB_to_csr_waddr(WB_to_csr_waddr),
    .WB_to_csr_wdata(WB_to_csr_wdata),
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush),
    .csr_ecode(csr_ecode),
    .csr_esubcode(csr_esubcode),
    .pc_to_era(pc_to_era),
    .error_badv(error_badv),
    .error_badv_pc(error_badv_pc)
    );
CSRH csr1(
    .clk(aclk),
    .reset(reset),
    .csr_raddr(ID_to_csr_raddr),
    .csr_rdata(csr_to_ID_rdata),
    .csr_we(WB_to_csr_we),
    .csr_waddr(WB_to_csr_waddr),
    .csr_wdata(WB_to_csr_wdata),
    
    .time_64(time_64),
    .time_tid(time_tid),
    
    .has_int(has_int),
    
    .excp_flush(excp_flush),
    .ertn_flush(ertn_flush),
    .ecode(csr_ecode),
    .esubcode(csr_esubcode),
    .era_pc(pc_to_era),
    .excp_pc(excp_pc),
    .ertn_pc(ertn_pc),
    
    .crmd_plv(crmd_plv),
    
    .error_badv_we(error_badv),
    .badv_wdata(error_badv_pc)
);

endmodule