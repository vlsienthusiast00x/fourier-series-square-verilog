`timescale 1ns / 1ps

module tb_fourier_sq;
    reg clk;
    reg rst;
    wire [7:0] wave_out;

    // Parameters via defparam or instance override if needed
    square_wave_fourier dut (
        .clk(clk),
        .rst(rst),
        .wave_out(wave_out)
    );
    defparam dut.PHASE_STEP = 256; // try 64, 128, 256, 512 to compare

    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    integer f;
    integer cycles;
    initial begin
        // Dumpfile setup for GTKWave or other viewers
        $dumpfile("tb_fourier_sq.vcd");   // name of VCD file
        $dumpvars(0, tb_fourier_sq);      // dump all signals in this module

        rst = 1;
        #50 rst = 0;

        // Open after reset deassertion
        f = $fopen("verilog_wave.txt", "w");

        // Capture a good window (e.g., 4000 samples)
        for (cycles = 0; cycles < 4000; cycles = cycles + 1) begin
            @(posedge clk);
            $fwrite(f, "%0d\n", wave_out);
        end

        $fclose(f);
        $finish;
    end
endmodule