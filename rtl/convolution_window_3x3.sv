module convolution_window_3x3 #(
    parameter int unsigned PIXEL_WIDTH = 8,
    parameter int unsigned LINE_PIXELS = 640,
    parameter bit REPLICATE_LEFT_BORDER = 1'b0
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,

    input  logic                   s_valid_i,
    output logic                   s_ready_o,
    input  logic [PIXEL_WIDTH-1:0] s_pixel_i,

    output logic                   m_valid_o,
    input  logic                   m_ready_i,
    output logic [PIXEL_WIDTH-1:0] m_top_left_o,
    output logic [PIXEL_WIDTH-1:0] m_top_mid_o,
    output logic [PIXEL_WIDTH-1:0] m_top_right_o,
    output logic [PIXEL_WIDTH-1:0] m_mid_left_o,
    output logic [PIXEL_WIDTH-1:0] m_mid_mid_o,
    output logic [PIXEL_WIDTH-1:0] m_mid_right_o,
    output logic [PIXEL_WIDTH-1:0] m_bot_left_o,
    output logic [PIXEL_WIDTH-1:0] m_bot_mid_o,
    output logic [PIXEL_WIDTH-1:0] m_bot_right_o
);

    localparam int unsigned COLUMN_WIDTH =
        (LINE_PIXELS > 1) ? $clog2(LINE_PIXELS) : 1;

    logic [PIXEL_WIDTH-1:0] line1_mem [0:LINE_PIXELS-1];
    logic [PIXEL_WIDTH-1:0] line2_mem [0:LINE_PIXELS-1];
    logic [COLUMN_WIDTH-1:0] column_q;
    logic [PIXEL_WIDTH-1:0] top_left_q;
    logic [PIXEL_WIDTH-1:0] top_mid_q;
    logic [PIXEL_WIDTH-1:0] mid_left_q;
    logic [PIXEL_WIDTH-1:0] mid_mid_q;
    logic [PIXEL_WIDTH-1:0] bot_left_q;
    logic [PIXEL_WIDTH-1:0] bot_mid_q;
    integer index;

    always_comb begin
        s_ready_o = ~m_valid_o | m_ready_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            m_valid_o     <= 1'b0;
            m_top_left_o  <= '0;
            m_top_mid_o   <= '0;
            m_top_right_o <= '0;
            m_mid_left_o  <= '0;
            m_mid_mid_o   <= '0;
            m_mid_right_o <= '0;
            m_bot_left_o  <= '0;
            m_bot_mid_o   <= '0;
            m_bot_right_o <= '0;
            column_q      <= '0;
            top_left_q    <= '0;
            top_mid_q     <= '0;
            mid_left_q    <= '0;
            mid_mid_q     <= '0;
            bot_left_q    <= '0;
            bot_mid_q     <= '0;
            for (index = 0; index < LINE_PIXELS; index = index + 1) begin
                line1_mem[index] <= '0;
                line2_mem[index] <= '0;
            end
        end else if (s_ready_o) begin
            m_valid_o <= s_valid_i;
            if (s_valid_i) begin
                if ((column_q == '0) && REPLICATE_LEFT_BORDER) begin
                    m_top_left_o <= line2_mem[column_q];
                    m_top_mid_o  <= line2_mem[column_q];
                    m_mid_left_o <= line1_mem[column_q];
                    m_mid_mid_o  <= line1_mem[column_q];
                    m_bot_left_o <= s_pixel_i;
                    m_bot_mid_o  <= s_pixel_i;
                end else begin
                    m_top_left_o <= top_left_q;
                    m_top_mid_o  <= top_mid_q;
                    m_mid_left_o <= mid_left_q;
                    m_mid_mid_o  <= mid_mid_q;
                    m_bot_left_o <= bot_left_q;
                    m_bot_mid_o  <= bot_mid_q;
                end
                m_top_right_o <= line2_mem[column_q];
                m_mid_right_o <= line1_mem[column_q];
                m_bot_right_o <= s_pixel_i;

                top_left_q <= top_mid_q;
                top_mid_q  <= line2_mem[column_q];
                mid_left_q <= mid_mid_q;
                mid_mid_q  <= line1_mem[column_q];
                bot_left_q <= bot_mid_q;
                bot_mid_q  <= s_pixel_i;
                line2_mem[column_q] <= line1_mem[column_q];
                line1_mem[column_q] <= s_pixel_i;

                if (column_q == LINE_PIXELS - 1) begin
                    column_q   <= '0;
                    top_left_q <= '0;
                    top_mid_q  <= '0;
                    mid_left_q <= '0;
                    mid_mid_q  <= '0;
                    bot_left_q <= '0;
                    bot_mid_q  <= '0;
                end else begin
                    column_q <= column_q + 1'b1;
                end
            end
        end
    end

endmodule
