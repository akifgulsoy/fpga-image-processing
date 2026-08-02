`timescale 1ns/1ps
module tb_pixel_stream_line_metadata;
    logic clk_i = 1'b0, rst_ni = 1'b0, s_valid_i = 1'b0, s_ready_o;
    logic [7:0] s_pixel_i = '0;
    logic s_sol_i = 1'b0, s_eol_i = 1'b0;
    logic m_valid_o, m_ready_i = 1'b1;
    logic [7:0] m_pixel_o;
    logic m_sol_o, m_eol_o;
    always #5 clk_i = ~clk_i;
    pixel_stream_line_metadata dut (.*);

    task automatic send_and_check(input logic [7:0] pixel, input logic sol, input logic eol);
        begin
            @(negedge clk_i); while (!s_ready_o) @(negedge clk_i);
            s_pixel_i = pixel; s_sol_i = sol; s_eol_i = eol; s_valid_i = 1'b1;
            @(negedge clk_i); s_valid_i = 1'b0;
            if (!m_valid_o || m_pixel_o !== pixel || m_sol_o !== sol || m_eol_o !== eol)
                $fatal(1, "Pixel or line metadata did not transfer together");
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i); rst_ni = 1'b1;
        send_and_check(8'd10, 1'b1, 1'b0);
        send_and_check(8'd11, 1'b0, 1'b0);
        send_and_check(8'd12, 1'b0, 1'b1);
        @(negedge clk_i); m_ready_i = 1'b0;
        s_pixel_i = 8'd91; s_sol_i = 1'b1; s_eol_i = 1'b1; s_valid_i = 1'b1;
        @(negedge clk_i); s_valid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_pixel_o !== 8'd91 || !m_sol_o || !m_eol_o || s_ready_o)
                $fatal(1, "Output payload, metadata, or ready changed while stalled");
        end
        m_ready_i = 1'b1; @(negedge clk_i);
        if (!s_ready_o) $fatal(1, "Input did not become ready after downstream accepted output");
        $display("PASS: pixel_stream_line_metadata"); $finish;
    end
endmodule
