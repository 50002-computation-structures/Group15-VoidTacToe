module tictactoe_ws2812_display #(
        parameter integer NUM_BOXES = 9,
        parameter integer BOXES_PER_ROW = 3,
        parameter integer PIXELS_PER_BOX = 16,
        parameter integer BOX_PIXELS_PER_ROW = 4,
        parameter integer BITS_PER_PIXEL = 24,
        parameter integer T0H_CYCLES = 4,
        parameter integer T0L_CYCLES = 8,
        parameter integer T1H_CYCLES = 7,
        parameter integer T1L_CYCLES = 6,
        parameter integer RESET_CYCLES = 3000
    ) (
        input wire clk,
        input wire rst,
        input wire [NUM_BOXES - 1:0][1:0] cell_states,
        output reg ws2812_out
    );
    localparam integer NUM_PIXELS = NUM_BOXES * PIXELS_PER_BOX;
    localparam logic [1:0] S_IDLE = 2'd0;
    localparam logic [1:0] S_HIGH = 2'd1;
    localparam logic [1:0] S_LOW = 2'd2;
    localparam logic [1:0] S_RESET = 2'd3;
    localparam logic [15:0] X_BITMAP = 16'b1001_0110_0110_1001;
    localparam logic [15:0] O_BITMAP = 16'b1111_1001_1001_1111;
    localparam logic [15:0] EMPTY_BITMAP = 16'b0000_0110_0110_0000;
    localparam logic [23:0] COLOR_OFF = 24'h000000;
    localparam logic [23:0] COLOR_X = {8'h00, 8'h40, 8'h00};
    localparam logic [23:0] COLOR_O = {8'h40, 8'h00, 8'h00};
    localparam logic [23:0] COLOR_EMPTY = {8'h00, 8'h00, 8'h20};

    logic [1:0] state_d, state_q = S_RESET;
    logic [31:0] phase_counter_d, phase_counter_q = 0;
    logic [31:0] reset_counter_d, reset_counter_q = RESET_CYCLES - 1;
    logic [$clog2(NUM_PIXELS)-1:0] pixel_index_d, pixel_index_q = 0;
    logic [BITS_PER_PIXEL-1:0] shift_color_d, shift_color_q = 0;
    logic [$clog2(BITS_PER_PIXEL)-1:0] bit_index_d, bit_index_q = 0;
    logic [NUM_BOXES - 1:0][1:0] frame_cell_states_d, frame_cell_states_q = '0;
    logic current_bit_d, current_bit_q = 0;
    logic ws2812_out_d, ws2812_out_q = 0;
    logic [BITS_PER_PIXEL-1:0] current_pixel_color;
    logic [BITS_PER_PIXEL-1:0] next_pixel_color;

    // Board layout is snake-wired across 3x3 modules, and each 4x4 module is snake-wired internally.
    function automatic integer board_box_index(input integer chain_box_index);
        integer box_row;
        integer box_col;
        begin
            box_row = chain_box_index / BOXES_PER_ROW;
            box_col = chain_box_index % BOXES_PER_ROW;
            if ((box_row % 2) == 1) begin
                board_box_index = (box_row * BOXES_PER_ROW) + ((BOXES_PER_ROW - 1) - box_col);
            end else begin
                board_box_index = (box_row * BOXES_PER_ROW) + box_col;
            end
        end
    endfunction

    function automatic integer bitmap_index(input integer pixel_in_box);
        integer pixel_row;
        integer pixel_col;
        integer visual_col;
        begin
            pixel_row = pixel_in_box / BOX_PIXELS_PER_ROW;
            pixel_col = pixel_in_box % BOX_PIXELS_PER_ROW;
            if ((pixel_row % 2) == 1) begin
                visual_col = (BOX_PIXELS_PER_ROW - 1) - pixel_col;
            end else begin
                visual_col = pixel_col;
            end
            bitmap_index = (PIXELS_PER_BOX - 1) - ((pixel_row * BOX_PIXELS_PER_ROW) + visual_col);
        end
    endfunction

    function automatic logic [15:0] bitmap_for_state(input logic [1:0] cell_state);
        begin
            case (cell_state)
                2'h1: bitmap_for_state = X_BITMAP;
                2'h3: bitmap_for_state = O_BITMAP;
                default: bitmap_for_state = EMPTY_BITMAP;
            endcase
        end
    endfunction

    function automatic logic [23:0] color_for_state(input logic [1:0] cell_state, input logic pixel_on);
        begin
            if (!pixel_on) begin
                color_for_state = COLOR_OFF;
            end else begin
                case (cell_state)
                    2'h1: color_for_state = COLOR_X;
                    2'h3: color_for_state = COLOR_O;
                    default: color_for_state = COLOR_EMPTY;
                endcase
            end
        end
    endfunction

    function automatic logic [23:0] pixel_color_for_index(input integer pixel_index);
        integer chain_box_index;
        integer pixel_in_box;
        integer logical_box_index;
        integer bit_pos;
        logic [1:0] cell_state;
        logic [15:0] bitmap;
        begin
            if ((pixel_index < 0) || (pixel_index >= NUM_PIXELS)) begin
                pixel_color_for_index = COLOR_OFF;
            end else begin
                chain_box_index = pixel_index / PIXELS_PER_BOX;
                pixel_in_box = pixel_index % PIXELS_PER_BOX;
                logical_box_index = board_box_index(chain_box_index);
                bit_pos = bitmap_index(pixel_in_box);
                cell_state = frame_cell_states_q[logical_box_index];
                bitmap = bitmap_for_state(cell_state);
                pixel_color_for_index = color_for_state(cell_state, bitmap[bit_pos]);
            end
        end
    endfunction

    always @* begin
        current_pixel_color = pixel_color_for_index(pixel_index_q);
        next_pixel_color = pixel_color_for_index(pixel_index_q + 1);
    end

    always @* begin
        state_d = state_q;
        phase_counter_d = phase_counter_q;
        reset_counter_d = reset_counter_q;
        pixel_index_d = pixel_index_q;
        shift_color_d = shift_color_q;
        bit_index_d = bit_index_q;
        frame_cell_states_d = frame_cell_states_q;
        current_bit_d = current_bit_q;
        ws2812_out_d = ws2812_out_q;

        case (state_q)
            S_IDLE: begin
                ws2812_out_d = 1'b0;
                shift_color_d = current_pixel_color;
                bit_index_d = BITS_PER_PIXEL - 1;
                current_bit_d = current_pixel_color[BITS_PER_PIXEL - 1];
                phase_counter_d = current_pixel_color[BITS_PER_PIXEL - 1] ? (T1H_CYCLES - 1) : (T0H_CYCLES - 1);
                state_d = S_HIGH;
                ws2812_out_d = 1'b1;
            end

            S_HIGH: begin
                if (phase_counter_q != 0) begin
                    phase_counter_d = phase_counter_q - 1;
                end else begin
                    phase_counter_d = current_bit_q ? (T1L_CYCLES - 1) : (T0L_CYCLES - 1);
                    state_d = S_LOW;
                    ws2812_out_d = 1'b0;
                end
            end

            S_LOW: begin
                if (phase_counter_q != 0) begin
                    phase_counter_d = phase_counter_q - 1;
                end else if (bit_index_q != 0) begin
                    shift_color_d = {shift_color_q[BITS_PER_PIXEL - 2:0], 1'b0};
                    bit_index_d = bit_index_q - 1;
                    current_bit_d = shift_color_q[BITS_PER_PIXEL - 2];
                    phase_counter_d = shift_color_q[BITS_PER_PIXEL - 2] ? (T1H_CYCLES - 1) : (T0H_CYCLES - 1);
                    state_d = S_HIGH;
                    ws2812_out_d = 1'b1;
                end else if (pixel_index_q == (NUM_PIXELS - 1)) begin
                    pixel_index_d = 0;
                    reset_counter_d = RESET_CYCLES - 1;
                    state_d = S_RESET;
                    ws2812_out_d = 1'b0;
                end else begin
                    pixel_index_d = pixel_index_q + 1;
                    shift_color_d = next_pixel_color;
                    bit_index_d = BITS_PER_PIXEL - 1;
                    current_bit_d = next_pixel_color[BITS_PER_PIXEL - 1];
                    phase_counter_d = next_pixel_color[BITS_PER_PIXEL - 1] ? (T1H_CYCLES - 1) : (T0H_CYCLES - 1);
                    state_d = S_HIGH;
                    ws2812_out_d = 1'b1;
                end
            end

            S_RESET: begin
                ws2812_out_d = 1'b0;
                if (reset_counter_q != 0) begin
                    reset_counter_d = reset_counter_q - 1;
                end else begin
                    frame_cell_states_d = cell_states;
                    state_d = S_IDLE;
                end
            end

            default: begin
                state_d = S_RESET;
                reset_counter_d = RESET_CYCLES - 1;
                pixel_index_d = 0;
                ws2812_out_d = 1'b0;
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state_q <= S_RESET;
            phase_counter_q <= 0;
            reset_counter_q <= RESET_CYCLES - 1;
            pixel_index_q <= 0;
            shift_color_q <= 0;
            bit_index_q <= 0;
            frame_cell_states_q <= '0;
            current_bit_q <= 1'b0;
            ws2812_out_q <= 1'b0;
        end else begin
            state_q <= state_d;
            phase_counter_q <= phase_counter_d;
            reset_counter_q <= reset_counter_d;
            pixel_index_q <= pixel_index_d;
            shift_color_q <= shift_color_d;
            bit_index_q <= bit_index_d;
            frame_cell_states_q <= frame_cell_states_d;
            current_bit_q <= current_bit_d;
            ws2812_out_q <= ws2812_out_d;
        end
    end

    always @* begin
        ws2812_out = ws2812_out_q;
    end
endmodule
