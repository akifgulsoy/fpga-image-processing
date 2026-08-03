`timescale 1ns/1ps
module tb_pixel_stream_frame_metadata;
    logic clk_i = 1'b0, rst_ni = 1'b0, s_valid_i = 1'b0, s_ready_o;
    logic [7:0] s_pixel_i = '0;
    logic m_valid_o, m_ready_i = 1'b1;
    logic [7:0] m_pixel_o;
    logic m_sol_o, m_eol_o, m_sof_o, m_eof_o;
    always #5 clk_i = ~clk_i;

    pixel_stream_frame_metadata #(.LINE_PIXELS(2), .FRAME_LINES(2)) dut (.*);

    task automatic send_and_check(
        input logic [7:0] pixel, input logic sol, input logic eol,
        input logic sof, input logic eof
    );
        begin
            @(negedge clk_i); while (!s_ready_o) @(negedge clk_i);
            s_pixel_i = pixel; s_valid_i = 1'b1;
            @(negedge clk_i); s_valid_i = 1'b0;
            if (!m_valid_o || m_pixel_o !== pixel || m_sol_o !== sol ||
                m_eol_o !== eol || m_sof_o !== sof || m_eof_o !== eof)
                $fatal(1, "Pixel metadata did not match the configured raster");
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i); rst_ni = 1'b1;
        send_and_check(8'd10, 1'b1, 1'b0, 1'b1, 1'b0);
        send_and_check(8'd11, 1'b0, 1'b1, 1'b0, 1'b0);
        send_and_check(8'd12, 1'b1, 1'b0, 1'b0, 1'b0);
        @(negedge clk_i); m_ready_i = 1'b0; s_pixel_i = 8'd13; s_valid_i = 1'b1;
        @(negedge clk_i); s_valid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_pixel_o !== 8'd13 || !m_eol_o || !m_eof_o ||
                m_sol_o || m_sof_o || s_ready_o)
                $fatal(1, "Output or ready changed during backpressure");
        end
        m_ready_i = 1'b1;
        send_and_check(8'd14, 1'b1, 1'b0, 1'b1, 1'b0);
        $display("PASS: pixel_stream_frame_metadata"); $finish;
    end
endmodule
