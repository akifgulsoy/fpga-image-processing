module rgb_to_grayscale (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       s_valid_i,
    output logic       s_ready_o,
    input  logic [7:0] s_red_i,
    input  logic [7:0] s_green_i,
    input  logic [7:0] s_blue_i,

    output logic       m_valid_o,
    input  logic       m_ready_i,
    output logic [7:0] m_gray_o
);

    logic [15:0] red_term;
    logic [15:0] green_term;
    logic [15:0] blue_term;
    logic [15:0] rounded_sum;

    always_comb begin
        red_term   = s_red_i   * 8'd77;
        green_term = s_green_i * 8'd150;
        blue_term  = s_blue_i  * 8'd29;
        rounded_sum = red_term + green_term + blue_term + 16'd128;

        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_gray_o  <= 8'd0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_gray_o <= rounded_sum[15:8];
            end
        end
    end

endmodule
