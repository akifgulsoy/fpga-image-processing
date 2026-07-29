module pixel_stream_register_slice #(
    parameter int unsigned DATA_WIDTH = 8
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,

    input  logic                  s_valid_i,
    output logic                  s_ready_o,
    input  logic [DATA_WIDTH-1:0] s_data_i,

    output logic                  m_valid_o,
    input  logic                  m_ready_i,
    output logic [DATA_WIDTH-1:0] m_data_o
);

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_data_o  <= '0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_data_o <= s_data_i;
            end
        end
    end

endmodule
