module pixel_stream_frame_metadata #(
    parameter int unsigned PIXEL_WIDTH = 8,
    parameter int unsigned LINE_PIXELS = 640,
    parameter int unsigned FRAME_LINES = 480
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,
    input  logic                   s_valid_i,
    output logic                   s_ready_o,
    input  logic [PIXEL_WIDTH-1:0] s_pixel_i,
    output logic                   m_valid_o,
    input  logic                   m_ready_i,
    output logic [PIXEL_WIDTH-1:0] m_pixel_o,
    output logic                   m_sol_o,
    output logic                   m_eol_o,
    output logic                   m_sof_o,
    output logic                   m_eof_o
);

    localparam int unsigned COLUMN_WIDTH =
        (LINE_PIXELS > 1) ? $clog2(LINE_PIXELS) : 1;
    localparam int unsigned LINE_WIDTH =
        (FRAME_LINES > 1) ? $clog2(FRAME_LINES) : 1;

    logic [COLUMN_WIDTH-1:0] column_q;
    logic [LINE_WIDTH-1:0] line_q;

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o <= 1'b0;
            m_pixel_o <= '0;
            m_sol_o   <= 1'b0;
            m_eol_o   <= 1'b0;
            m_sof_o   <= 1'b0;
            m_eof_o   <= 1'b0;
            column_q  <= '0;
            line_q    <= '0;
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_pixel_o <= s_pixel_i;
                m_sol_o   <= (column_q == '0);
                m_eol_o   <= (column_q == LINE_PIXELS - 1);
                m_sof_o   <= (column_q == '0) && (line_q == '0);
                m_eof_o   <= (column_q == LINE_PIXELS - 1) &&
                             (line_q == FRAME_LINES - 1);
                if (column_q == LINE_PIXELS - 1) begin
                    column_q <= '0;
                    if (line_q == FRAME_LINES - 1) begin
                        line_q <= '0;
                    end else begin
                        line_q <= line_q + 1'b1;
                    end
                end else begin
                    column_q <= column_q + 1'b1;
                end
            end
        end
    end
endmodule
