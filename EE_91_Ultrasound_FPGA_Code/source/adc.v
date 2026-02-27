// ADC module
// Generates ADC clock (50 MHz)
// Within each ADC clock cycle:
// First clock cycle (ADC clock HIGH): Write to RAM prev val
// Second clock cycle (ADC clock LOW): Read ADC

module adc #(
    parameter NUM_ADC_CHANNELS = 10
)(
    input  wire                        clk,          // 100 MHz
    input  wire                        rst,
    
    input  wire                        adc_en,        // LOW for disable
    input  wire [NUM_ADC_CHANNELS-1:0] adc_din_vals,
    output reg  [NUM_ADC_CHANNELS-1:0] adc_write_data,
    output reg                         adc_clk_out,   // 50 MHz
    output reg                         adc_write_en
);

    always @(posedge clk) begin
        if (rst | ~adc_en) begin
            adc_clk_out    <= 1'b0;
            adc_write_en   <= 1'b0;
            adc_write_data <= {NUM_ADC_CHANNELS{1'b0}};
        end else begin

            // Toggle ADC clock (divide by 2 --> 50 MHz)
            adc_clk_out <= ~adc_clk_out;

            // Default
            adc_write_en <= 1'b0;

            // When ADC clock is LOW, sample ADC inputs
            if (!adc_clk_out) begin
                adc_write_data <= adc_din_vals;
            end

            // When ADC clock is HIGH, assert write enable
            if (adc_clk_out) begin
                adc_write_en <= 1'b1;
            end
        end
    end

endmodule
