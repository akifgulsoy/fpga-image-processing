module axi4s_video_adapter #(
    parameter int unsigned PIXEL_WIDTH = 8
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,

    input  logic                   s_axis_tvalid_i,
    output logic                   s_axis_tready_o,
    input  logic [PIXEL_WIDTH-1:0] s_axis_tdata_i,
    input  logic                   s_axis_tuser_i,
    input  logic                   s_axis_tlast_i,

    output logic                   m_valid_o,
    input  logic                   m_ready_i,
    output logic [PIXEL_WIDTH-1:0] m_pixel_o,
    output logic                   m_sof_o,
    output logic                   m_eol_o
);

    always_comb begin
        s_axis_tready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_pixel_o <= '0;
            m_sof_o   <= 1'b0;
            m_eol_o   <= 1'b0;
        end else if (s_axis_tready_o) begin
            m_valid_o <= s_axis_tvalid_i;
            if (s_axis_tvalid_i) begin
                m_pixel_o <= s_axis_tdata_i;
                m_sof_o   <= s_axis_tuser_i;
                m_eol_o   <= s_axis_tlast_i;
            end
        end
    end

endmodule
