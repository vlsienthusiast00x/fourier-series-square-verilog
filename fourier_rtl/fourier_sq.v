module square_wave_fourier #(
    parameter PHASE_WIDTH   = 16,
    parameter PHASE_STEP    = 256,    // fundamental phase step
    parameter LUT_BITS      = 12,     // 4096-entry sine
    parameter LUT_SIZE      = (1 << LUT_BITS),
    parameter MAX_HARMONICS = 8       // odd harmonics: 1..15
)(
    input  wire clk,
    input  wire rst,
    output reg  [7:0] wave_out
);

    // =========================================
    // Declarations
    // =========================================
    reg [PHASE_WIDTH-1:0] phase0;

    reg [PHASE_WIDTH-1:0] phase_h_s1   [0:MAX_HARMONICS-1];
    reg [PHASE_WIDTH-1:0] step_h       [0:MAX_HARMONICS-1];
    reg                   harm_en      [0:MAX_HARMONICS-1]; // auto Nyquist gating

    reg  signed [8:0] sine_lut [0:LUT_SIZE-1];

    reg [LUT_BITS-1:0]    lut_addr_s2  [0:MAX_HARMONICS-1];
    reg signed [8:0]      sine_val_s3  [0:MAX_HARMONICS-1];
    reg signed [15:0]     scaled_s4    [0:MAX_HARMONICS-1];

    reg signed [31:0] sum_c_s5;
    reg signed [31:0] sum_s5;
    reg signed [31:0] scaled_sum_s6;
    reg signed [31:0] recentered_s6;
    reg [7:0]         final_wave_s6;

    integer i;
    integer j;
    integer n;

    // =========================================
    // Initialization
    // =========================================
    initial begin
        $readmemh("sine_lut.hex", sine_lut);
    end

    // Precompute step_h and harmonic enable with Nyquist guard:
    // n*PHASE_STEP < 2^(PHASE_WIDTH-1)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
                n = (2*i) + 1;
                // shift-add n*PHASE_STEP
                case (n)
                    1:  step_h[i] <= PHASE_STEP;
                    3:  step_h[i] <= PHASE_STEP + PHASE_STEP + PHASE_STEP;
                    5:  step_h[i] <= (PHASE_STEP << 2) + PHASE_STEP;
                    7:  step_h[i] <= (PHASE_STEP << 3) - PHASE_STEP;
                    9:  step_h[i] <= (PHASE_STEP << 3) + PHASE_STEP;
                    11: step_h[i] <= (PHASE_STEP << 3) + (PHASE_STEP << 1) + PHASE_STEP;
                    13: step_h[i] <= (PHASE_STEP << 3) + (PHASE_STEP << 2) + PHASE_STEP;
                    15: step_h[i] <= (PHASE_STEP << 4) - PHASE_STEP;
                    default: step_h[i] <= PHASE_STEP;
                endcase
                // Nyquist enable
                harm_en[i] <= (step_h[i] < (1 << (PHASE_WIDTH-1)));
            end
        end
    end

    // =========================================
    // Stage 0: fundamental phase accumulator
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            phase0 <= {PHASE_WIDTH{1'b0}};
        else
            phase0 <= phase0 + PHASE_STEP;
    end

    // =========================================
    // Stage 1: per-harmonic phase accumulators (gated)
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                phase_h_s1[i] <= {PHASE_WIDTH{1'b0}};
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                phase_h_s1[i] <= harm_en[i] ? (phase_h_s1[i] + step_h[i]) : phase_h_s1[i];
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
    // Stage 3: ROM read
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                sine_val_s3[i] <= 9'sd0;
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                sine_val_s3[i] <= harm_en[i] ? sine_lut[lut_addr_s2[i]] : 9'sd0;
        end
    end

    // =========================================
    // Stage 4: ~1/n scaling (shift-add)
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                scaled_s4[i] <= 16'sd0;
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
                if (!harm_en[i]) begin
                    scaled_s4[i] <= 16'sd0;
                end else begin
                    n = (2*i) + 1;
                    case (n)
                        1:  scaled_s4[i] <= sine_val_s3[i];
                        3:  scaled_s4[i] <= (sine_val_s3[i] >>> 2) + (sine_val_s3[i] >>> 4);
                        5:  scaled_s4[i] <= (sine_val_s3[i] >>> 3) + (sine_val_s3[i] >>> 5);
                        7:  scaled_s4[i] <= (sine_val_s3[i] >>> 3) - (sine_val_s3[i] >>> 6);
                        9:  scaled_s4[i] <= (sine_val_s3[i] >>> 3) - (sine_val_s3[i] >>> 6) + (sine_val_s3[i] >>> 9);
                        11: scaled_s4[i] <= (sine_val_s3[i] >>> 4) + (sine_val_s3[i] >>> 5) - (sine_val_s3[i] >>> 8);
                        13: scaled_s4[i] <= (sine_val_s3[i] >>> 4) + (sine_val_s3[i] >>> 6) - (sine_val_s3[i] >>> 9);
                        15: scaled_s4[i] <= (sine_val_s3[i] >>> 4) + (sine_val_s3[i] >>> 8);
                        default: scaled_s4[i] <= sine_val_s3[i];
                    endcase
                end
            end
        end
    end

    // =========================================
    // Stage 5: sum
    // =========================================
    always @* begin
        sum_c_s5 = 32'sd0;
        for (j = 0; j < MAX_HARMONICS; j = j + 1)
            sum_c_s5 = sum_c_s5 + scaled_s4[j];
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            sum_s5 <= 32'sd0;
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
            scaled_sum_s6 <= (sum_s5 * 32'sd64) >>> 8; // conservative gain
            recentered_s6 <= scaled_sum_s6 + 32'sd128; // mid-scale
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
            wave_out <= 8'd128;
        else
            wave_out <= final_wave_s6;
    end

endmodule
