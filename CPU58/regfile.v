module regfile(
    input  wire        clk,
    input  wire        reset,
    // READ PORT 1
    input  wire [ 4:0] raddr1,
    output wire [31:0] rdata1,
    // READ PORT 2
    input  wire [ 4:0] raddr2,
    output wire [31:0] rdata2,
    // WRITE PORT
    input  wire        we,       //write enable, HIGH valid
    input  wire [ 4:0] waddr,
    input  wire [31:0] wdata
    
    /*input wire we0,
    input  wire [ 4:0] waddr0,
    input  wire [31:0] wdata0*/
);

reg [31: 0] rf[0: 31];

always @(posedge clk) begin
    if (we) rf[waddr] <= wdata;
end

/*always @(posedge clk) begin
    if (we0) rf[waddr0] <= wdata0;
end*/
assign rdata1 = (raddr1==5'b0) ? 32'b0 : rf[raddr1];

assign rdata2 = (raddr2==5'b0) ? 32'b0 : rf[raddr2];

endmodule
