module alchitry_top (
	clk,
	rst_n,
	trig_adc_read_pin,
	clear_mem_pin,
	adc_din,
	adc_out_pin,
	led,
	usb_rx,
	usb_tx
);
	input wire clk;
	input wire rst_n;
	input wire trig_adc_read_pin;
	input wire clear_mem_pin;
	input wire [9:0] adc_din;
	output reg [1:0] adc_out_pin;
	output reg [7:0] led;
	input wire usb_rx;
	output reg usb_tx;
	reg rst;
	localparam E_TopLevelStates_IDLE = 1'h0;
	localparam E_TopLevelStates_GET_PULSE = 1'h1;
	localparam E_RamHandler_States_IDLE = 2'h0;
	localparam E_RamHandler_States_CLEAR_MEM = 2'h1;
	localparam E_RamHandler_States_READ_ADC = 2'h2;
	localparam E_RamHandler_States_TRANSMIT_MEM = 2'h3;
	localparam EN_MODE_DISABLE = 1'h0;
	localparam EN_MODE_ADC = 1'h1;
	localparam EN_MODE_TRANSMIT = 2'h2;
	localparam EN_MODE_CLEAR = 2'h3;
	localparam _MP_STAGES_183869570 = 3'h4;
	reg M_reset_cond_in;
	wire M_reset_cond_out;
	reset_conditioner #(.STAGES(_MP_STAGES_183869570)) reset_cond(
		.clk(clk),
		.in(M_reset_cond_in),
		.out(M_reset_cond_out)
	);
	reg [0:0] D_toplevel_state_d;
	reg [0:0] D_toplevel_state_q = 0;
	reg D_trigger_pending_d;
	reg D_trigger_pending_q = 0;
	reg D_started_get_pulse_d;
	reg D_started_get_pulse_q = 0;
	reg [1:0] D_curr_ram_handler_en_state_d;
	reg [1:0] D_curr_ram_handler_en_state_q = 0;
	localparam _MP_CLK_FREQ_738674177 = 27'h5f5e100;
	localparam _MP_BAUD_738674177 = 20'hf4240;
	reg M_rx_rx;
	wire [7:0] M_rx_data;
	wire M_rx_new_data;
	uart_rx #(
		.CLK_FREQ(_MP_CLK_FREQ_738674177),
		.BAUD(_MP_BAUD_738674177)
	) rx(
		.clk(clk),
		.rst(rst),
		.rx(M_rx_rx),
		.data(M_rx_data),
		.new_data(M_rx_new_data)
	);
	localparam _MP_CLK_FREQ_1602448897 = 27'h5f5e100;
	localparam _MP_BAUD_1602448897 = 20'hf4240;
	wire M_tx_tx;
	wire M_tx_busy;
	reg [7:0] M_tx_data;
	reg M_tx_new_data;
	uart_tx #(
		.CLK_FREQ(_MP_CLK_FREQ_1602448897),
		.BAUD(_MP_BAUD_1602448897)
	) tx(
		.clk(clk),
		.rst(rst),
		.tx(M_tx_tx),
		.busy(M_tx_busy),
		.data(M_tx_data),
		.new_data(M_tx_new_data)
	);
	localparam _MP_NUM_SAMPLES_1127345720 = 13'h1f40;
	localparam _MP_NUM_ADC_CHANNELS_1127345720 = 4'ha;
	reg [9:0] M_readAndTransmitOnePulse_adc_in;
	wire M_readAndTransmitOnePulse_adc_clk_val;
	wire M_readAndTransmitOnePulse_new_tx;
	wire [7:0] M_readAndTransmitOnePulse_tx_data;
	reg M_readAndTransmitOnePulse_tx_busy;
	reg [1:0] M_readAndTransmitOnePulse_ramHandlerEn;
	wire M_readAndTransmitOnePulse_ramDoneFlag;
	ram_handler #(
		.NUM_SAMPLES(_MP_NUM_SAMPLES_1127345720),
		.NUM_ADC_CHANNELS(_MP_NUM_ADC_CHANNELS_1127345720)
	) readAndTransmitOnePulse(
		.clk(clk),
		.rst(rst),
		.adc_in(M_readAndTransmitOnePulse_adc_in),
		.adc_clk_val(M_readAndTransmitOnePulse_adc_clk_val),
		.new_tx(M_readAndTransmitOnePulse_new_tx),
		.tx_data(M_readAndTransmitOnePulse_tx_data),
		.tx_busy(M_readAndTransmitOnePulse_tx_busy),
		.ramHandlerEn(M_readAndTransmitOnePulse_ramHandlerEn),
		.ramDoneFlag(M_readAndTransmitOnePulse_ramDoneFlag)
	);
	always @(*) begin
		D_toplevel_state_d = D_toplevel_state_q;
		D_trigger_pending_d = D_trigger_pending_q;
		D_started_get_pulse_d = D_started_get_pulse_q;
		D_curr_ram_handler_en_state_d = D_curr_ram_handler_en_state_q;
		M_reset_cond_in = ~rst_n;
		rst = M_reset_cond_out;
		led = 8'h00;
		usb_tx = M_tx_tx;
		M_rx_rx = usb_rx;
		M_readAndTransmitOnePulse_ramHandlerEn = 1'h0;
		D_toplevel_state_d = D_toplevel_state_q;
		D_trigger_pending_d = D_trigger_pending_q;
		D_started_get_pulse_d = D_started_get_pulse_q;
		if (rst)
			D_toplevel_state_d = 1'h0;
		else
			case (D_toplevel_state_q)
				1'h0: begin
					M_readAndTransmitOnePulse_ramHandlerEn = 1'h0;
					D_started_get_pulse_d = 1'h0;
					if (D_trigger_pending_q == 1'h1) begin
						D_trigger_pending_d = 1'h0;
						D_curr_ram_handler_en_state_d = 2'h2;
						D_toplevel_state_d = 1'h1;
					end
					else if (trig_adc_read_pin) begin
						D_curr_ram_handler_en_state_d = 1'h1;
						D_toplevel_state_d = 1'h1;
					end
					else if (clear_mem_pin) begin
						D_curr_ram_handler_en_state_d = 2'h3;
						D_toplevel_state_d = 1'h1;
					end
				end
				1'h1: begin
					M_readAndTransmitOnePulse_ramHandlerEn = D_curr_ram_handler_en_state_q;
					if (D_started_get_pulse_q == 1'h0)
						D_started_get_pulse_d = 1'h1;
					else if (M_readAndTransmitOnePulse_ramDoneFlag) begin
						M_readAndTransmitOnePulse_ramHandlerEn = 1'h0;
						D_started_get_pulse_d = 1'h0;
						D_toplevel_state_d = 1'h0;
					end
				end
			endcase
		M_readAndTransmitOnePulse_adc_in = adc_din;
		adc_out_pin[1'h0] = M_readAndTransmitOnePulse_adc_clk_val;
		adc_out_pin[1'h1] = 1'h0;
		M_tx_new_data = M_readAndTransmitOnePulse_new_tx;
		M_tx_data = M_readAndTransmitOnePulse_tx_data;
		M_readAndTransmitOnePulse_tx_busy = M_tx_busy;
		if (M_rx_new_data)
			D_trigger_pending_d = 1'h1;
		led[1'h0] = D_trigger_pending_q;
		led[3'h7] = D_toplevel_state_q == 1'h1;
	end
	always @(posedge clk)
		if (rst == 1'b1) begin
			D_toplevel_state_q <= 0;
			D_trigger_pending_q <= 0;
			D_started_get_pulse_q <= 0;
			D_curr_ram_handler_en_state_q <= 0;
		end
		else begin
			D_toplevel_state_q <= D_toplevel_state_d;
			D_trigger_pending_q <= D_trigger_pending_d;
			D_started_get_pulse_q <= D_started_get_pulse_d;
			D_curr_ram_handler_en_state_q <= D_curr_ram_handler_en_state_d;
		end
endmodule
