module square_wave_fourier #(
    parameter PHASE_WIDTH   = 16,
    parameter PHASE_STEP    = 256,   // tune fundamental frequency
    parameter MAX_HARMONICS = 7,     // odd harmonics: 1,3,5,7 supported by cases below
    parameter LUT_BITS      = 12,    // 4096-entry sine
    parameter LUT_SIZE      = (1 << LUT_BITS)
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

    // Pipeline arrays per harmonic
    reg [PHASE_WIDTH-1:0] phase_h_s1   [0:MAX_HARMONICS-1]; // Stage 1: phase*harmonic
    reg [LUT_BITS-1:0]    lut_addr_s2  [0:MAX_HARMONICS-1]; // Stage 2: LUT addr
    reg signed [8:0]      sine_val_s3  [0:MAX_HARMONICS-1]; // Stage 3: ROM data
    reg signed [15:0]     scaled_s4    [0:MAX_HARMONICS-1]; // Stage 4: scaled harmonic

    // Summation
    reg signed [31:0] sum_c_s5;   // combinational
    reg signed [31:0] sum_s5;     // registered

    // Normalize/clip
    reg signed [31:0] scaled_sum_s6;
    reg signed [31:0] recentered_s6;
    reg [7:0]         final_wave_s6;

    // Loop counters and temps
    integer i;
    integer j;
    integer n; // current harmonic number (odd: 1,3,5,7)

    // =========================================
    // Initialization
    // =========================================
    initial begin
        $readmemh("sine_lut.hex", sine_lut); // ensure tool includes as memory init file
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
    // Stage 1: phase multiply for odd harmonics (DSP-free)
    // Supports n = 1,3,5,7 via shift-add
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                phase_h_s1[i] <= {PHASE_WIDTH{1'b0}};
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
                n = (2*i) + 1;
                case (n)
                    1: phase_h_s1[i] <= phase;
                    3: phase_h_s1[i] <= phase + phase + phase;
                    5: phase_h_s1[i] <= (phase << 2) + phase;     // 4*phase + phase
                    7: phase_h_s1[i] <= (phase << 3) - phase;     // 8*phase - phase
                    default: phase_h_s1[i] <= phase;              // fallback
                endcase
            end
        end
    end

    // =========================================
    // Stage 2: LUT address (MSBs of phase_h)
    // Replace SystemVerilog -: with explicit range
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
    // Stage 3: synchronous ROM read (1-cycle latency)
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
    // Stage 4: scale by ~1/n (fixed-point shift approximations)
    // 1/3 ≈ 1/4 + 1/16, 1/5 ≈ 1/8 + 1/32, 1/7 ≈ 1/8 − 1/64
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1)
                scaled_s4[i] <= 16'sd0;
        end else begin
            for (i = 0; i < MAX_HARMONICS; i = i + 1) begin
                n = (2*i) + 1;
                case (n)
                    1: scaled_s4[i] <= sine_val_s3[i];                                   // 1
                    3: scaled_s4[i] <= (sine_val_s3[i] >>> 2) + (sine_val_s3[i] >>> 4);  // ~1/3
                    5: scaled_s4[i] <= (sine_val_s3[i] >>> 3) + (sine_val_s3[i] >>> 5);  // ~1/5
                    7: scaled_s4[i] <= (sine_val_s3[i] >>> 3) - (sine_val_s3[i] >>> 6);  // ~1/7
                    default: scaled_s4[i] <= sine_val_s3[i];
                endcase
            end
        end
    end

    // =========================================
    // Stage 5: combinational sum (then register)
    // =========================================
    always @* begin
        // Verilog-2001: acc declared at module scope is cleaner; here we inline via sum_c_s5
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
    // Stage 6: normalize, recenter, clip (binary output)
    // Keep conservative amplitude; adjust constants as needed
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scaled_sum_s6 <= 32'sd0;
            recentered_s6 <= 32'sd0;
            final_wave_s6 <= 8'd128;
        end else begin
            // ~*100/512 via arithmetic shift (avoids divider)
            scaled_sum_s6 <= (sum_s5 * 100) >>> 10;
            // DC offset (tune for your DAC mid-scale)
            recentered_s6 <= scaled_sum_s6 + 32'sd120;

            // Saturating clip to 8-bit unsigned
            if (recentered_s6 < 32'sd0)
                final_wave_s6 <= 8'd0;
            else if (recentered_s6 > 32'sd255)
                final_wave_s6 <= 8'd255;
            else
                final_wave_s6 <= recentered_s6[7:0];
        end
    end

    // =========================================
    // Stage 7: output register (binary for DAC/R–2R)
    // =========================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            wave_out <= 8'd0; // or 8'd128 for mid-level at reset
        else
            wave_out <= final_wave_s6;
    end

endmodule
