module sobel_xy #(
    parameter int unsigned PIXEL_WIDTH = 8
) (
    input logic clk_i, rst_ni, s_valid_i,
    output logic s_ready_o,
    input logic [PIXEL_WIDTH-1:0] s_top_left_i, s_top_mid_i, s_top_right_i,
    input logic [PIXEL_WIDTH-1:0] s_mid_left_i, s_mid_right_i,
    input logic [PIXEL_WIDTH-1:0] s_bot_left_i, s_bot_mid_i, s_bot_right_i,
    output logic m_valid_o,
    input logic m_ready_i,
    output logic signed [PIXEL_WIDTH+2:0] m_gx_o, m_gy_o
);
    logic signed [PIXEL_WIDTH+2:0] gx_next, gy_next;

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
        gx_next = $signed({3'b000, s_top_right_i}) - $signed({3'b000, s_top_left_i})
                + ($signed({3'b000, s_mid_right_i}) <<< 1) - ($signed({3'b000, s_mid_left_i}) <<< 1)
                + $signed({3'b000, s_bot_right_i}) - $signed({3'b000, s_bot_left_i});
        gy_next = $signed({3'b000, s_bot_left_i}) - $signed({3'b000, s_top_left_i})
                + ($signed({3'b000, s_bot_mid_i}) <<< 1) - ($signed({3'b000, s_top_mid_i}) <<< 1)
                + $signed({3'b000, s_bot_right_i}) - $signed({3'b000, s_top_right_i});
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_gx_o <= '0;
            m_gy_o <= '0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_gx_o <= gx_next;
                m_gy_o <= gy_next;
            end
        end
    end
endmodule
