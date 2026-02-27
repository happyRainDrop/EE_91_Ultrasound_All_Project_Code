module uart_rx (
	clk,
	rst,
	rx,
	data,
	new_data
);
	parameter CLK_FREQ = 27'h5f5e100;
	parameter BAUD = 20'hf4240;
	input wire clk;
	input wire rst;
	input wire rx;
	output reg [7:0] data;
	output reg new_data;
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
	localparam E_States_WAIT_HALF = 2'h1;
	localparam E_States_WAIT_FULL = 2'h2;
	localparam E_States_WAIT_HIGH = 2'h3;
	reg [1:0] D_state_d;
	reg [1:0] D_state_q = 0;
	reg [CTR_SIZE - 1:0] D_ctr_d;
	reg [CTR_SIZE - 1:0] D_ctr_q = 0;
	reg [2:0] D_bit_ctr_d;
	reg [2:0] D_bit_ctr_q = 0;
	reg [7:0] D_saved_data_d;
	reg [7:0] D_saved_data_q = 0;
	reg D_new_data_buffer_d;
	reg D_new_data_buffer_q = 0;
	reg [2:0] D_rxd_d;
	reg [2:0] D_rxd_q = 0;
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
		D_rxd_d = D_rxd_q;
		D_new_data_buffer_d = D_new_data_buffer_q;
		D_bit_ctr_d = D_bit_ctr_q;
		D_ctr_d = D_ctr_q;
		D_state_d = D_state_q;
		D_saved_data_d = D_saved_data_q;
		D_rxd_d = {D_rxd_q[1:1'h0], rx};
		D_new_data_buffer_d = 1'h0;
		data = D_saved_data_q;
		new_data = D_new_data_buffer_q;
		case (D_state_q)
			2'h0: begin
				D_bit_ctr_d = 1'h0;
				D_ctr_d = 1'h0;
				if (D_rxd_q[2] == 1'h0)
					D_state_d = 2'h1;
			end
			2'h1: begin
				D_ctr_d = sv2v_cast_A4548(D_ctr_q + 1'h1);
				if (D_ctr_q == (CLK_PER_BIT >> 1'h1)) begin
					D_ctr_d = 1'h0;
					D_state_d = 2'h2;
				end
			end
			2'h2: begin
				D_ctr_d = sv2v_cast_A4548(D_ctr_q + 1'h1);
				if (D_ctr_q == sv2v_cast_D0F1C(CLK_PER_BIT - 1'h1)) begin
					D_saved_data_d = {D_rxd_q[2], D_saved_data_q[3'h7:1'h1]};
					D_bit_ctr_d = sv2v_cast_5891A(D_bit_ctr_q + 1'h1);
					D_ctr_d = 1'h0;
					if (D_bit_ctr_q == 3'h7) begin
						D_state_d = 2'h3;
						D_new_data_buffer_d = 1'h1;
					end
				end
			end
			2'h3:
				if (D_rxd_q[2] == 1'h1)
					D_state_d = 2'h0;
			default: D_state_d = 2'h0;
		endcase
	end
	always @(posedge clk)
		if (rst == 1'b1)
			D_state_q <= 0;
		else
			D_state_q <= D_state_d;
	always @(posedge clk) begin
		D_ctr_q <= D_ctr_d;
		D_bit_ctr_q <= D_bit_ctr_d;
		D_saved_data_q <= D_saved_data_d;
		D_new_data_buffer_q <= D_new_data_buffer_d;
		D_rxd_q <= D_rxd_d;
	end
endmodule
