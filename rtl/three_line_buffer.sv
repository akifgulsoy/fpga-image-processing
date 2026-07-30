module three_line_buffer #(
    parameter int unsigned PIXEL_WIDTH = 8,
    parameter int unsigned LINE_PIXELS = 640
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,

    input  logic                   s_valid_i,
    output logic                   s_ready_o,
    input  logic [PIXEL_WIDTH-1:0] s_pixel_i,

    output logic                   m_valid_o,
    input  logic                   m_ready_i,
    output logic [PIXEL_WIDTH-1:0] m_pixel_o,
    output logic [PIXEL_WIDTH-1:0] m_line1_pixel_o,
    output logic [PIXEL_WIDTH-1:0] m_line2_pixel_o
);

    localparam int unsigned COLUMN_WIDTH =
        (LINE_PIXELS > 1) ? $clog2(LINE_PIXELS) : 1;

    logic [PIXEL_WIDTH-1:0] line1_mem [0:LINE_PIXELS-1];
    logic [PIXEL_WIDTH-1:0] line2_mem [0:LINE_PIXELS-1];
    logic [COLUMN_WIDTH-1:0] column_q;
    integer index;

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o       <= 1'b0;
            m_pixel_o       <= '0;
            m_line1_pixel_o <= '0;
            m_line2_pixel_o <= '0;
            column_q        <= '0;
            for (index = 0; index < LINE_PIXELS; index = index + 1) begin
                line1_mem[index] <= '0;
                line2_mem[index] <= '0;
            end
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                m_pixel_o       <= s_pixel_i;
                m_line1_pixel_o <= line1_mem[column_q];
                m_line2_pixel_o <= line2_mem[column_q];
                line2_mem[column_q] <= line1_mem[column_q];
                line1_mem[column_q] <= s_pixel_i;

                if (column_q == LINE_PIXELS - 1) begin
                    column_q <= '0;
                end else begin
                    column_q <= column_q + 1'b1;
                end
            end
        end
    end

endmodule
