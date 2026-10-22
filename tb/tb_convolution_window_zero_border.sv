`timescale 1ns/1ps

module tb_convolution_window_zero_border;

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
        .LINE_PIXELS(3)
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
                $fatal(1, "Unexpected zero-border window for pixel %0d", pixel);
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd10, 0, 0, 0, 0, 0, 0, 0, 0, 10);
        send_and_check(8'd11, 0, 0, 0, 0, 0, 0, 0, 10, 11);
        send_and_check(8'd12, 0, 0, 0, 0, 0, 0, 10, 11, 12);
        send_and_check(8'd20, 0, 0, 0, 0, 0, 10, 0, 0, 20);
        send_and_check(8'd21, 0, 0, 0, 0, 10, 11, 0, 20, 21);
        send_and_check(8'd22, 0, 0, 0, 10, 11, 12, 20, 21, 22);
        send_and_check(8'd30, 0, 0, 10, 0, 0, 20, 0, 0, 30);

        // Hold a second-row-history window while offering the next input.
        // The default zero-filled border and all payload entries must remain
        // stable until the output transfer makes room for the input.
        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_pixel_i = 8'd31;
        s_valid_i = 1'b1;
        repeat (3) begin
            @(negedge clk_i);
            if (s_ready_o || !m_valid_o || m_top_left_o !== 0 ||
                m_top_mid_o !== 0 || m_top_right_o !== 10 ||
                m_mid_left_o !== 0 || m_mid_mid_o !== 0 ||
                m_mid_right_o !== 20 || m_bot_left_o !== 0 ||
                m_bot_mid_o !== 0 || m_bot_right_o !== 30) begin
                $fatal(1, "Zero-border window changed while stalled");
            end
        end
        m_ready_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;
        if (!m_valid_o || m_top_left_o !== 0 || m_top_mid_o !== 10 ||
            m_top_right_o !== 11 || m_mid_left_o !== 0 ||
            m_mid_mid_o !== 20 || m_mid_right_o !== 21 ||
            m_bot_left_o !== 0 || m_bot_mid_o !== 30 || m_bot_right_o !== 31) begin
            $fatal(1, "Held input did not produce the zero-border window");
        end

        $display("PASS: convolution_window_zero_border");
        $finish;
    end

endmodule
