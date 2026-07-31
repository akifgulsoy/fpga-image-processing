`timescale 1ns/1ps
module tb_sobel_xy;
    logic clk_i = 1'b0, rst_ni = 1'b0, s_valid_i = 1'b0, s_ready_o;
    logic [7:0] s_top_left_i, s_top_mid_i, s_top_right_i, s_mid_left_i, s_mid_right_i;
    logic [7:0] s_bot_left_i, s_bot_mid_i, s_bot_right_i;
    logic m_valid_o, m_ready_i = 1'b1;
    logic signed [10:0] m_gx_o, m_gy_o;
    always #5 clk_i = ~clk_i;
    sobel_xy dut (.*);

    task automatic send_and_check(input integer gx, input integer gy);
        begin
            @(negedge clk_i); while (!s_ready_o) @(negedge clk_i);
            s_valid_i = 1'b1;
            @(negedge clk_i); s_valid_i = 1'b0;
            if (!m_valid_o || m_gx_o !== gx || m_gy_o !== gy)
                $fatal(1, "Unexpected Sobel result: got (%0d, %0d), expected (%0d, %0d)", m_gx_o, m_gy_o, gx, gy);
        end
    endtask

    initial begin
        s_top_left_i=0; s_top_mid_i=0; s_top_right_i=255;
        s_mid_left_i=0; s_mid_right_i=255;
        s_bot_left_i=0; s_bot_mid_i=0; s_bot_right_i=255;
        repeat (3) @(posedge clk_i); rst_ni = 1'b1;
        send_and_check(1020, 0);
        s_top_left_i=255; s_top_mid_i=255; s_top_right_i=255;
        s_mid_left_i=0; s_mid_right_i=0;
        s_bot_left_i=0; s_bot_mid_i=0; s_bot_right_i=0;
        send_and_check(0, -1020);
        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_top_left_i=255; s_top_mid_i=0; s_top_right_i=0;
        s_mid_left_i=255; s_mid_right_i=0;
        s_bot_left_i=255; s_bot_mid_i=0; s_bot_right_i=0;
        @(negedge clk_i); s_valid_i=1'b1;
        @(negedge clk_i); s_valid_i=1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_gx_o !== -1020 || m_gy_o !== 0 || s_ready_o)
                $fatal(1, "Sobel result or ready changed while stalled");
        end
        m_ready_i=1'b1; @(negedge clk_i);
        if (!s_ready_o) $fatal(1, "Input did not become ready after stall");
        $display("PASS: sobel_xy"); $finish;
    end
endmodule
