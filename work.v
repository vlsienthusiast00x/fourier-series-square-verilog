module square_wave_fourier #(
    parameter PHASE_WIDTH   = 16,
    parameter PHASE_STEP    = 256,   // tune fundamental frequency
    parameter MAX_HARMONICS = 50,    // odd harmonics up to 99
    parameter LUT_BITS      = 12,    // 4096-entry sine
    parameter LUT_SIZE      = (1 << LUT_BITS),
    parameter SCALE_Q       = 16     // fixed-point fractional bits for scaling
)(
    input  wire clk,
    input  wire rst,
    output reg  [7:0] wave_out
);

    // =========================================
    // Declarations 
    // =========================================
    reg [PHASE_WIDTH-1:0] phase;

    // Sine LUT (signed 9-bit, -256..+255)
    reg signed [8:0] sine_lut [0:LUT_SIZE-1];

    // Harmonic phase, LUT addr, sine value, scaled value
    reg [PHASE_WIDTH-1:0] phase_h_s1   [0:MAX_HARMONICS-1];
    reg [LUT_BITS-1:0]    lut_addr_s2  [0:MAX_HARMONICS-1];
    reg signed [8:0]      sine_val_s3  [0:MAX_HARMONICS-1];
    reg signed [31:0]     scaled_s4    [0:MAX_HARMONICS-1];

    // Scaling coefficients (fixed-point Q16)
    reg [31:0] scale_coeff [0:MAX_HARMONICS-1];

    // Summation
    reg signed [47:0] sum_c_s5;
    reg signed [47:0] sum_s5;

    // Normalize/clip
    reg signed [31:0] scaled_sum_s6;
    reg signed [31:0] recentered_s6;
    reg [7:0]         final_wave_s6;

    integer i;
    integer n;

    // =========================================
    // Initialization
    // =========================================
    initial begin
        $readmemh("sine_lut.hex", sine_lut);
        // Precompute scale coefficients: (4/pi)*(1/n) in Q16
        for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
            n = (2*i) + 1;
            scale_coeff[i] = (32'd262144 * 1273) / (n * 1000); 
            // crude approx: (4/pi) ≈ 1.273, scaled by 2^18 for Q16
        end
    end

    // =========================================
    // Stage 0: fundamental phase accumulator
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            phase <= {PHASE_WIDTH{1'b0}};
        else
            phase <= phase + PHASE_STEP;
    end

    // =========================================
    // Stage 1: phase multiply for odd harmonics
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                phase_h_s1[i] <= {PHASE_WIDTH{1'b0}};
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
                n = (2*i) + 1;
                phase_h_s1[i] <= phase * n;
            end
        end
    end

    // =========================================
    // Stage 2: LUT address
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                lut_addr_s2[i] <= {LUT_BITS{1'b0}};
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                lut_addr_s2[i] <= phase_h_s1[i][PHASE_WIDTH-1:PHASE_WIDTH-LUT_BITS];
        end
    end

    // =========================================
    // Stage 3: synchronous ROM read
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                sine_val_s3[i] <= 9'sd0;
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                sine_val_s3[i] <= sine_lut[lut_addr_s2[i]];
        end
    end

    // =========================================
    // Stage 4: scale by 1/n (using coeff table)
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                scaled_s4[i] <= 32'sd0;
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                scaled_s4[i] <= (sine_val_s3[i] * scale_coeff[i]) >>> SCALE_Q;
        end
    end

    // =========================================
    // Stage 5: combinational sum
    // =========================================
    always @* begin
        sum_c_s5 = 48'sd0;
        for (i = 0; i < MAX_HARMONICS; i = i + 1)
            sum_c_s5 = sum_c_s5 + scaled_s4[i];
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            sum_s5 <= 48'sd0;
        else
            sum_s5 <= sum_c_s5;
    end

    // =========================================
    // Stage 6: normalize, recenter, clip
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scaled_sum_s6 <= 32'sd0;
            recentered_s6 <= 32'sd0;
            final_wave_s6 <= 8'd128;
        end else begin
            scaled_sum_s6 <= sum_s5 >>> 8; // adjust gain
            recentered_s6 <= scaled_sum_s6 + 32'sd128;

            if (recentered_s6 < 32'sd0)
                final_wave_s6 <= 8'd0;
            else if (recentered_s6 > 32'sd255)
                final_wave_s6 <= 8'd255;
            else
                final_wave_s6 <= recentered_s6[7:0];
        end
    end

    // =========================================
    // Stage 7: output register
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            wave_out <= 8'd0;
        else
            wave_out <= final_wave_s6;
    end

endmodule
