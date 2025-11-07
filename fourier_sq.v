module square_wave_fourier #(
    parameter PHASE_WIDTH   = 16,
    parameter PHASE_STEP    = 256,   // adjust for sampling resolution
    parameter MAX_HARMONICS = 1,     // odd harmonics: 1,3,5,...
    parameter LUT_BITS      = 12,    // 4096 entries
    parameter LUT_SIZE      = (1 << LUT_BITS),
    parameter DEBUG         = 0      // set to 1 to enable $display
)(
    input  wire clk,
    input  wire rst,
    output reg  [7:0] wave_out
);

    // === Fundamental Phase Accumulator ===
    reg [PHASE_WIDTH-1:0] phase;
    always @(posedge clk or posedge rst) begin
        if (rst)
            phase <= 0;
        else
            phase <= phase + PHASE_STEP;
    end

    // === Sine LUT (bipolar −256..+255) ===
    reg signed [8:0] sine_lut [0:LUT_SIZE-1];
    initial begin
        $readmemh("sine_lut_9bit.hex", sine_lut);  // must be regenerated with 4096 entries
    end

    // === Harmonic Summation ===
    reg signed [47:0] sum_all;
    integer i;
    integer n;

    reg [31:0] phase_wide;
    reg [PHASE_WIDTH-1:0] phase_n;
    reg signed [8:0] sine_n;
    reg signed [31:0] scaled_n;

    always @(*) begin
        sum_all = 0;
        for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
            n = 2 * i + 1;

            phase_wide = phase * n;
            phase_n    = phase_wide[PHASE_WIDTH-1:0];

            sine_n     = sine_lut[phase_n[PHASE_WIDTH-1 -: LUT_BITS]];

            // fractional scaling with rounding
            scaled_n   = (sine_n * 1024 + (n>>1)) / n;
            scaled_n   = scaled_n >>> 10;

            sum_all    = sum_all + scaled_n;
        end
    end

    // === Output Normalization ===
    // Softer scaling to avoid crest clipping
    wire signed [47:0] scaled_sum = (sum_all * 100) / 638; // ~1.065
    // Midpoint shift with extra headroom
    wire signed [47:0] recentered = scaled_sum + 48'sd120;

    // Saturating clip to 8-bit unsigned output
    wire [7:0] final_wave;
    assign final_wave = (recentered < 0)   ? 8'd0   :
                        (recentered > 255) ? 8'd255 : recentered[7:0];

    always @(posedge clk or posedge rst) begin
        if (rst)
            wave_out <= 8'd128;
        else
            wave_out <= final_wave;
    end


endmodule  