

module BatchRoundRobinArbitrationLogic #(
    	parameter NUMBER_OF_USERS              = 4,
    	parameter USERS_BITS                   = 2,
    	parameter USER_LINE_IN_WIDTH           = 512,
    	parameter USER_LINE_OUT_WIDTH          = 512,
    	parameter BATCH_SIZE                   = 16
    )(
		input                         									clk,
		input                         									rst_n, 

		// Users TX Channel
    	input  wire   [USER_LINE_IN_WIDTH - 1 : 0]                      usr_tx_lines[NUMBER_OF_USERS-1:0],
    	input  wire   [NUMBER_OF_USERS-1 : 0]                           usr_tx_valid,
    	output wire   [NUMBER_OF_USERS-1 : 0]                           usr_tx_ready,
    	// TX Channel
    	output wire   [USER_LINE_IN_WIDTH-1:0]                          rr_tx_line,
    	output wire   [USERS_BITS-1:0]                                  rr_tx_tag,
    	output wire                                                     rr_tx_valid,
    	input  wire                                                     rr_tx_ready
	);


reg     [USERS_BITS-1:0]                  select;
wire    [USERS_BITS-1:0]                  selected_user;
reg     [USERS_BITS-1:0]                  batching_user;

reg     [31:0]                            curr_batching_user_count;
reg                                       batching_user_valid;

wire                                      select_curr_batching_user;

reg     [USERS_BITS-1:0]                  sh_pos;
wire    [USERS_BITS-1:0]                  pr_sh_in;
reg     [USERS_BITS-1:0]                  pr_reg[NUMBER_OF_USERS-1:0];

wire    [NUMBER_OF_USERS-1 : 0]           pr_sh_en;
wire    [NUMBER_OF_USERS-1 : 0]           prio;

wire                                      sh_enable;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
///////////////////////////////////////         Priority Multiplexer        /////////////////////////////////////////////
/////////////////////////////////////////////                           /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
genvar i;

generate for( i = 0; i < NUMBER_OF_USERS; i = i + 1) begin: selUsrLine
    assign usr_tx_ready[i] = rr_tx_ready & (selected_user == i);
end 
endgenerate

assign rr_tx_tag   = selected_user;
assign rr_tx_line  = usr_tx_lines[selected_user];
assign rr_tx_valid = (|usr_tx_valid);
///////////////////////// Multi input shift register (Priority Register) ////////////////////////////////////////////////
// priority register shift enables for each user slot
generate for( i = 0; i < NUMBER_OF_USERS; i=i+1) begin: PrShEn
	if(i < NUMBER_OF_USERS-1)
		assign pr_sh_en[i] = (sh_pos <= i);
	else
		assign pr_sh_en[i] = (sh_pos != NUMBER_OF_USERS-1);
end 
endgenerate

// priority register shift input
assign pr_sh_in     = pr_reg[sh_pos];
// priority register slots
generate for( i = 0; i < NUMBER_OF_USERS-1; i = i + 1) begin: PrReg
	always@(posedge clk) begin
		if(~ rst_n) begin 
			pr_reg[i] <= i;
		end 
		else if(sh_enable & pr_sh_en[i]) begin
			pr_reg[i] <= pr_reg[i+1];
		end 
	end 
end
endgenerate

always@(posedge clk) begin
	if(~ rst_n) begin 
		pr_reg[NUMBER_OF_USERS-1] <= NUMBER_OF_USERS-1;
	end 
	else if(sh_enable & pr_sh_en[NUMBER_OF_USERS-1]) begin
		pr_reg[NUMBER_OF_USERS-1] <= pr_sh_in;
	end 
end 

assign sh_enable                 = (|usr_tx_valid) & rr_tx_ready & ~select_curr_batching_user;

assign select_curr_batching_user = usr_tx_valid[batching_user] & batching_user_valid & (curr_batching_user_count < BATCH_SIZE);

always@(posedge clk) begin
	if(~rst_n) begin
		batching_user_valid      <= 0;
		batching_user            <= 0;
		curr_batching_user_count <= 0;
	end 
	else begin 
		if( sh_enable ) begin 
			batching_user_valid       <= 1'b1;
			curr_batching_user_count  <= 1;
			batching_user             <= select;
		end 
		else if(select_curr_batching_user & rr_tx_ready) begin 
			if( curr_batching_user_count == BATCH_SIZE-1 ) begin 
				batching_user_valid      <= 1'b0;
				curr_batching_user_count <= 0;
			end 
			else begin 
				curr_batching_user_count <= curr_batching_user_count + 1'b1;
			end
		end 
	end 
end 

assign selected_user = (sh_enable)? select : batching_user;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////  Mapping User Valid in to the current priority order ////////////////////////////
generate for( i = 0; i < NUMBER_OF_USERS; i = i + 1) begin: PRIO_b
	assign prio[i] = usr_tx_valid[ pr_reg[i] ];
end 
endgenerate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////// Priority Encoder /////////////////////////////////////////////////////////
integer j;

always @(*) begin
    select = 0; // default value 
    for ( j=NUMBER_OF_USERS-1; j>=0; j = j-1)
        if (prio[j]) select = pr_reg[j];
end

always @(*) begin
    sh_pos = 0; // default value 
    for ( j=NUMBER_OF_USERS-1; j>=0; j = j-1)
        if (prio[j]) sh_pos = j;
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


endmodule
