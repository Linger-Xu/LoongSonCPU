`include "CSR.vh"
module CSRH(
    input clk,
    input reset,
    
    input [13:0] csr_raddr,
    output[31:0] csr_rdata,
    
    input csr_we,
    input [13:0] csr_waddr,
    input [31:0] csr_wdata,
    
    //64位计数
    output [63:0] time_64,    
    output [31:0] time_tid,
    //中断信号
    output has_int,
    
    //例外信号
    input excp_flush,
    input ertn_flush,
    input [5:0]ecode,
    input [8:0]esubcode,
    input [31:0]era_pc,
    output [31:0]excp_pc,
    output [31:0]ertn_pc,
    output [1:0]crmd_plv,
    input error_badv_we,
    input [31:0]badv_wdata
    );
localparam CRMD  = 14'h0;
localparam PRMD  = 14'h1;
localparam ECFG  = 14'h4;
localparam ESTAT = 14'h5;
localparam ERA   = 14'h6;
localparam BADV  = 14'h7;
localparam EENTRY = 14'hc;
localparam TLBIDX= 14'h10;
localparam TLBEHI= 14'h11;
localparam TLBELO0=14'h12;
localparam TLBELO1=14'h13;
localparam ASID  = 14'h18;
localparam PGDL  = 14'h19;
localparam PGDH  = 14'h1a;
localparam PGD   = 14'h1b;
localparam CPUID = 14'h20;
localparam SAVE0 = 14'h30;
localparam SAVE1 = 14'h31;
localparam SAVE2 = 14'h32;
localparam SAVE3 = 14'h33;
localparam TID   = 14'h40;
localparam TCFG  = 14'h41;
localparam TVAL  = 14'h42;
localparam CNTC  = 14'h43;
localparam TICLR = 14'h44;
localparam LLBCTL= 14'h60;
localparam TLBRENTRY = 14'h88;
localparam DMW0  = 14'h180;
localparam DMW1  = 14'h181;
localparam BRK = 14'h100;
localparam DISABLE_CACHE = 14'h101;

wire crmd_wen   = csr_we & (csr_waddr == CRMD);
wire prmd_wen   = csr_we & (csr_waddr == PRMD);

wire ecfg_wen   = csr_we & (csr_waddr == ECFG);
wire estat_wen  = csr_we & (csr_waddr == ESTAT);
wire era_wen    = csr_we & (csr_waddr == ERA);
wire badv_wen   = csr_we & (csr_waddr == BADV);
wire eentry_wen = csr_we & (csr_waddr == EENTRY);

wire save0_wen  = csr_we & (csr_waddr == SAVE0);
wire save1_wen  = csr_we & (csr_waddr == SAVE1);
wire save2_wen  = csr_we & (csr_waddr == SAVE2);
wire save3_wen  = csr_we & (csr_waddr == SAVE3);

wire tid_wen    =csr_we & (csr_waddr == TID);
wire tcfg_wen   =csr_we & (csr_waddr == TCFG);
wire tval_wen   =csr_we & (csr_waddr == TVAL);
wire ticlr_wen  =csr_we & (csr_waddr == TICLR);

reg [31:0]csr_crmd;
reg [31:0]csr_prmd;

reg [31:0]csr_ecfg;
reg [31:0]csr_estat;
reg [31:0]csr_era;
reg [31:0]csr_badv;
reg [31:0]csr_eentry;

reg [31:0]csr_save0;
reg [31:0]csr_save1;
reg [31:0]csr_save2;
reg [31:0]csr_save3;

reg [31:0]csr_tid;
reg [31:0]csr_tcfg;
reg [31:0]csr_tval;
reg [31:0]csr_ticlr;

reg [63:0] Stable_Counter;

reg timer_en;

//64位计数

assign time_64=Stable_Counter;
assign time_tid=csr_tid;
//例外
assign ertn_pc=csr_era;
assign excp_pc=csr_eentry;


assign crmd_plv=csr_crmd[`PLV];
//中断
assign has_int=((csr_ecfg[`LIE] & csr_estat[`IS])!=13'b0) & csr_crmd[`IE];


//read
assign csr_rdata=
                ({32{csr_raddr==CRMD}}   & csr_crmd|
                 {32{csr_raddr==PRMD}}   & csr_prmd|
                 {32{csr_raddr==ECFG}}   & csr_ecfg|
                 {32{csr_raddr==ESTAT}}  & csr_estat|
                 {32{csr_raddr== ERA}}   & csr_era|
                 {32{csr_raddr== BADV}}  & csr_badv|
                 {32{csr_raddr==EENTRY}} & csr_eentry|
                 {32{csr_raddr==SAVE0}}  & csr_save0|
                 {32{csr_raddr==SAVE1}}  & csr_save1|
                 {32{csr_raddr==SAVE2}}  & csr_save2|
                 {32{csr_raddr==SAVE3}}  & csr_save3|
                 {32{csr_raddr==TID}}    & csr_tid|
                 {32{csr_raddr==TCFG}}    & csr_tcfg|
                 {32{csr_raddr==TVAL}}  & csr_tval|
                 {32{csr_raddr==TICLR}}    & csr_ticlr
                );
//CRMD
always @(posedge clk) begin
    if (reset) begin
        csr_crmd[ `PLV] <=  2'b0;
        csr_crmd[  `IE] <=  1'b0;
        csr_crmd[  `DA] <=  1'b1;
        csr_crmd[  `PG] <=  1'b0;
        csr_crmd[`DATF] <=  2'b0;
        csr_crmd[`DATM] <=  2'b0;
        csr_crmd[31: 9] <= 23'b0;
    end
    else if (excp_flush) begin
        csr_crmd[ `PLV] <=  2'b0;
        csr_crmd[  `IE] <=  1'b0;
    end
    else if (ertn_flush)begin
        csr_crmd[`PLV] <=csr_prmd[`PPLV] ;
        csr_crmd[`IE ] <=csr_prmd[ `PIE] ;
    end
    else if (crmd_wen) begin
        csr_crmd[ `PLV] <= csr_wdata[ `PLV];
        csr_crmd[  `IE] <= csr_wdata[ `IE];
        csr_crmd[  `DA] <= csr_wdata[ `DA];
        csr_crmd[  `PG] <= csr_wdata[ `PG];
        csr_crmd[`DATF] <= csr_wdata[`DATF];
        csr_crmd[`DATM] <= csr_wdata[`DATM];
    end
end
//PRMD
always @(posedge clk) begin
    if (reset) begin
        csr_prmd[31:3] <= 29'b0;
    end
    else if (excp_flush)begin
        csr_prmd[`PPLV] <= csr_crmd[`PLV];
        csr_prmd[ `PIE] <= csr_crmd[`IE ];
    end
    else if (prmd_wen) begin
        csr_prmd[`PPLV] <= csr_wdata[`PPLV];
        csr_prmd[ `PIE] <= csr_wdata[ `PIE];
    end
end
//ECFG
always @(posedge clk) begin
    if (reset) begin
        csr_ecfg[31:0]<=32'b0;
    end
    else if (ecfg_wen) begin
       csr_ecfg[`LIE_1]<=csr_wdata[`LIE_1];
       csr_ecfg[`LIE_2]<=csr_wdata[`LIE_2];
    end
end
//ESTAT
always @(posedge clk) begin
    if (reset) begin
        csr_estat[ 1: 0] <= 2'b0;
        csr_estat[ 9: 2] <= 8'b0;
		csr_estat[10]    <= 1'b0;
		csr_estat[11] <= 1'b0;
		csr_estat[12]    <= 1'b0;
        csr_estat[15:13] <= 3'b0;
        csr_estat[30:16] <= 15'b0;
        csr_estat[31]    <= 1'b0;
        
        timer_en        <= 1'b0;
    end
    else begin 
        if (ticlr_wen && csr_wdata[`CLR]) begin
            csr_estat[11] <= 1'b0;
        end
        else if (tcfg_wen) begin
            timer_en <= csr_wdata[`EN];
        end
        else if (timer_en && (csr_tval == 32'b0)) begin
            csr_estat[11] <= 1'b1;
            timer_en      <= csr_tcfg[`PERIODIC];
        end
        if (excp_flush) begin
            csr_estat[   `ECODE] <= ecode;
            csr_estat[`ESUBCODE] <= esubcode;
        end
        else if (estat_wen) begin
                csr_estat[      1:0] <= csr_wdata[      1:0];
            end
    end
end
//ERA
always @(posedge clk) begin
    if (excp_flush) begin
        csr_era <= era_pc;
    end
    else if (era_wen) begin
        csr_era <= csr_wdata;
    end
end
//BADV
always @(posedge clk) begin
    if (badv_wen) begin
        csr_badv[31:0]<=csr_wdata[31:0];
    end
    if(error_badv_we)begin
        csr_badv[31:0]<=badv_wdata[31:0];
    end
end
//EENTRY
always @(posedge clk) begin
    if (reset) begin
        csr_eentry[31:0] <= 32'b0;
    end
    else if (eentry_wen) begin
        csr_eentry[31:6] <= csr_wdata[31:6];
    end
end

//save0
always @(posedge clk) begin
    if (reset) begin
        csr_save0[31:0] <= 32'b0;
    end
    else if (save0_wen) begin
        csr_save0 <= csr_wdata;
    end 
end

//save1
always @(posedge clk) begin
    if (reset) begin
        csr_save1[31:0] <= 32'b0;
    end
    else 
    if (save1_wen) begin
        csr_save1 <= csr_wdata;
    end 
end

//save2
always @(posedge clk) begin
    if (reset) begin
        csr_save2[31:0] <= 32'b0;
    end
    else 
    if (save2_wen) begin
        csr_save2 <= csr_wdata;
    end 
end

//save3
always @(posedge clk) begin
    if (reset) begin
        csr_save3[31:0] <= 32'b0;
    end
    else 
    if (save3_wen) begin
        csr_save3 <= csr_wdata;
    end 
end
//TID
always @(posedge clk) begin
    if (reset) begin
        csr_tid <= 32'b0;
    end
    else if (tid_wen) begin
        csr_tid <= csr_wdata;
    end
end
//TCFG
always @(posedge clk) begin
    if (reset) begin
        csr_tcfg[`EN] <= 1'b0;
    end
    else if (tcfg_wen) begin
        csr_tcfg[      `EN] <= csr_wdata[      `EN];
        csr_tcfg[`PERIODIC] <= csr_wdata[`PERIODIC];
        csr_tcfg[ `INITVAL] <= csr_wdata[ `INITVAL];
    end
end
//TVAL
always @(posedge clk) begin
    if (tcfg_wen) begin
        csr_tval <= {csr_wdata[ `INITVAL], 2'b0};
    end
    else if (timer_en) begin
        if (csr_tval != 32'b0) begin
            csr_tval <= csr_tval - 32'b1;
        end
        else if (csr_tval == 32'b0) begin
            csr_tval <= csr_tcfg[`PERIODIC] ? {csr_tcfg[`INITVAL], 2'b0} : 32'hffffffff;
        end
    end
end
//TICLR
always @(posedge clk) begin
    if (reset) begin
        csr_ticlr <= 32'b0;
    end
end
//Stable Counter
always @(posedge clk) begin
    if(reset)begin
        Stable_Counter <= 64'b0;
    end else begin
        if(Stable_Counter==64'hffffffffffffffff)begin
            Stable_Counter <= 64'b0;
        end else begin
            Stable_Counter <=Stable_Counter+1'b1;
        end
    end
end
endmodule
