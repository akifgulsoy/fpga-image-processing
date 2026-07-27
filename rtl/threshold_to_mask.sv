module threshold_to_mask #(
    parameter logic [7:0] THRESHOLD = 8'd128
) (
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       s_valid_i,
    output logic       s_ready_o,
    input  logic [7:0] s_gray_i,

    output logic       m_valid_o,
    input  logic       m_ready_i,
    output logic       m_mask_o
);

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_mask_o  <= 1'b0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_mask_o <= s_gray_i >= THRESHOLD;
            end
        end
    end

endmodule
