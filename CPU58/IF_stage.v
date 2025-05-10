 
module IF_stage(
	input  clk,
	input  reset,
	input  ID_allow_in,
	input  [33:0] br_bus,
	
    output read_inst_req,
    output [2:0]read_inst_size,
    output [31:0]read_inst_addr,
    input  read_inst_addr_ok,
    input  read_inst_out_req,
    input  [31:0] read_inst,
    
    
	output [65:0] IF_ID_bus,
	output IF_to_ID_valid,
	
    //ÀýÍâ
    input excp_flush,
    input ertn_flush,
    input [31:0]excp_pc,
    input [31:0]ertn_pc
    );
wire br_stall;
wire br_taken;
wire [31:0] br_target;
wire [31:0] IF_inst;
reg  [31:0] IF_pc;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire pre_If_ready_go;
wire IF_ready_go;
wire IF_allow_in;
wire to_IF_valid;
wire IF_to_ID_valid;
reg  IF_valid;
//ÀýÍâ
reg  if_excp;
reg  if_excp_num;
wire excp;
wire excp_num;
wire pif_excp;
wire pif_excp_num;
wire excp_ADEF;
assign pre_If_ready_go = read_inst_addr_ok && (~br_stall||excp_flush||ertn_flush);
assign to_IF_valid = ~reset && pre_If_ready_go;
assign IF_ready_go = ~cancel_ertn&&~flush_ertn&&~flush_addr && ~cancel&& (read_inst_out_req || inst_buff_enable);
assign IF_allow_in = !IF_valid || IF_ready_go && ID_allow_in || flush_addr||flush_ertn;
assign IF_to_ID_valid =  IF_valid && IF_ready_go;   
assign IF_ID_bus = {
                    excp_num,//65
                    excp,//64
                    IF_pc,// 63
                    IF_inst
                    };
assign {br_stall,br_taken, br_target} = br_bus;
	always @(posedge clk) begin
	    if (reset||excp_flush||ertn_flush) begin
	        IF_valid <= 1'b0;
	        
	    end
	    else if (IF_allow_in) begin
	        IF_valid <= to_IF_valid;
	    end
	end
 
	always @(posedge clk) begin 
		if(reset) begin
			 IF_pc <= 32'h1bfffffc;
			 if_excp<=1'b0;
			 if_excp_num<=1'b0;
		end else if(to_IF_valid && (IF_allow_in))begin
			 IF_pc <= nextpc;
			 if_excp_num<=pif_excp_num;
			 if_excp<=pif_excp;
		end
	end
assign pif_excp_num=excp_ADEF;
assign pif_excp=nextpc[1]||nextpc[0];  
assign excp_ADEF=nextpc[1]||nextpc[0];
assign excp=if_excp;
assign excp_num=if_excp_num;         
assign seq_pc      = IF_pc + 3'h4;
assign nextpc       = flush_addr || cancel? excp_pc:
                      flush_ertn || cancel_ertn? ertn_pc:
                      ((br_bus_buffer_state==br_bus_buffer_wait)&&!excp_flush) ? br_bus_buffer :
                      seq_pc;

//Ìø×ªÑÓ³Ù²Û
reg [31:0]br_bus_buffer;
reg [1:0]br_bus_buffer_state;
localparam br_bus_buffer_empty=2'b00;
localparam br_bus_buffer_solt=2'b01;
localparam br_bus_buffer_wait=2'b10;
always @(posedge clk)begin
    if(reset || excp_flush || ertn_flush)begin
        br_bus_buffer_state <= br_bus_buffer_empty;
    end
    else case(br_bus_buffer_state) 
        br_bus_buffer_empty:begin
            if(br_taken && ~pre_If_ready_go && ~IF_valid  )begin
                br_bus_buffer <=br_target;
                br_bus_buffer_state <= br_bus_buffer_solt;
            end
            else if(br_taken && (pre_If_ready_go && ~IF_valid|| ~pre_If_ready_go && IF_valid))begin
                    br_bus_buffer_state <=br_bus_buffer_wait;
                 end
        end
        br_bus_buffer_solt:begin
            if(pre_If_ready_go)begin
                br_bus_buffer_state<= br_bus_buffer_wait;
            end
        end
        br_bus_buffer_wait:begin
            if(pre_If_ready_go)begin
                br_bus_buffer_state<=br_bus_buffer_empty;
            end
        end
    endcase
