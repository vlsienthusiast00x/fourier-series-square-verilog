`timescale 1ns / 1ps

module tb_fourier_sq;
    reg clk;
    reg rst;
    wire [7:0] wave_out;

    // DUT instantiation
    square_wave_fourier dut (
        .clk(clk),
        .rst(rst),
        .wave_out(wave_out)
    );
    defparam dut.PHASE_STEP = 256; // try 64, 128, 256, 512 to compare

    // Clock generation: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // File handle for dumping wave_out values
    integer fd;
    integer cycles;

    initial begin
        // VCD dump for GTKWave
        $dumpfile("tb_fourier_sq.vcd");
        $dumpvars(0, tb_fourier_sq);

        // Open text file for Python analysis
        fd = $fopen("verilog_wave.txt", "w");
        if (fd == 0) begin
            $display("ERROR: Could not open verilog_wave.txt");
            $finish;
        end

        // Reset sequence
        rst = 1;
        #50 rst = 0;

        // Run for N cycles and log output
        for (cycles = 0; cycles < 2000; cycles = cycles + 1) begin
            @(posedge clk);
            $fwrite(fd, "%0d\n", wave_out);
        end

        $fclose(fd);
        $finish;
    end
endmodule