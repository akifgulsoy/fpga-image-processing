`timescale 1ns/1ps

module tb_three_line_buffer;

    logic       clk_i = 1'b0;
    logic       rst_ni = 1'b0;
    logic       s_valid_i = 1'b0;
    logic       s_ready_o;
    logic [7:0] s_pixel_i = 8'd0;
    logic       m_valid_o;
    logic       m_ready_i = 1'b1;
    logic [7:0] m_pixel_o;
    logic [7:0] m_line1_pixel_o;
    logic [7:0] m_line2_pixel_o;

    always #5 clk_i = ~clk_i;

    three_line_buffer #(
        .PIXEL_WIDTH(8),
        .LINE_PIXELS(4)
    ) dut (
        .clk_i,
        .rst_ni,
        .s_valid_i,
        .s_ready_o,
        .s_pixel_i,
        .m_valid_o,
        .m_ready_i,
        .m_pixel_o,
        .m_line1_pixel_o,
        .m_line2_pixel_o
    );

    task automatic send_and_check(
        input logic [7:0] pixel,
        input logic [7:0] expected_line1,
        input logic [7:0] expected_line2
    );
        begin
            @(negedge clk_i);
            while (!s_ready_o) @(negedge clk_i);
            s_pixel_i = pixel;
            s_valid_i = 1'b1;

            @(negedge clk_i);
            s_valid_i = 1'b0;

            if (!m_valid_o || m_pixel_o !== pixel ||
                m_line1_pixel_o !== expected_line1 ||
                m_line2_pixel_o !== expected_line2) begin
                $fatal(1, "Expected (%0d, %0d, %0d), got (%0d, %0d, %0d)",
                    pixel, expected_line1, expected_line2,
                    m_pixel_o, m_line1_pixel_o, m_line2_pixel_o);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd10, 8'd0, 8'd0);
        send_and_check(8'd11, 8'd0, 8'd0);
        send_and_check(8'd12, 8'd0, 8'd0);
        send_and_check(8'd13, 8'd0, 8'd0);
        send_and_check(8'd20, 8'd10, 8'd0);
        send_and_check(8'd21, 8'd11, 8'd0);
        send_and_check(8'd22, 8'd12, 8'd0);
        send_and_check(8'd23, 8'd13, 8'd0);
        send_and_check(8'd30, 8'd20, 8'd10);

        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_pixel_i = 8'd31;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;

        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_pixel_o !== 8'd31 ||
                m_line1_pixel_o !== 8'd21 || m_line2_pixel_o !== 8'd11) begin
                $fatal(1, "Output changed while downstream was stalled");
            end
            if (s_ready_o) begin
                $fatal(1, "Input advertised ready while output was stalled");
            end
        end

        m_ready_i = 1'b1;
        @(negedge clk_i);
        if (!s_ready_o) begin
            $fatal(1, "Input did not become ready after downstream accepted output");
        end

        $display("PASS: three_line_buffer");
        $finish;
    end

endmodule
