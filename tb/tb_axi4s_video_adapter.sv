`timescale 1ns/1ps

module tb_axi4s_video_adapter;
    logic clk_i = 1'b0, rst_ni = 1'b0;
    logic s_axis_tvalid_i = 1'b0, s_axis_tready_o;
    logic [7:0] s_axis_tdata_i = '0;
    logic s_axis_tuser_i = 1'b0, s_axis_tlast_i = 1'b0;
    logic m_valid_o, m_ready_i = 1'b1;
    logic [7:0] m_pixel_o;
    logic m_sof_o, m_eol_o;

    always #5 clk_i = ~clk_i;

    axi4s_video_adapter #(.PIXEL_WIDTH(8)) dut (.*);

    task automatic send_and_check(input logic [7:0] pixel, input logic sof, input logic eol);
        begin
            @(negedge clk_i); while (!s_axis_tready_o) @(negedge clk_i);
            s_axis_tdata_i = pixel; s_axis_tuser_i = sof; s_axis_tlast_i = eol;
            s_axis_tvalid_i = 1'b1;
            @(negedge clk_i); s_axis_tvalid_i = 1'b0;
            if (!m_valid_o || m_pixel_o !== pixel || m_sof_o !== sof || m_eol_o !== eol)
                $fatal(1, "AXI4-Stream payload or video markers did not transfer together");
        end
    endtask

    initial begin
        repeat (3) @(negedge clk_i); rst_ni = 1'b1;
        send_and_check(8'd10, 1'b1, 1'b0);
        send_and_check(8'd11, 1'b0, 1'b1);

        @(negedge clk_i); m_ready_i = 1'b0;
        s_axis_tdata_i = 8'd91; s_axis_tuser_i = 1'b1; s_axis_tlast_i = 1'b1;
        s_axis_tvalid_i = 1'b1;
        @(negedge clk_i); s_axis_tvalid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_pixel_o !== 8'd91 || !m_sof_o || !m_eol_o || s_axis_tready_o)
                $fatal(1, "AXI4-Stream output or ready changed while stalled");
        end
        m_ready_i = 1'b1; @(negedge clk_i);
        if (!s_axis_tready_o) $fatal(1, "AXI4-Stream input did not become ready");
        $display("PASS: axi4s_video_adapter");
        $finish;
    end
endmodule
