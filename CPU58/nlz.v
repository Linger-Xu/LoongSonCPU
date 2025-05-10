module nlz(
    input  wire [ 15:0] in,
    output wire [ 4:0] out
);
reg [15:0] src;
reg [4:0] n;

always @(posedge clk)
begin
    src<=in;
    if(src==0)
    begin
        n<=1;
    end
    else begin
        if((src>>8)==0)
            begin
                n<=n+8;
                src<=src<<8;
            end
        if((src>>12)==0)
            begin
                n<=n+4;
                src<=src<<4;
            end
        if((src>>14)==0)
            begin
                n<=n+2;
                src<=src<<2;
            end
        n<=n-(src>>15);
    end
end
assign out=n;


endmodule



