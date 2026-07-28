`timescale 1ns/1ps

module tb_brightness_contrast;

    logic       clk_i = 1'b0;
    logic       rst_ni = 1'b0;
    logic       s_valid_i = 1'b0;
    logic       s_ready_o;
    logic [7:0] s_gray_i = 8'd0;
    logic       m_valid_o;
    logic       m_ready_i = 1'b1;
    logic [7:0] m_gray_o;

    always #5 clk_i = ~clk_i;

    brightness_contrast #(
        .BRIGHTNESS(10'sd16),
        .CONTRAST_Q8(16'sd512)
    ) dut (
        .clk_i,
        .rst_ni,
        .s_valid_i,
        .s_ready_o,
        .s_gray_i,
        .m_valid_o,
        .m_ready_i,
        .m_gray_o
    );

    function automatic logic [7:0] expected_gray(input logic [7:0] gray);
        integer adjusted;
        begin
            adjusted = ((integer'(gray) - 128) * 512 >>> 8) + 128 + 16;
            if (adjusted < 0) begin
                expected_gray = 8'd0;
            end else if (adjusted > 255) begin
                expected_gray = 8'd255;
            end else begin
                expected_gray = adjusted[7:0];
            end
        end
    endfunction

    task automatic send_and_check(input logic [7:0] gray);
        logic [7:0] expected;
        begin
            expected = expected_gray(gray);
            @(negedge clk_i);
            while (!s_ready_o) @(negedge clk_i);
            s_gray_i = gray;
            s_valid_i = 1'b1;

            @(negedge clk_i);
            s_valid_i = 1'b0;

            while (!m_valid_o) @(negedge clk_i);
            if (m_gray_o !== expected) begin
                $fatal(1, "gray %0d: expected %0d, got %0d", gray, expected, m_gray_o);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd0);
        send_and_check(8'd64);
        send_and_check(8'd120);
        send_and_check(8'd128);
        send_and_check(8'd200);
        send_and_check(8'd255);

        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_gray_i = 8'd200;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;

        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_gray_o !== expected_gray(8'd200)) begin
                $fatal(1, "Output changed while downstream was stalled");
            end
            if (s_ready_o) begin
                $fatal(1, "Input advertised ready while output was stalled");
            end
        end

        m_ready_i = 1'b1;
        @(negedge clk_i);

        $display("PASS: brightness_contrast");
        $finish;
    end

endmodule
