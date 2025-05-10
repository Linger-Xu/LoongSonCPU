
module axi_inter(
    input clk,
    input reset,
    
    input read_inst_req,
    input [2:0]read_inst_size,
    input [31:0]read_inst_addr,
    output reg read_inst_addr_ok,
    output reg read_inst_out_req,
    output reg [31:0] read_inst,
    
    input read_data_req,
    input [2:0]read_data_size,
    input [31:0]read_data_addr,
    output reg read_data_addr_ok,
    output reg read_data_out_req,
    output reg [31:0] read_data,
    
    
    input write_req,
    input [2:0]write_data_size,
    input [3:0]write_data_wstrb,
    input [31:0]write_data_addr,
    input [31:0]write_data_data,
    output reg write_ok,
    output reg write_addr_ok,
    
    output reg[3:0]    		arid,
	output reg[31:0] 		araddr,
	output [7 :0] 		arlen,
	output reg[2 :0] 		arsize,
	output [1 :0] 		arburst,
	output [1 :0]    		arlock,
	output [3 :0] 		arcache,
	output [2 :0]			arprot,
	output reg				arvalid,
	input					arready,

	//r           
	input  [3 :0] 			rid,
	input  [31:0] 			rdata,
	input  [1 :0] 			rresp,
	input         			rlast,
	input         			rvalid,
	output reg    			rready,

	//aw          
	output [3 :0]    		awid,
	output reg[31:0] 		awaddr,
	output [7 :0] 		awlen,
	output reg[2 :0] 		awsize,
	output [1 :0] 		awburst,
	output [1 :0]    		awlock,
	output [3 :0] 		awcache,
	output [2 :0]    		awprot,
	output reg       		awvalid,
	input            		awready,

	//w
	output [3 :0]    		wid,
	output reg[31:0] 		wdata,
	output reg[3 :0] 		wstrb,
	output      		    wlast,
	output reg       		wvalid,
	input            		wready,

	//b           
	input  [3 :0] 			bid,
	input  [1 :0] 			bresp,
	input         			bvalid,
	output reg       			bready,
    
    input excp_flush,
    input ertn_flush
    );
    
    
    
assign arlen=8'b0;
assign arburst=2'b01;
assign arlock=2'b0;
assign arcache=4'b0;
assign arprot=3'b0;
assign awid=4'b1;
assign awlen=8'b0;
assign awburst=2'b01;
assign awlock=2'b0;
assign awcache=4'b0;
assign awprot=3'b0;
assign wid=4'b1;
assign wlast=1'b1;     
    
    
reg [2:0]read_state;
reg [2:0]rnext_state;
reg [2:0]write_state;
reg [2:0]wnext_state;
localparam AXI_idel=3'b000;
localparam READ_ARREADY=3'b001;
localparam READ_RVALID=3'b010;
localparam WRITE_AWREADY=3'b011;
localparam WRITE_WREADY=3'b100;
localparam WRITE_BVALID=3'b101;
always @(posedge clk)begin
    if(reset)begin
        read_state <= AXI_idel;
        write_state <= AXI_idel;
    end
    else begin
        read_state <= rnext_state;
        write_state <= wnext_state;
    end
end
//read
always @(*)begin
    if(reset)begin
        rnext_state <= AXI_idel;
        wnext_state <= AXI_idel; 
    end
    else begin
        case(read_state)
            AXI_idel:begin
                if(read_data_req||read_inst_req)begin
                     rnext_state <= READ_ARREADY;
                end
                else begin
                     rnext_state <= AXI_idel;
                end
            end
            READ_ARREADY:begin
                if(arready)begin
                    rnext_state <= READ_RVALID;
                end else begin
                        rnext_state <= READ_ARREADY;
                    end
            end
            READ_RVALID:begin
                if(~rvalid && ~rready && (read_inst_out_req||read_data_out_req))begin
                    rnext_state <= AXI_idel;
                end else begin
                    rnext_state <= READ_RVALID;
                    end
            end
            default:begin rnext_state <= AXI_idel;end
        endcase
        case (write_state)
            AXI_idel:begin
                if(write_req)begin
                    wnext_state <= WRITE_AWREADY;
                end
                else wnext_state <= AXI_idel;
            end
            WRITE_AWREADY:begin
                if(awready)begin
                    wnext_state <= WRITE_WREADY;
                end else wnext_state <= WRITE_AWREADY;
            end
            WRITE_WREADY:begin
                if(wready)begin
                    wnext_state <= WRITE_BVALID;
                end else wnext_state <= WRITE_WREADY;
            end
            WRITE_BVALID:begin
                if(bvalid)begin
                    wnext_state <= AXI_idel;
                end else wnext_state <= WRITE_BVALID;
            end
            default:begin wnext_state<=AXI_idel;end
        endcase
    end
