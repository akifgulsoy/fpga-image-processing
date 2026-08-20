`timescale 1ns/1ps

module tb_pixel_stream_frame_metadata_single_pixel;
    logic clk_i = 1'b0, rst_ni = 1'b0, s_valid_i = 1'b0, s_ready_o;
    logic [7:0] s_pixel_i = '0;
    logic m_valid_o, m_ready_i = 1'b1;
    logic [7:0] m_pixel_o;
    logic m_sol_o, m_eol_o, m_sof_o, m_eof_o;

    always #5 clk_i = ~clk_i;

    pixel_stream_frame_metadata #(.LINE_PIXELS(1), .FRAME_LINES(1)) dut (.*);

    task automatic send_and_check(input logic [7:0] pixel);
        begin
            @(negedge clk_i); while (!s_ready_o) @(negedge clk_i);
            s_pixel_i = pixel; s_valid_i = 1'b1;
            @(negedge clk_i); s_valid_i = 1'b0;
            if (!m_valid_o || m_pixel_o !== pixel || !m_sol_o || !m_eol_o ||
                !m_sof_o || !m_eof_o)
                $fatal(1, "Single-pixel frame markers did not match pixel %0d", pixel);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk_i); rst_ni = 1'b1;
        send_and_check(8'd10);

        @(negedge clk_i); m_ready_i = 1'b0; s_pixel_i = 8'd11; s_valid_i = 1'b1;
        @(negedge clk_i); s_valid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_pixel_o !== 8'd11 || !m_sol_o || !m_eol_o ||
                !m_sof_o || !m_eof_o || s_ready_o)
                $fatal(1, "Single-pixel frame output changed during backpressure");
        end

        m_ready_i = 1'b1;
        send_and_check(8'd12);
        $display("PASS: pixel_stream_frame_metadata_single_pixel");
        $finish;
    end
endmodule
