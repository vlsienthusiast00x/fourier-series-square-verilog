module square_wave_fourier #(
    parameter PHASE_WIDTH   = 16,
    parameter PHASE_STEP    = 256,
    parameter MAX_HARMONICS = 5,
    parameter LUT_BITS      = 12,
    parameter LUT_SIZE      = (1 << LUT_BITS)
)(
    input  wire clk,
    input  wire rst,
    output reg  [7:0] wave_out
);

    // === Phase Accumulator ===
    reg [PHASE_WIDTH-1:0] phase;
    always @(posedge clk or posedge rst) begin
        if (rst)
            phase <= 0;
        else
            phase <= phase + PHASE_STEP;
    end

    // === Sine LUT (synchronous ROM) ===
    reg signed [8:0] sine_lut [0:LUT_SIZE-1];
    initial begin
        $readmemh("sine_lut.hex", sine_lut);
    end

    // === Harmonic Pipeline ===
    reg signed [15:0] scaled_harmonic [0:MAX_HARMONICS-1];
    reg [PHASE_WIDTH-1:0] phase_n [0:MAX_HARMONICS-1];
    reg [LUT_BITS-1:0] lut_addr [0:MAX_HARMONICS-1];
    reg signed [8:0] sine_val [0:MAX_HARMONICS-1];

    integer i;
    reg [3:0] n;

    always @(posedge clk) begin
        for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
            n = 2*i + 1;

            // Phase multiplication via shift-add
            if (n == 1)
                phase_n[i] <= phase;
            else if (n == 3)
                phase_n[i] <= phase + phase + phase;
            else if (n == 5)
                phase_n[i] <= (phase << 2) + phase;
            else if (n == 7)
                phase_n[i] <= (phase << 3) - phase;
            else
                phase_n[i] <= phase;

            // LUT address and read
            lut_addr[i] <= phase_n[i][PHASE_WIDTH-1 -: LUT_BITS];
            sine_val[i] <= sine_lut[lut_addr[i]];

            // Scale harmonic
            if (n == 1)
                scaled_harmonic[i] <= sine_val[i];
            else if (n == 3)
                scaled_harmonic[i] <= (sine_val[i] >>> 2) + (sine_val[i] >>> 4);
            else if (n == 5)
                scaled_harmonic[i] <= (sine_val[i] >>> 3) + (sine_val[i] >>> 5);
            else if (n == 7)
                scaled_harmonic[i] <= (sine_val[i] >>> 3) - (sine_val[i] >>> 6);
            else
                scaled_harmonic[i] <= sine_val[i];
        end
    end

    // === Registered Summation ===
    reg signed [31:0] sum_all;
    always @(posedge clk or posedge rst) begin
        if (rst)
            sum_all <= 0;
        else begin
            sum_all <= 0;
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                sum_all <= sum_all + scaled_harmonic[i];
        end
    end

    // === Normalize and Clip ===
    reg signed [31:0] scaled_sum;
    reg signed [31:0] recentered;
    reg [7:0] final_wave;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scaled_sum <= 0;
            recentered <= 0;
            final_wave <= 8'd128;
        end else begin
            scaled_sum <= (sum_all * 100) >>> 9;
            recentered <= scaled_sum + 32'sd120;

            if (recentered < 0)
                final_wave <= 8'd0;
            else if (recentered > 255)
                final_wave <= 8'd255;
            else
                final_wave <= recentered[7:0];
        end
    end

    // === Gray Encoding ===
    wire [7:0] gray;
    assign gray[7] = final_wave[7];
    assign gray[6] = final_wave[7] ^ final_wave[6];
    assign gray[5] = final_wave[6] ^ final_wave[5];
    assign gray[4] = final_wave[5] ^ final_wave[4];
    assign gray[3] = final_wave[4] ^ final_wave[3];
    assign gray[2] = final_wave[3] ^ final_wave[2];
    assign gray[1] = final_wave[2] ^ final_wave[1];
    assign gray[0] = final_wave[1] ^ final_wave[0];

    // === Output Register ===
    always @(posedge clk or posedge rst) begin
        if (rst)
            wave_out <= 8'd128;
        else
            wave_out <= gray;
    end

endmodule