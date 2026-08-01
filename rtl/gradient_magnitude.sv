module gradient_magnitude #(
    parameter int unsigned PIXEL_WIDTH = 8
) (
    input logic clk_i, rst_ni, s_valid_i,
    output logic s_ready_o,
    input logic signed [PIXEL_WIDTH+2:0] s_gx_i, s_gy_i,
    output logic m_valid_o,
    input logic m_ready_i,
    output logic [PIXEL_WIDTH+2:0] m_magnitude_o
);
    logic [PIXEL_WIDTH+2:0] abs_gx, abs_gy;
    logic [PIXEL_WIDTH+3:0] magnitude_sum;

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
        abs_gx = s_gx_i[PIXEL_WIDTH+2] ? -s_gx_i : s_gx_i;
        abs_gy = s_gy_i[PIXEL_WIDTH+2] ? -s_gy_i : s_gy_i;
        magnitude_sum = {1'b0, abs_gx} + {1'b0, abs_gy};
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_magnitude_o <= '0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i)
                m_magnitude_o <= magnitude_sum[PIXEL_WIDTH+3]
                    ? {PIXEL_WIDTH+3{1'b1}} : magnitude_sum[PIXEL_WIDTH+2:0];
        end
    end
endmodule
