module brightness_contrast #(
    parameter logic signed [9:0]  BRIGHTNESS  = 10'sd0,
    parameter logic signed [15:0] CONTRAST_Q8 = 16'sd256
) (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       s_valid_i,
    output logic       s_ready_o,
    input  logic [7:0] s_gray_i,

    output logic       m_valid_o,
    input  logic       m_ready_i,
    output logic [7:0] m_gray_o
);

    logic signed [10:0] centered_gray;
    logic signed [26:0] scaled_gray;
    logic signed [27:0] adjusted_gray;
    logic        [7:0] clamped_gray;

    always_comb begin
        centered_gray = $signed({1'b0, s_gray_i}) - 11'sd128;
        scaled_gray   = centered_gray * CONTRAST_Q8;
        adjusted_gray = (scaled_gray >>> 8) + 28'sd128 + BRIGHTNESS;

        if (adjusted_gray < 0) begin
            clamped_gray = 8'd0;
        end else if (adjusted_gray > 28'sd255) begin
            clamped_gray = 8'd255;
        end else begin
            clamped_gray = adjusted_gray[7:0];
        end

        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_gray_o  <= 8'd0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_gray_o <= clamped_gray;
            end
        end
    end

endmodule
