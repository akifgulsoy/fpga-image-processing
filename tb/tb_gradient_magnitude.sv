`timescale 1ns/1ps
module tb_gradient_magnitude;
    logic clk_i = 1'b0, rst_ni = 1'b0, s_valid_i = 1'b0, s_ready_o;
    logic signed [10:0] s_gx_i, s_gy_i;
    logic m_valid_o, m_ready_i = 1'b1;
    logic [10:0] m_magnitude_o;
    always #5 clk_i = ~clk_i;
    gradient_magnitude dut (.*);

    task automatic send_and_check(input integer gx, input integer gy, input integer magnitude);
        begin
            @(negedge clk_i); while (!s_ready_o) @(negedge clk_i);
            s_gx_i = gx; s_gy_i = gy; s_valid_i = 1'b1;
            @(negedge clk_i); s_valid_i = 1'b0;
            if (!m_valid_o || m_magnitude_o !== magnitude)
                $fatal(1, "Unexpected magnitude: got %0d, expected %0d", m_magnitude_o, magnitude);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i); rst_ni = 1'b1;
        send_and_check(1020, 0, 1020);
        send_and_check(-300, 200, 500);
        @(negedge clk_i); m_ready_i = 1'b0;
        s_gx_i = -1020; s_gy_i = 510; s_valid_i = 1'b1;
        @(negedge clk_i); s_valid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_magnitude_o !== 1530 || s_ready_o)
                $fatal(1, "Magnitude result or ready changed while stalled");
        end
        m_ready_i = 1'b1; @(negedge clk_i);
        if (!s_ready_o) $fatal(1, "Input did not become ready after stall");
        $display("PASS: gradient_magnitude"); $finish;
    end
endmodule
