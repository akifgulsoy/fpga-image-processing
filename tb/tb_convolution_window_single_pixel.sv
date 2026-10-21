`timescale 1ns/1ps

module tb_convolution_window_single_pixel;

    logic       clk_i = 1'b0;
    logic       rst_ni = 1'b0;
    logic       s_valid_i = 1'b0;
    logic       s_ready_o;
    logic [7:0] s_pixel_i = '0;
    logic       m_valid_o;
    logic       m_ready_i = 1'b1;
    logic [7:0] m_top_left_o, m_top_mid_o, m_top_right_o;
    logic [7:0] m_mid_left_o, m_mid_mid_o, m_mid_right_o;
    logic [7:0] m_bot_left_o, m_bot_mid_o, m_bot_right_o;

    always #5 clk_i = ~clk_i;

    convolution_window_3x3 #(
        .PIXEL_WIDTH(8),
        .LINE_PIXELS(1),
        .REPLICATE_LEFT_BORDER(1'b1),
        .REPLICATE_TOP_BORDER(1'b1)
    ) dut (
        .clk_i, .rst_ni, .s_valid_i, .s_ready_o, .s_pixel_i,
        .m_valid_o, .m_ready_i,
        .m_top_left_o, .m_top_mid_o, .m_top_right_o,
        .m_mid_left_o, .m_mid_mid_o, .m_mid_right_o,
        .m_bot_left_o, .m_bot_mid_o, .m_bot_right_o
    );

    task automatic send_and_check(
        input logic [7:0] pixel,
        input logic [7:0] top,
        input logic [7:0] middle,
        input logic [7:0] bottom
    );
        begin
            @(negedge clk_i);
            while (!s_ready_o) @(negedge clk_i);
            s_pixel_i = pixel;
            s_valid_i = 1'b1;
            @(negedge clk_i);
            s_valid_i = 1'b0;
            if (!m_valid_o || m_top_left_o !== top || m_top_mid_o !== top ||
                m_top_right_o !== top || m_mid_left_o !== middle ||
                m_mid_mid_o !== middle || m_mid_right_o !== middle ||
                m_bot_left_o !== bottom || m_bot_mid_o !== bottom ||
                m_bot_right_o !== bottom) begin
                $fatal(1, "Unexpected single-pixel-line window for pixel %0d", pixel);
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd10, 8'd10, 8'd10, 8'd10);
        send_and_check(8'd20, 8'd10, 8'd10, 8'd20);

        // Reset also wins over an output that is ready to transfer on the
        // following rising edge, so it must begin a new raster.
        @(negedge clk_i);
        s_pixel_i = 8'd30;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;
        if (!m_valid_o || m_bot_right_o !== 30) $fatal(1, "Expected transferable window");
        rst_ni = 1'b0;
        #1;
        if (m_valid_o || !s_ready_o) $fatal(1, "Reset did not discard transferable window");
        @(negedge clk_i);
        rst_ni = 1'b1;
        send_and_check(8'd40, 8'd40, 8'd40, 8'd40);

        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_pixel_i = 8'd50;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_top_left_o !== 40 || m_top_mid_o !== 40 ||
                m_top_right_o !== 40 || m_mid_left_o !== 40 ||
                m_mid_mid_o !== 40 || m_mid_right_o !== 40 ||
                m_bot_left_o !== 50 || m_bot_mid_o !== 50 ||
                m_bot_right_o !== 50 || s_ready_o) begin
                $fatal(1, "Window or ready changed while downstream was stalled");
            end
        end

        // Reset must discard the stalled window and all single-pixel-line
        // history, then permit a fresh raster with both border policies on.
        rst_ni = 1'b0;
        #1;
        if (m_valid_o || !s_ready_o) $fatal(1, "Reset did not discard pending window");
        @(negedge clk_i);
        rst_ni = 1'b1;
        m_ready_i = 1'b1;
        send_and_check(8'd90, 8'd90, 8'd90, 8'd90);
        send_and_check(8'd91, 8'd90, 8'd90, 8'd91);
        $display("PASS: convolution_window_single_pixel");
        $finish;
    end

endmodule
