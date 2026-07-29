`timescale 1ns/1ps

module tb_pixel_stream_register_slice;

    logic       clk_i = 1'b0;
    logic       rst_ni = 1'b0;
    logic       s_valid_i = 1'b0;
    logic       s_ready_o;
    logic [7:0] s_data_i = 8'd0;
    logic       m_valid_o;
    logic       m_ready_i = 1'b1;
    logic [7:0] m_data_o;

    always #5 clk_i = ~clk_i;

    pixel_stream_register_slice #(
        .DATA_WIDTH(8)
    ) dut (
        .clk_i,
        .rst_ni,
        .s_valid_i,
        .s_ready_o,
        .s_data_i,
        .m_valid_o,
        .m_ready_i,
        .m_data_o
    );

    task automatic send_and_check(input logic [7:0] data);
        begin
            @(negedge clk_i);
            while (!s_ready_o) @(negedge clk_i);
            s_data_i = data;
            s_valid_i = 1'b1;

            @(negedge clk_i);
            s_valid_i = 1'b0;

            while (!m_valid_o) @(negedge clk_i);
            if (m_data_o !== data) begin
                $fatal(1, "Expected data %0d, got %0d", data, m_data_o);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_i);
        rst_ni = 1'b1;

        send_and_check(8'd0);
        send_and_check(8'd37);
        send_and_check(8'd255);

        @(negedge clk_i);
        m_ready_i = 1'b0;
        s_data_i = 8'd91;
        s_valid_i = 1'b1;
        @(negedge clk_i);
        s_valid_i = 1'b0;

        repeat (3) begin
            @(negedge clk_i);
            if (!m_valid_o || m_data_o !== 8'd91) begin
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

        $display("PASS: pixel_stream_register_slice");
        $finish;
    end

endmodule