end
//action
always @(posedge clk)begin
    if(reset)begin
    arid <= 4'b0;
    araddr <= 32'b0;
    arsize <= 3'b0;
    arvalid <= 1'b0;
    read_inst_addr_ok <=1'b0;
    read_inst_out_req <=1'b0;
    read_data_addr_ok <=1'b0;
    read_data_out_req <=1'b0;
    
    rready <= 1'b0;
    
    awaddr <= 32'b0;
    awsize <= 3'b0;
    awvalid <= 1'b0;
    
    wdata <= 32'b0;
    wvalid <= 1'b0;
    
    
    bready <= 1'b0;
    write_ok <=1'b0;
    write_addr_ok <= 1'b0;
    end
    else begin
        case(read_state)
            AXI_idel:begin
            read_data_addr_ok <= 1'b0;
            read_data_out_req <= 1'b0;
            read_inst_out_req <= 1'b0;
            read_inst_addr_ok <= 1'b0;
                if(read_data_req)begin
                    rready <=1'b0;
                    read_data <= 32'b0;
                    read_data_out_req <= 1'b0;
                    read_data_addr_ok <= 1'b0;
                    
                    arid <= 4'b1;
                    araddr <= read_data_addr;
                    arsize <= read_data_size;
                    arvalid <= 1'b1;
                end
                else begin
                     if(read_inst_req)begin
                        rready <=1'b0;
                        read_inst <= 32'b0;
                        read_inst_out_req <= 1'b0;
                        read_inst_addr_ok <= 1'b0;
                        
                        arid <= 4'b0;
                        araddr <= read_inst_addr;
                        arsize <= read_inst_size;
                        arvalid <= 1'b1;
                    end
                end
            end
            READ_ARREADY:begin
                if(arready)begin
                    if(read_data_req)begin
                        read_data_addr_ok <=1'b1;
                    end
                    else if(read_inst_req)begin
                            read_inst_addr_ok <= 1'b1;
                         end
                    araddr <= 32'b0;
                    arvalid <= 1'b0;
                    rready <= 1'b1;
                end
            end
            READ_RVALID:begin
             read_inst_addr_ok <=1'b0;
             read_data_addr_ok <=1'b0;
                if(rvalid)begin
                    if(rid==4'b1) begin
                        read_data <= rdata;
                        read_data_out_req <= 1'b1;
                        rready <= 1'b0;
                    end
                    else begin
                        if(rid==4'b0 )begin
                            read_inst <= rdata;
                            read_inst_out_req <= 1'b1;
                            rready <= 1'b0;
                        end
                    end
                end
            end
            default:begin end
        endcase
        case(write_state)
            AXI_idel:begin
                bready <= 1'b0;
                write_ok <= 1'b0;
                write_addr_ok <= 1'b0;
                if(write_req)begin
                    awvalid <=1'b1;
                    wvalid <= 1'b0;
                    bready <= 1'b0;
                    write_ok <= 1'b0;
                    write_addr_ok <= 1'b0;
                    
                    awaddr <= write_data_addr;
                    awsize <= write_data_size;
                end
            end
            WRITE_AWREADY:begin
                if(awready)begin
                   awvalid <=1'b0;
                   wvalid <= 1'b1;
                   write_addr_ok <= 1'b1;
                   
                   wdata <=write_data_data;
                   wstrb <= write_data_wstrb;
                end
            end
            WRITE_WREADY:begin
                if(wready)begin
                    bready <= 1'b1;
                    wvalid <=1'b0;
                end
            end
            WRITE_BVALID:begin
                if(bvalid)begin
                    awaddr=32'b0;
                    write_ok <=1'b1;
                end
            end
            default:begin end
        endcase    
    end
end
endmodule
