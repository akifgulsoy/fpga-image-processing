`timescale 1ns/1ps

module tb_rgb_to_grayscale;

    logic       clk_i = 1'b0;
    logic       rst_ni = 1'b0;
    logic       s_valid_i = 1'b0;
    logic       s_ready_o;
    logic [7:0] s_red_i = 8'd0;
    logic [7:0] s_green_i = 8'd0;
    logic [7:0] s_blue_i = 8'd0;
    logic       m_valid_o;
    logic       m_ready_i = 1'b1;
    logic [7:0] m_gray_o;

    always #5 clk_i = ~clk_i;

    rgb_to_grayscale dut (
        .clk_i,
        .rst_ni,
        .s_valid_i,
        .s_ready_o,
        .s_red_i,
        .s_green_i,
        .s_blue_i,
        .m_valid_o,
        .m_ready_i,
        .m_gray_o
    );

    function automatic logic [7:0] expected_gray (
        input logic [7:0] red,
        input logic [7:0] green,
        input logic [7:0] blue
    );
        logic [15:0] total;
        begin
            total = red * 16'd77
                  + green * 16'd150
                  + blue * 16'd29
                  + 16'd128;
            expected_gray = total[15:8];
        end
    endfunction

    task automatic send_and_check (
        input logic [7:0] red,
        input logic [7:0] green,
        input logic [7:0] blue
    );
        logic [7:0] expected;
        begin
            expected = expected_gray(red, green, blue);
            @(negedge clk_i);
            while (!s_ready_o) @(negedge clk_i);
            s_red_i   = red;
            s_green_i = green;
            s_blue_i  = blue;
            s_valid_i = 1'b1;

            @(negedge clk_i);
            s_valid_i = 1'b0;

            while (!m_valid_o) @(negedge clk_i);
            if (m_gray_o !== expected) begin
                $fatal(
                    1,
                    "RGB(%0d,%0d,%0d): expected %0d, got %0d",
                    red,
                    green,
                    blue,
                    expected,
                    m_gray_o
                );
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd0,   8'd0,   8'd0);
        send_and_check(8'd255, 8'd255, 8'd255);
        send_and_check(8'd255, 8'd0,   8'd0);
        send_and_check(8'd0,   8'd255, 8'd0);
        send_and_check(8'd0,   8'd0,   8'd255);
        send_and_check(8'd12,  8'd34,  8'd56);

        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_red_i   = 8'd10;
        s_green_i = 8'd20;
        s_blue_i  = 8'd30;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;

        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_gray_o !== expected_gray(8'd10, 8'd20, 8'd30)) begin
                $fatal(1, "Output changed while downstream was stalled");
            end
            if (s_ready_o) begin
                $fatal(1, "Input advertised ready while output was stalled");
            end
        end

        m_ready_i = 1'b1;
        @(negedge clk_i);

        $display("PASS: rgb_to_grayscale");
        $finish;
    end

endmodule
