`timescale 1ns/1ps

module tb_convolution_window_3x3;

    logic       clk_i = 1'b0;
    logic       rst_ni = 1'b0;
    logic       s_valid_i = 1'b0;
    logic       s_ready_o;
    logic [7:0] s_pixel_i = 8'd0;
    logic       m_valid_o;
    logic       m_ready_i = 1'b1;
    logic [7:0] m_top_left_o, m_top_mid_o, m_top_right_o;
    logic [7:0] m_mid_left_o, m_mid_mid_o, m_mid_right_o;
    logic [7:0] m_bot_left_o, m_bot_mid_o, m_bot_right_o;

    always #5 clk_i = ~clk_i;

    convolution_window_3x3 #(
        .PIXEL_WIDTH(8),
        .LINE_PIXELS(3),
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
        input logic [7:0] tl, input logic [7:0] tm, input logic [7:0] tr,
        input logic [7:0] ml, input logic [7:0] mm, input logic [7:0] mr,
        input logic [7:0] bl, input logic [7:0] bm, input logic [7:0] br
    );
        begin
            @(negedge clk_i);
            while (!s_ready_o) @(negedge clk_i);
            s_pixel_i = pixel;
            s_valid_i = 1'b1;
            @(negedge clk_i);
            s_valid_i = 1'b0;
            if (!m_valid_o || m_top_left_o !== tl || m_top_mid_o !== tm ||
                m_top_right_o !== tr || m_mid_left_o !== ml ||
                m_mid_mid_o !== mm || m_mid_right_o !== mr ||
                m_bot_left_o !== bl || m_bot_mid_o !== bm || m_bot_right_o !== br) begin
                $fatal(1, "Unexpected 3x3 window for pixel %0d", pixel);
            end
        end
    endtask

    initial begin
        // Deassert reset away from the DUT's active clock edge so the first
        // transfer has a deterministic reset state in all simulators.
        repeat (3) @(negedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd10, 10, 10, 10, 10, 10, 10, 10, 10, 10);
        send_and_check(8'd11, 10, 10, 11, 10, 10, 11, 10, 10, 11);
        send_and_check(8'd12, 10, 11, 12, 10, 11, 12, 10, 11, 12);
        send_and_check(8'd20, 10, 10, 10, 10, 10, 10, 20, 20, 20);
        send_and_check(8'd21, 10, 10, 11, 10, 10, 11, 20, 20, 21);
        send_and_check(8'd22, 10, 11, 12, 10, 11, 12, 20, 21, 22);
        send_and_check(8'd30, 10, 10, 10, 20, 20, 20, 30, 30, 30);
        send_and_check(8'd31, 10, 10, 11, 20, 20, 21, 30, 30, 31);
        send_and_check(8'd32, 10, 11, 12, 20, 21, 22, 30, 31, 32);

        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_pixel_i = 8'd40;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;
        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_top_left_o !== 20 || m_top_mid_o !== 20 ||
                m_top_right_o !== 20 || m_mid_left_o !== 30 || m_mid_mid_o !== 30 ||
                m_mid_right_o !== 30 || m_bot_left_o !== 40 || m_bot_mid_o !== 40 ||
                m_bot_right_o !== 40 || s_ready_o) begin
                $fatal(1, "Window or ready changed while downstream was stalled");
            end
        end

        // Reset with a pending output partway through a line. The next pixel
        // must start a fresh raster, even though the old output was stalled.
        rst_ni = 1'b0;
        #1;
        if (m_valid_o || !s_ready_o) $fatal(1, "Reset did not discard pending window");
        @(negedge clk_i);
        rst_ni = 1'b1;
        m_ready_i = 1'b1;
        send_and_check(8'd90, 90, 90, 90, 90, 90, 90, 90, 90, 90);
        send_and_check(8'd91, 90, 90, 91, 90, 90, 91, 90, 90, 91);
        send_and_check(8'd92, 90, 91, 92, 90, 91, 92, 90, 91, 92);
        send_and_check(8'd93, 90, 90, 90, 90, 90, 90, 93, 93, 93);
        $display("PASS: convolution_window_3x3");
        $finish;
    end

endmodule
