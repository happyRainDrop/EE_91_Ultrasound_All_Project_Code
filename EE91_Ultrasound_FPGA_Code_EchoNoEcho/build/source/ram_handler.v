module ram_handler (
	clk,
	rst,
	adc_in,
	adc_clk_val,
	new_tx,
	tx_data,
	tx_busy,
	ramHandlerEn,
	ramDoneFlag
);
	parameter NUM_SAMPLES = 13'h1f40;
	parameter NUM_ADC_CHANNELS = 4'ha;
	input wire clk;
	input wire rst;
	input wire [NUM_ADC_CHANNELS - 1:0] adc_in;
	output reg adc_clk_val;
	output reg new_tx;
	output reg [7:0] tx_data;
	input wire tx_busy;
	input wire [1:0] ramHandlerEn;
	output reg ramDoneFlag;
	localparam EN_MODE_DISABLE = 1'h0;
	localparam EN_MODE_ADC = 1'h1;
	localparam EN_MODE_TRANSMIT = 2'h2;
	localparam EN_MODE_CLEAR = 2'h3;
	localparam E_RamHandler_States_IDLE = 2'h0;
	localparam E_RamHandler_States_CLEAR_MEM = 2'h1;
	localparam E_RamHandler_States_READ_ADC = 2'h2;
	localparam E_RamHandler_States_TRANSMIT_MEM = 2'h3;
	reg [1:0] D_ramhandler_state_d;
	reg [1:0] D_ramhandler_state_q = 0;
	localparam _MP_NUM_ADC_CHANNELS_406442986 = NUM_ADC_CHANNELS;
	reg M_my_adc_adc_en;
	reg [_MP_NUM_ADC_CHANNELS_406442986 - 1:0] M_my_adc_adc_din_vals;
	wire [_MP_NUM_ADC_CHANNELS_406442986 - 1:0] M_my_adc_adc_write_data;
	wire M_my_adc_adc_clk_out;
	wire M_my_adc_adc_write_en;
	adc #(.NUM_ADC_CHANNELS(_MP_NUM_ADC_CHANNELS_406442986)) my_adc(
		.clk(clk),
		.rst(rst),
		.adc_en(M_my_adc_adc_en),
		.adc_din_vals(M_my_adc_adc_din_vals),
		.adc_write_data(M_my_adc_adc_write_data),
		.adc_clk_out(M_my_adc_adc_clk_out),
		.adc_write_en(M_my_adc_adc_write_en)
	);
	reg [$clog2(NUM_SAMPLES) - 1:0] D_mem_location_idx_d;
	reg [$clog2(NUM_SAMPLES) - 1:0] D_mem_location_idx_q = 0;
	reg D_passedEchoThresh_d;
	reg D_passedEchoThresh_q = 0;
	localparam _MP_WIDTH_172199047 = 5'h10;
	localparam _MP_ENTRIES_172199047 = NUM_SAMPLES;
	reg [$clog2(_MP_ENTRIES_172199047) - 1:0] M_my_ram_address;
	wire [15:0] M_my_ram_read_data;
	reg [15:0] M_my_ram_write_data;
	reg M_my_ram_write_enable;
	simple_ram #(
		.WIDTH(_MP_WIDTH_172199047),
		.ENTRIES(_MP_ENTRIES_172199047)
	) my_ram(
		.clk(clk),
		.address(M_my_ram_address),
		.read_data(M_my_ram_read_data),
		.write_data(M_my_ram_write_data),
		.write_enable(M_my_ram_write_enable)
	);
	function automatic [13:0] sv2v_cast_3A5C4;
		input reg [13:0] inp;
		sv2v_cast_3A5C4 = inp;
	endfunction
	function automatic [((($clog2(NUM_SAMPLES) > 1 ? $clog2(NUM_SAMPLES) : 1) + 0) >= 0 ? ($clog2(NUM_SAMPLES) > 1 ? $clog2(NUM_SAMPLES) : 1) + 1 : 1 - (($clog2(NUM_SAMPLES) > 1 ? $clog2(NUM_SAMPLES) : 1) + 0)) - 1:0] sv2v_cast_66076;
		input reg [((($clog2(NUM_SAMPLES) > 1 ? $clog2(NUM_SAMPLES) : 1) + 0) >= 0 ? ($clog2(NUM_SAMPLES) > 1 ? $clog2(NUM_SAMPLES) : 1) + 1 : 1 - (($clog2(NUM_SAMPLES) > 1 ? $clog2(NUM_SAMPLES) : 1) + 0)) - 1:0] inp;
		sv2v_cast_66076 = inp;
	endfunction
	function automatic [(((16 > (6 + _MP_NUM_ADC_CHANNELS_406442986) ? 16 : 6 + _MP_NUM_ADC_CHANNELS_406442986) + 0) >= 0 ? (16 > (6 + _MP_NUM_ADC_CHANNELS_406442986) ? 16 : 6 + _MP_NUM_ADC_CHANNELS_406442986) + 1 : 1 - ((16 > (6 + _MP_NUM_ADC_CHANNELS_406442986) ? 16 : 6 + _MP_NUM_ADC_CHANNELS_406442986) + 0)) - 1:0] sv2v_cast_403E3;
		input reg [(((16 > (6 + _MP_NUM_ADC_CHANNELS_406442986) ? 16 : 6 + _MP_NUM_ADC_CHANNELS_406442986) + 0) >= 0 ? (16 > (6 + _MP_NUM_ADC_CHANNELS_406442986) ? 16 : 6 + _MP_NUM_ADC_CHANNELS_406442986) + 1 : 1 - ((16 > (6 + _MP_NUM_ADC_CHANNELS_406442986) ? 16 : 6 + _MP_NUM_ADC_CHANNELS_406442986) + 0)) - 1:0] inp;
		sv2v_cast_403E3 = inp;
	endfunction
	always @(*) begin
		D_ramhandler_state_d = D_ramhandler_state_q;
		D_passedEchoThresh_d = D_passedEchoThresh_q;
		D_mem_location_idx_d = D_mem_location_idx_q;
		M_my_ram_address = D_mem_location_idx_q;
		M_my_ram_write_data = 1'h0;
		M_my_ram_write_enable = 1'h0;
		new_tx = 1'h0;
		tx_data = 1'h0;
		ramDoneFlag = 1'h0;
		M_my_adc_adc_en = 1'h1;
		M_my_adc_adc_din_vals = adc_in;
		adc_clk_val = M_my_adc_adc_clk_out;
		D_ramhandler_state_d = D_ramhandler_state_q;
		D_passedEchoThresh_d = D_passedEchoThresh_q;
		D_mem_location_idx_d = D_mem_location_idx_q;
		if (rst) begin
			D_ramhandler_state_d = 2'h0;
			D_mem_location_idx_d = 1'h0;
			D_passedEchoThresh_d = 1'h0;
		end
		else
			case (D_ramhandler_state_q)
				2'h0: begin
					D_mem_location_idx_d = 1'h0;
					D_passedEchoThresh_d = 1'h0;
					M_my_adc_adc_en = 1'h0;
					ramDoneFlag = 1'h1;
					if (ramHandlerEn == 1'h1)
						D_ramhandler_state_d = 2'h2;
					else if (ramHandlerEn == 2'h3)
						D_ramhandler_state_d = 2'h1;
					else if (ramHandlerEn == 2'h2) begin
						D_ramhandler_state_d = 2'h3;
						D_mem_location_idx_d = 13'h1000;
					end
					else if (ramHandlerEn == 1'h0)
						D_ramhandler_state_d = 2'h0;
				end
				2'h1: begin
					M_my_adc_adc_en = 1'h1;
					M_my_ram_write_enable = M_my_adc_adc_write_en;
					M_my_ram_write_data = 1'h0;
					if (M_my_adc_adc_write_en) begin
						if (D_mem_location_idx_q < sv2v_cast_3A5C4(NUM_SAMPLES - 1'h1))
							D_mem_location_idx_d = sv2v_cast_66076(D_mem_location_idx_q + 1'h1);
						else begin
							D_mem_location_idx_d = 1'h0;
							D_ramhandler_state_d = 2'h0;
						end
					end
				end
				2'h2: begin
					M_my_adc_adc_en = 1'h1;
					M_my_ram_write_enable = M_my_adc_adc_write_en;
					if (M_my_adc_adc_write_en) begin
						M_my_ram_write_data = sv2v_cast_403E3(M_my_ram_read_data + {6'h00, M_my_adc_adc_write_data});
						if (D_mem_location_idx_q < sv2v_cast_3A5C4(NUM_SAMPLES - 1'h1))
							D_mem_location_idx_d = sv2v_cast_66076(D_mem_location_idx_q + 1'h1);
						else begin
							D_mem_location_idx_d = 1'h0;
							D_ramhandler_state_d = 2'h0;
						end
					end
				end
				2'h3: begin
					M_my_adc_adc_en = 1'h0;
					new_tx = 1'h0;
					if (M_my_ram_read_data[4'hf] == 1'h0)
						D_passedEchoThresh_d = 1'h1;
					if (D_mem_location_idx_q < sv2v_cast_3A5C4(NUM_SAMPLES - 1'h1))
						D_mem_location_idx_d = sv2v_cast_66076(D_mem_location_idx_q + 1'h1);
					else begin
						if (!tx_busy) begin
							tx_data = (D_passedEchoThresh_q ? 8'hff : 8'h00);
							new_tx = 1'h1;
						end
						D_passedEchoThresh_d = 1'h0;
						D_mem_location_idx_d = 1'h0;
						D_ramhandler_state_d = 2'h0;
					end
				end
			endcase
	end
	always @(posedge clk)
		if (rst == 1'b1)
			D_ramhandler_state_q <= 0;
		else
			D_ramhandler_state_q <= D_ramhandler_state_d;
	always @(posedge clk) begin
		D_mem_location_idx_q <= D_mem_location_idx_d;
		D_passedEchoThresh_q <= D_passedEchoThresh_d;
	end
endmodule
