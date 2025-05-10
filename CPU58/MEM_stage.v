module MEM_stage(
    input  clk,
    input  reset,
    input  WB_allow_in,
    output MEM_allow_in,
    input  [240:0]EX_MEM_bus,
    //input  [31:0] data_sram_rdata,
    
    output read_data_req,
    input  read_data_out_req,
    input  [31:0] read_data,
    
    input  EX_to_MEM_valid, 
    output MEM_to_WB_valid,
    output [265:0]MEM_WB_bus,
    output [ 4:0]MEM_dest_reg,
    
    output [ 4:0] MEM_dest_rj,
    output [31:0] MEM_time_w_rj,
    output MEM_need_time_rj,
    
    output [13:0]MEM_csr_addr,
    output [31:0]MEM_csr_data,
    output MEM_only_csr_r,
    
    output [36:0]MEM_to_ID_reg_result,
    
    input excp_flush,
    input ertn_flush,
    output no_we
    );
reg [98:0]w_time;
reg [4:0] time_rj;
reg [4:0] time_rd;
wire [31:0] mem_error_addr;
wire [5:0] MEM_excp_num;
wire MEM_excp;
reg MEM_ertn;
reg [5:0]EX_excp_num;
reg EX_excp;
reg [31:0] MEM_csr_wdata;
reg [13:0] MEM_csr_waddr;
reg MEM_csr_we;
reg [1:0] MEM_adder;
reg [31:0] MEM_pc;
reg MEM_res_from_mem_w;
reg MEM_res_from_mem_b;
reg MEM_res_from_mem_bu;
reg MEM_res_from_mem_h;
reg MEM_res_from_mem_hu;
reg MEM_gr_we;
reg [4:0]MEM_dest;
reg [31:0]MEM_alu_result;
wire [31:0] MEM_final_result;
wire [31:0] MEM_result;
 
reg MEM_valid;
wire MEM_ready_go;

assign MEM_mem_req=is_ld && MEM_valid;

assign MEM_dest_rj=time_rj&{5{MEM_valid}};
assign MEM_need_time_rj=w_time[98:96]!=3'b000;
assign MEM_time_w_rj=w_time[96]?w_time[31:0]:
                        w_time[97]?w_time[31:0]:
                        w_time[95:64];
assign read_data_req=is_ld && MEM_valid;
assign no_we=(MEM_excp||MEM_ertn) && MEM_valid;
assign MEM_ready_go    = read_data_out_req&&is_ld || ~is_ld;
assign MEM_allow_in     = !MEM_valid || MEM_ready_go && WB_allow_in;
assign MEM_to_WB_valid = MEM_valid && MEM_ready_go;
assign MEM_dest_reg = MEM_dest & {5{MEM_valid}};
assign MEM_csr_addr=MEM_csr_waddr&{14{MEM_valid}};
assign MEM_csr_data=MEM_csr_wdata;
assign MEM_only_csr_r=MEM_csr_we;
always @(posedge clk) begin
    if (reset||excp_flush||ertn_flush) begin
        MEM_valid <= 1'b0;
    end
    else if (MEM_allow_in) begin
        MEM_valid <= EX_to_MEM_valid;
    end
 
    if (EX_to_MEM_valid && MEM_allow_in) begin
        {
        
        time_rj,//236-240
        time_rd,//231-235
        w_time,//132-230
        MEM_ertn,//131
        EX_excp_num,
        EX_excp,
        MEM_csr_wdata,
        MEM_csr_waddr,
        MEM_csr_we,
        MEM_adder,//76
        MEM_pc ,
        MEM_gr_we ,
        MEM_dest,
        MEM_alu_result,
        MEM_res_from_mem_w,
        MEM_res_from_mem_b,
        MEM_res_from_mem_bu,
        MEM_res_from_mem_h,
        MEM_res_from_mem_hu } <= EX_MEM_bus;
    end
end

assign MEM_result = read_data;
assign mem_error_addr=MEM_alu_result;
reg [31:0]MEM_ld_result;
wire is_ld;
assign is_ld=MEM_res_from_mem_w|
        MEM_res_from_mem_b|
        MEM_res_from_mem_bu|
        MEM_res_from_mem_h|
        MEM_res_from_mem_hu;
        
always @(*)begin
        if(is_ld)begin
            if(MEM_res_from_mem_b)begin
                case(MEM_adder)
                    2'b00: MEM_ld_result={{24{MEM_result[7]}},MEM_result[7:0]};
                    2'b01: MEM_ld_result={{24{MEM_result[15]}},MEM_result[15:8]};
                    2'b10: MEM_ld_result={{24{MEM_result[23]}},MEM_result[23:16]};
                    2'b11: MEM_ld_result={{24{MEM_result[31]}},MEM_result[31:24]};
                    default: ;
                endcase
            end
            if(MEM_res_from_mem_bu)begin
                case(MEM_adder)
                    2'b00: MEM_ld_result={24'b0,MEM_result[7:0]};
                    2'b01: MEM_ld_result={24'b0,MEM_result[15:8]};
                    2'b10: MEM_ld_result={24'b0,MEM_result[23:16]};
                    2'b11: MEM_ld_result={24'b0,MEM_result[31:24]};
                    default: ;
                endcase
            end
            if(MEM_res_from_mem_hu)begin
                case(MEM_adder)
                    2'b00: MEM_ld_result={24'b0,MEM_result[15:0]};
                    2'b10: MEM_ld_result={24'b0,MEM_result[31:16]};
                    default: ;
                endcase
            end
            if(MEM_res_from_mem_h)begin
                case(MEM_adder)
                    2'b00: MEM_ld_result={{24{MEM_result[15]}},MEM_result[15:0]};
                    2'b10: MEM_ld_result={{24{MEM_result[31]}},MEM_result[31:16]};
                    default: ;
                endcase
            end
            if(MEM_res_from_mem_w)begin
                MEM_ld_result=MEM_result;
            end
        end
        else begin
            MEM_ld_result=MEM_alu_result;
        end
end

assign MEM_final_result=MEM_ld_result;

assign MEM_excp_num=EX_excp_num;
assign MEM_excp=EX_excp;
assign MEM_WB_bus = {   
                        
                        
                        time_rj,//261-265
                        time_rd,//256-260
                        w_time,//157-255
                        mem_error_addr,//125-156
                        MEM_ertn,//124
                        MEM_excp_num,//118-123
                        MEM_excp,//117
                        MEM_csr_wdata,//85-116
                        MEM_csr_waddr,//71-84
                        MEM_csr_we,//70
                        MEM_pc,//69
                        MEM_gr_we,
                        MEM_dest,
                        MEM_final_result
};
assign MEM_to_ID_reg_result={
                            MEM_dest,
                            MEM_final_result
                            };
endmodule