end
reg [31:0]inst_buff;
reg inst_buff_enable;
always @(posedge clk)begin
    if(reset || excp_flush || ertn_flush)begin
        inst_buff_enable <= 1'b0;
    end
    else begin
        if(IF_ready_go && ~ID_allow_in && IF_valid)begin
            inst_buff_enable <= 1'b1;
            inst_buff <= read_inst;
        end 
        else if(IF_ready_go && ID_allow_in)begin
            inst_buff_enable <= 1'b0;
        end
            
    end
end
reg [2:0]excp_ertn_state;
reg cancel;
reg cancel_ertn;
reg flush_ertn;
reg flush_addr;
localparam excp_ertn_idle=3'b000;
localparam excp_ertn_ready=3'b001;
localparam excp_ertn_data_ok=3'b010;
localparam excp_ertn_flush=3'b011;
localparam excp_ertn_flush_ing=3'b100;
localparam excp_ertn_flush_ertn=3'b101;
localparam excp_ertn_flush_ing_ertn=3'b110;
always @(posedge clk)begin
    if(reset)begin
        excp_ertn_state <= excp_ertn_idle;
        cancel <= 1'b0;
        cancel_ertn <=1'b0;
        flush_addr <= 1'b0;
        flush_ertn  <= 1'b0;
    end
    else begin
        case (excp_ertn_state)
            excp_ertn_idle:begin
                if(pre_If_ready_go)begin
                    if(excp_flush)begin
                        cancel <= 1'b1;
                        excp_ertn_state <= excp_ertn_data_ok;
                    end
                    else begin
                        cancel <= 1'b0;
                        excp_ertn_state <= excp_ertn_ready; 
                   end
                    if(ertn_flush)begin
                        cancel_ertn <= 1'b1;
                        excp_ertn_state <= excp_ertn_data_ok;
                    end
                    else begin
                        cancel_ertn <= 1'b0;
                        excp_ertn_state <= excp_ertn_ready; 
                   end
                end
                else begin
                    if(excp_flush)begin
                        flush_addr <= 1'b0;
                        excp_ertn_state <= excp_ertn_flush;
                    end
                    if(ertn_flush)begin
                        flush_ertn <= 1'b0;
                        excp_ertn_state <= excp_ertn_flush_ertn;
                    end
                end
            end
            excp_ertn_ready:begin
                if(excp_flush)begin
                    cancel <= 1'b1;
                    excp_ertn_state <= excp_ertn_data_ok;
                end
                else if(read_inst_out_req)begin
                    excp_ertn_state <= excp_ertn_idle;
                end
                if(ertn_flush)begin
                    cancel_ertn <= 1'b1;
                    excp_ertn_state <= excp_ertn_data_ok;
                end
                else if(read_inst_out_req)begin
                    excp_ertn_state <= excp_ertn_idle;
                end
            end
            excp_ertn_data_ok:begin
                if(pre_If_ready_go)begin
                    cancel_ertn <= 1'b0;
                    cancel <= 1'b0;
                    excp_ertn_state <= excp_ertn_idle;
                end
            end
            excp_ertn_flush:begin
                if(pre_If_ready_go)begin
                    flush_addr <= 1'b1;
                    excp_ertn_state <= excp_ertn_flush_ing;
                end
            end
            excp_ertn_flush_ing:begin
                if(pre_If_ready_go)begin
                    flush_addr <= 1'b0;
                    excp_ertn_state <= excp_ertn_idle;
                end
            end
            excp_ertn_flush_ertn:begin
                if(pre_If_ready_go)begin
                    flush_ertn <= 1'b1;
                    excp_ertn_state <= excp_ertn_flush_ing_ertn;
                end
            end
            excp_ertn_flush_ing_ertn:begin
                if(pre_If_ready_go)begin
                    flush_ertn <= 1'b0;
                    excp_ertn_state <= excp_ertn_idle;
                end
            end
        endcase
    end
end


assign read_inst_req =IF_allow_in && ~IF_valid;
assign IF_inst=inst_buff_enable ? inst_buff :read_inst;
assign read_inst_size=3'b010;
assign read_inst_addr =nextpc;
//assign inst_sram_en    = to_IF_valid && (IF_allow_in || br_stall);
//assign inst_sram_addr = nextpc;
//assign IF_inst = inst_sram_rdata;
//assign inst_sram_we = 4'b0;
//assign inst_sram_wdata = 32'b0;
 
endmodule