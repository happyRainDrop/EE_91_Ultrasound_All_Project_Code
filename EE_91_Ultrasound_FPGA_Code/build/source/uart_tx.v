module uart_tx (
	clk,
	rst,
	tx,
	busy,
	data,
	new_data
);
	parameter CLK_FREQ = 27'h5f5e100;
	parameter BAUD = 20'hf4240;
	input wire clk;
	input wire rst;
	output reg tx;
	output reg busy;
	input wire [7:0] data;
	input wire new_data;
	function automatic [27:0] sv2v_cast_57658;
		input reg [27:0] inp;
		sv2v_cast_57658 = inp;
	endfunction
	function automatic [28:0] sv2v_cast_338EA;
		input reg [28:0] inp;
		sv2v_cast_338EA = inp;
	endfunction
	localparam CLK_PER_BIT = sv2v_cast_338EA((sv2v_cast_57658(CLK_FREQ + BAUD) / BAUD) - 1'h1);
	localparam CTR_SIZE = $clog2(CLK_PER_BIT);
	localparam E_States_IDLE = 2'h0;
	localparam E_States_START_BIT = 2'h1;
	localparam E_States_DATA = 2'h2;
	localparam E_States_STOP_BIT = 2'h3;
	reg [1:0] D_state_d;
	reg [1:0] D_state_q = 2'h0;
	reg [CTR_SIZE - 1:0] D_ctr_d;
	reg [CTR_SIZE - 1:0] D_ctr_q = 0;
	reg [2:0] D_bit_ctr_d;
	reg [2:0] D_bit_ctr_q = 0;
	reg [7:0] D_saved_data_d;
	reg [7:0] D_saved_data_q = 0;
	reg D_tx_reg_d;
	reg D_tx_reg_q = 0;
	function automatic [(((CTR_SIZE > 1 ? CTR_SIZE : 1) + 0) >= 0 ? (CTR_SIZE > 1 ? CTR_SIZE : 1) + 1 : 1 - ((CTR_SIZE > 1 ? CTR_SIZE : 1) + 0)) - 1:0] sv2v_cast_A4548;
		input reg [(((CTR_SIZE > 1 ? CTR_SIZE : 1) + 0) >= 0 ? (CTR_SIZE > 1 ? CTR_SIZE : 1) + 1 : 1 - ((CTR_SIZE > 1 ? CTR_SIZE : 1) + 0)) - 1:0] inp;
		sv2v_cast_A4548 = inp;
	endfunction
	function automatic [29:0] sv2v_cast_D0F1C;
		input reg [29:0] inp;
		sv2v_cast_D0F1C = inp;
	endfunction
	function automatic [3:0] sv2v_cast_5891A;
		input reg [3:0] inp;
		sv2v_cast_5891A = inp;
	endfunction
	always @(*) begin
		D_tx_reg_d = D_tx_reg_q;
		D_bit_ctr_d = D_bit_ctr_q;
		D_ctr_d = D_ctr_q;
		D_saved_data_d = D_saved_data_q;
		D_state_d = D_state_q;
		tx = D_tx_reg_q;
		busy = 1'h1;
		case (D_state_q)
			2'h0: begin
				D_tx_reg_d = 1'h1;
				busy = 1'h0;
				D_bit_ctr_d = 1'h0;
				D_ctr_d = 1'h0;
				if (new_data) begin
					D_saved_data_d = data;
					D_state_d = 2'h1;
				end
			end
			2'h1: begin
				D_ctr_d = sv2v_cast_A4548(D_ctr_q + 1'h1);
				D_tx_reg_d = 1'h0;
				if (D_ctr_q == sv2v_cast_D0F1C(CLK_PER_BIT - 1'h1)) begin
					D_ctr_d = 1'h0;
					D_state_d = 2'h2;
				end
			end
			2'h2: begin
				D_tx_reg_d = D_saved_data_q[D_bit_ctr_q];
				D_ctr_d = sv2v_cast_A4548(D_ctr_q + 1'h1);
				if (D_ctr_q == sv2v_cast_D0F1C(CLK_PER_BIT - 1'h1)) begin
					D_ctr_d = 1'h0;
					D_bit_ctr_d = sv2v_cast_5891A(D_bit_ctr_q + 1'h1);
					if (D_bit_ctr_q == 3'h7)
						D_state_d = 2'h3;
				end
			end
			2'h3: begin
				D_tx_reg_d = 1'h1;
				D_ctr_d = sv2v_cast_A4548(D_ctr_q + 1'h1);
				if (D_ctr_q == sv2v_cast_D0F1C(CLK_PER_BIT - 1'h1))
					D_state_d = 2'h0;
			end
			default: D_state_d = 2'h0;
		endcase
	end
	always @(posedge clk)
		if (rst == 1'b1)
			D_state_q <= 2'h0;
		else
			D_state_q <= D_state_d;
	always @(posedge clk) begin
		D_ctr_q <= D_ctr_d;
		D_bit_ctr_q <= D_bit_ctr_d;
		D_saved_data_q <= D_saved_data_d;
		D_tx_reg_q <= D_tx_reg_d;
	end
endmodule
