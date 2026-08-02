module pixel_stream_line_metadata #(
    parameter int unsigned PIXEL_WIDTH = 8
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,
    input  logic                   s_valid_i,
    output logic                   s_ready_o,
    input  logic [PIXEL_WIDTH-1:0] s_pixel_i,
    input  logic                   s_sol_i,
    input  logic                   s_eol_i,
    output logic                   m_valid_o,
    input  logic                   m_ready_i,
    output logic [PIXEL_WIDTH-1:0] m_pixel_o,
    output logic                   m_sol_o,
    output logic                   m_eol_o
);

    always_comb s_ready_o = ~m_valid_o | m_ready_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_pixel_o <= '0;
            m_sol_o   <= 1'b0;
            m_eol_o   <= 1'b0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_pixel_o <= s_pixel_i;
                m_sol_o   <= s_sol_i;
                m_eol_o   <= s_eol_i;
            end
        end
    end
endmodule
