`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/27/2025 02:04:20 PM
// Design Name: 
// Module Name: tetris_grid
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tetris_grid(
        input logic [9:0] drawX, 
        input logic [9:0] drawY, 
        input logic frame_clk, 
        input logic reset, 
        input logic [7:0] keycode, 
        input logic [3:0] bg_red, 
        input logic [3:0] bg_green, 
        input logic [3:0] bg_blue,
        input logic [3:0] end_red, 
        input logic [3:0] end_green, 
        input logic [3:0] end_blue,
        
        output logic [3:0] red, 
        output logic [3:0] green, 
        output logic [3:0] blue, 
        output logic [15:0] score
    );
    
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter CELL_SIZE = 22;
    parameter GRID_WIDTH = 10;
    parameter GRID_HEIGHT = 20;
    parameter CELL_BITS = 4; // first 2 MSB = block type, last 2 LSB = color
    parameter GRID_START_X = 320;
    parameter GRID_START_Y = 20;
    parameter FALL_SPEED = 150;
    
    parameter NEXT_START_X = 80;
    parameter NEXT_START_Y = 80;
    parameter NEXT_GRID_WIDTH = 4;
    parameter NEXT_GRID_HEIGHT = 3;
    parameter NEXT_CELL_SIZE = 22;
    
    logic next_grid[0:NEXT_GRID_HEIGHT-1][0:NEXT_GRID_WIDTH-1];
    logic [CELL_BITS-1:0] grid [0:GRID_HEIGHT-1][0:GRID_WIDTH-1];
    logic [7:0] prev_keycode;
    logic [0:0] spawn_new_block;
    logic [2:0] active_block;
    
    logic spawn_data_in, spawn_data_out, spawn_ld_reg;
    logic shape_ld_reg;
    logic collision;
    logic [2:0] shape_data_in, shape_data_out;
    logic [2:0] next_shape;
    logic lock_block;
    logic valid_drop;
    logic [4:0] drop_dist_0, drop_dist_1, drop_dist_2, drop_dist_3, final_drop_dist;
    logic row_full;
    logic game_over;
    
    logic [4:0] grid_x, block_x_0, block_x_1, block_x_2, block_x_3; // log2(10) ? 4 bits (use 5 for safety)
    logic [4:0] grid_y, block_y_0, block_y_1, block_y_2, block_y_3;  // log2(20) ? 5 bits
    logic signed [4:0] piv_x, rot_x1, rot_x2, rot_x3;
    logic signed [4:0] piv_y, rot_y1, rot_y2, rot_y3;
    logic [4:0] new_block_x_0;
    logic [4:0] new_block_y_0;
    logic block_dropped;
    logic [4:0] next_grid_x, next_block_x_0, next_block_x_1, next_block_x_2, next_block_x_3; 
    logic [4:0] next_grid_y, next_block_y_0, next_block_y_1, next_block_y_2, next_block_y_3;
    logic [3:0] locked_block_color;
    
    assign next_grid_x = (drawX - NEXT_START_X) / NEXT_CELL_SIZE;
    assign next_grid_y = (drawY - NEXT_START_Y) / NEXT_CELL_SIZE;
    
    assign grid_x = (drawX - GRID_START_X) / CELL_SIZE;
    assign grid_y = (drawY - GRID_START_Y) / CELL_SIZE;
    
    logic [4:0] cell_x_pos, cell_y_pos, next_cell_x_pos, next_cell_y_pos;
    
    assign cell_x_pos = (drawX - GRID_START_X) % CELL_SIZE;
    assign cell_y_pos = (drawY - GRID_START_Y) % CELL_SIZE;
    assign next_cell_x_pos = (drawX - NEXT_START_X) % NEXT_CELL_SIZE;
    assign next_cell_y_pos = (drawY - NEXT_START_Y) % NEXT_CELL_SIZE;
    
    logic [9:0] fall_rate;
        
        always_comb begin
            case(next_shape)
                3'b000: begin // Square
                    next_block_x_0 = 5'd1; next_block_y_0 = 5'd0;
                    next_block_x_1 = 5'd2; next_block_y_1 = 5'd0;
                    next_block_x_2 = 5'd1; next_block_y_2 = 5'd1;
                    next_block_x_3 = 5'd2; next_block_y_3 = 5'd1;
                end
                3'b001: begin // L Shape
                    next_block_x_0 = 5'd1; next_block_y_0 = 5'd1;
                    next_block_x_1 = 5'd1; next_block_y_1 = 5'd0;
                    next_block_x_2 = 5'd2; next_block_y_2 = 5'd0;
                    next_block_x_3 = 5'd3; next_block_y_3 = 5'd0;
                end
                3'b010: begin // Straight Line
                    next_block_x_0 = 5'd0; next_block_y_0 = 5'd0;
                    next_block_x_1 = 5'd1; next_block_y_1 = 5'd0;
                    next_block_x_2 = 5'd2; next_block_y_2 = 5'd0;
                    next_block_x_3 = 5'd3; next_block_y_3 = 5'd0;
                end
                3'b011: begin // Z
                    next_block_x_0 = 5'd1; next_block_y_0 = 5'd2;
                    next_block_x_1 = 5'd1; next_block_y_1 = 5'd1;
                    next_block_x_2 = 5'd2; next_block_y_2 = 5'd1;
                    next_block_x_3 = 5'd2; next_block_y_3 = 5'd0;
                end
                3'b100: begin // T block
                    next_block_x_0 = 5'd1; next_block_y_0 = 5'd0;
                    next_block_x_1 = 5'd2; next_block_y_1 = 5'd0;
                    next_block_x_2 = 5'd3; next_block_y_2 = 5'd0;
                    next_block_x_3 = 5'd2; next_block_y_3 = 5'd1;
                end
                3'b101: begin // S block
                    next_block_x_0 = 5'd1; next_block_y_0 = 5'd1;
                    next_block_x_1 = 5'd2; next_block_y_1 = 5'd1;
                    next_block_x_2 = 5'd2; next_block_y_2 = 5'd0;
                    next_block_x_3 = 5'd3; next_block_y_3 = 5'd0;
                end
                3'b110: begin // J block
                    next_block_x_0 = 5'd1; next_block_y_0 = 5'd1;
                    next_block_x_1 = 5'd2; next_block_y_1 = 5'd1;
                    next_block_x_2 = 5'd3; next_block_y_2 = 5'd1;
                    next_block_x_3 = 5'd3; next_block_y_3 = 5'd0;
                end
            endcase    
             
            // Default background: black
                red = bg_red;
                green = bg_green;
                blue = bg_blue;
    
            // Only draw inside the grid are
            if (game_over) begin 
                    red = end_red;
                    green = end_green;
                    blue = end_blue;
                    
            end
            if ((drawX >= GRID_START_X) && (drawX < GRID_START_X + GRID_WIDTH * CELL_SIZE) &&
                (drawY >= GRID_START_Y) && (drawY < GRID_START_Y + GRID_HEIGHT * CELL_SIZE) && (!game_over)) begin
                
                if ((cell_x_pos == 0) || (cell_y_pos == 0)) begin
                    red = 4'h0;
                    green = 4'hA;
                    blue = 4'hF;
                end else begin
                    if ((grid_x == block_x_0 && grid_y == block_y_0) ||
                        (grid_x == block_x_1 && grid_y == block_y_1) ||
                        (grid_x == block_x_2 && grid_y == block_y_2) ||
                        (grid_x == block_x_3 && grid_y == block_y_3) ||
                    
                        ((block_y_0 == GRID_HEIGHT-1 || grid[block_y_0+1][block_x_0][3]) && grid_x == block_x_0 && grid_y == block_y_0) ||
                        ((block_y_1 == GRID_HEIGHT-1 || grid[block_y_1+1][block_x_1][3]) && grid_x == block_x_1 && grid_y == block_y_1) ||
                        ((block_y_2 == GRID_HEIGHT-1 || grid[block_y_2+1][block_x_2][3]) && grid_x == block_x_2 && grid_y == block_y_2) ||
                        ((block_y_3 == GRID_HEIGHT-1 || grid[block_y_3+1][block_x_3][3]) && grid_x == block_x_3 && grid_y == block_y_3))
                        begin
                        // Filled block (red for now)
                        case(active_block)
                            3'b000: begin // Square
                                red = 4'hF;
                                green = 4'hF;
                                blue = 4'h0;
                            end
                            3'b001: begin // L Shape
                                red = 4'hF;
                                green = 4'h8;
                                blue = 4'h0;
                            end
                            3'b010: begin // Straight Line
                                red = 4'h0;
                                green = 4'hF;
                                blue = 4'hF;
                            end
                            3'b011: begin // Z
                                red = 4'hF;
                                green = 4'h0;
                                blue = 4'h0;
                            end
                            3'b100: begin // T block
                                red = 4'hF;
                                green = 4'h0;
                                blue = 4'hF;
                            end
                            3'b101: begin // S block
                                red = 4'h0;
                                green = 4'hF;
                                blue = 4'h0;
                            end
                            3'b110: begin // J block
                                red = 4'h0;
                                green = 4'h0;
                                blue = 4'hF;
                            end
                        endcase 
                        
                    end else if (grid[grid_y][grid_x][3]!= 0) begin
                        case(grid[grid_y][grid_x][2:0])
                            3'b000: begin // Square
                                red = 4'hF;
                                green = 4'hF;
                                blue = 4'h0;
                            end
                            3'b001: begin // L Shape
                                red = 4'hF;
                                green = 4'h8;
                                blue = 4'h0;
                            end
                            3'b010: begin // Straight Line
                                red = 4'h0;
                                green = 4'hF;
                                blue = 4'hF;
                            end
                            3'b011: begin // Z
                                red = 4'hF;
                                green = 4'h0;
                                blue = 4'h0;
                            end
                            3'b100: begin // T block
                                red = 4'hF;
                                green = 4'h0;
                                blue = 4'hF;
                            end
                            3'b101: begin // S block
                                red = 4'h0;
                                green = 4'hF;
                                blue = 4'h0;
                            end
                            3'b110: begin // J block
                                red = 4'h0;
                                green = 4'h0;
                                blue = 4'hF;
                            end
                        endcase 
                        
                    end else begin
                        // Empty block but inside the grid area - draw a slight gray or keep black
                        red = 4'hF;
                        green = 4'hF;
                        blue = 4'hF;
                    end
                    
                end
                
            end else if ((drawX >= NEXT_START_X) && (drawX < NEXT_START_X + NEXT_GRID_WIDTH * NEXT_CELL_SIZE) &&
                        (drawY >= NEXT_START_Y) && (drawY < NEXT_START_Y + NEXT_GRID_HEIGHT * NEXT_CELL_SIZE) && (!game_over)) begin
                        if ((next_grid_x == next_block_x_0 && next_grid_y == next_block_y_0) || (next_grid_x == next_block_x_1 && next_grid_y == next_block_y_1) ||
                            (next_grid_x == next_block_x_2 && next_grid_y == next_block_y_2) || (next_grid_x == next_block_x_3 && next_grid_y == next_block_y_3)) begin 
                            if ((next_cell_x_pos == 0) || (next_cell_y_pos == 0)) begin
                                red = 4'h0;
                                green = 4'hA;
                                blue = 4'hF;
                            end else begin 
                            
                                case(next_shape)
                                    3'b000: begin // Square
                                        red = 4'hF;
                                        green = 4'hF;
                                        blue = 4'h0;
                                    end
                                    3'b001: begin // L Shape
                                        red = 4'hF;
                                        green = 4'h8;
                                        blue = 4'h0;
                                    end
                                    3'b010: begin // Straight Line
                                        red = 4'h0;
                                        green = 4'hF;
                                        blue = 4'hF;
                                    end
                                    3'b011: begin // Z
                                        red = 4'hF;
                                        green = 4'h0;
                                        blue = 4'h0;
                                    end
                                    3'b100: begin // T block
                                        red = 4'hF;
                                        green = 4'h0;
                                        blue = 4'hF;
                                    end
                                    3'b101: begin // S block
                                        red = 4'h0;
                                        green = 4'hF;
                                        blue = 4'h0;
                                    end
                                    3'b110: begin // J block
                                        red = 4'h0;
                                        green = 4'h0;
                                        blue = 4'hF;
                                    end
                                endcase 
                             end
                        end else begin 
                            red = bg_red;
                            green = bg_green;
                            blue = bg_blue;
                        end
                end
    end
     
    always_comb begin // HARD DROP 
        final_drop_dist = 0;
    
        for (int i = 0; i < GRID_HEIGHT; i++) begin
            // Assume no collision at this distance
            collision = 0;
    
            // For each block, check if at that drop distance, it hits something
            if ((block_y_0 + i >= GRID_HEIGHT) || grid[block_y_0 + i][block_x_0]) begin 
                collision = 1;
            end
            if ((block_y_1 + i >= GRID_HEIGHT) || grid[block_y_1 + i][block_x_1]) begin
                collision = 1;
            end
            if ((block_y_2 + i >= GRID_HEIGHT) || grid[block_y_2 + i][block_x_2]) begin 
                collision = 1;
            end
            if ((block_y_3 + i >= GRID_HEIGHT) || grid[block_y_3 + i][block_x_3]) begin 
                collision = 1;
            end
    
            if (!collision)
                final_drop_dist = i;
            else
                break;
        end
     end
     logic signed [4:0] max_right_coord, max_left_coord, shift;
     always_comb begin // ROTATION LOGIC
            piv_x = block_x_0;
            piv_y = block_y_0;
            
            rot_x1 = piv_x - (block_y_1 - piv_y); rot_y1 = piv_y + (block_x_1 - piv_x);
            rot_x2 = piv_x - (block_y_2 - piv_y); rot_y2 = piv_y + (block_x_2 - piv_x);
            rot_x3 = piv_x - (block_y_3 - piv_y); rot_y3 = piv_y + (block_x_3 - piv_x);
            
            new_block_x_0 = piv_x;
            new_block_y_0 = piv_y;
            
            max_right_coord = new_block_x_0;
            if (rot_x1 > max_right_coord) begin 
                max_right_coord = rot_x1;
            end
            if (rot_x2 > max_right_coord) begin 
                max_right_coord = rot_x2;
            end
            if (rot_x3 > max_right_coord) begin 
                max_right_coord = rot_x3;
            end
            
            max_left_coord = new_block_x_0;
            if (rot_x1 < max_left_coord) begin 
                max_left_coord = rot_x1;
            end
            if (rot_x2 < max_left_coord) begin 
                max_left_coord = rot_x2;
            end
            if (rot_x3 < max_left_coord) begin 
                max_left_coord = rot_x3;
            end

            // RIGHT WALL KICK
            if (max_right_coord > (GRID_WIDTH - 1)) begin 
                shift = max_right_coord - (GRID_WIDTH - 1);
                new_block_x_0 = new_block_x_0 - shift;
                rot_x1 = rot_x1 - shift;
                rot_x2 = rot_x2 - shift;
                rot_x3 = rot_x3 - shift;
            end
            // LEFT WALL KICK
           if (max_left_coord < 0) begin 
                shift = 0 - max_left_coord;
                new_block_x_0 = new_block_x_0 + shift;
                rot_x1 = rot_x1 + shift;
                rot_x2 = rot_x2 + shift;
                rot_x3 = rot_x3 + shift;
            end
     end

load_reg #(.DATA_WIDTH(1)) spawn_new_block_reg (
    .clk    (frame_clk),
    .reset  (reset),

    .load   (spawn_ld_reg),
    .data_i (spawn_data_in),

    .data_q (spawn_data_out)
);

load_reg #(.DATA_WIDTH(3)) random_shape_reg (
    .clk    (frame_clk),
    .reset  (reset),

    .load   (shape_ld_reg),
    .data_i (shape_data_in),

    .data_q (shape_data_out)
);

always_ff @(posedge frame_clk) begin

    if (spawn_data_out && (!game_over)) begin 
            spawn_ld_reg <= 1'b1;
            spawn_data_in <= 1'b0;
            lock_block <= 0;
            active_block <= shape_data_out;
            
            case(shape_data_out)
                3'b000: begin // Square
                    block_x_0 <= 5'd4; block_y_0 <= 5'd0;
                    block_x_1 <= 5'd5; block_y_1 <= 5'd0;
                    block_x_2 <= 5'd4; block_y_2 <= 5'd1;
                    block_x_3 <= 5'd5; block_y_3 <= 5'd1;
                    
                end
                3'b001: begin // L Shape
                    block_x_0 <= 5'd4; block_y_0 <= 5'd1;
                    block_x_1 <= 5'd4; block_y_1 <= 5'd0;
                    block_x_2 <= 5'd5; block_y_2 <= 5'd0;
                    block_x_3 <= 5'd6; block_y_3 <= 5'd0;
                    
                end
                3'b010: begin // Straight Line
                    block_x_0 <= 5'd3; block_y_0 <= 5'd0;
                    block_x_1 <= 5'd4; block_y_1 <= 5'd0;
                    block_x_2 <= 5'd5; block_y_2 <= 5'd0;
                    block_x_3 <= 5'd6; block_y_3 <= 5'd0;
                end
                3'b011: begin // Z
                    block_x_0 <= 5'd4; block_y_0 <= 5'd2;
                    block_x_1 <= 5'd4; block_y_1 <= 5'd1;
                    block_x_2 <= 5'd5; block_y_2 <= 5'd1;
                    block_x_3 <= 5'd5; block_y_3 <= 5'd0;
                end
                3'b100: begin // T block
                    block_x_0 <= 4; block_y_0 <= 0;
                    block_x_1 <= 3; block_y_1 <= 0;
                    block_x_2 <= 5; block_y_2 <= 0;
                    block_x_3 <= 4; block_y_3 <= 1;
                end
                3'b101: begin // S block
                    block_x_0 <= 4; block_y_0 <= 0;
                    block_x_1 <= 5; block_y_1 <= 0;
                    block_x_2 <= 3; block_y_2 <= 1;
                    block_x_3 <= 4; block_y_3 <= 1;
                end
                3'b110: begin // J block
                    block_x_0 <= 4; block_y_0 <= 1;
                    block_x_1 <= 5; block_y_1 <= 1;
                    block_x_2 <= 6; block_y_2 <= 1;
                    block_x_3 <= 6; block_y_3 <= 0;
                end
            endcase 
            shape_ld_reg <= 1;
            
            shape_data_in <= (shape_data_out == 3'b110) ? 3'b000 : shape_data_out + 1;
            next_shape    <= (shape_data_out == 3'b110) ? 3'b000 : shape_data_out + 1;
     end
    
    if (reset) begin
        // Initialize the grid
        for (int y = 0; y < GRID_HEIGHT; y++) begin
            for (int x = 0; x < GRID_WIDTH; x++) begin
                grid[y][x] <= 0;
            end
        end
        
    end else begin
            if (!game_over) begin
                if ((keycode == 8'h07) && (keycode != prev_keycode)) begin // RIGHT SHIFT
                    if ((block_x_0 < (GRID_WIDTH - 1)) && (block_x_1 < (GRID_WIDTH - 1)) && (block_x_2 < (GRID_WIDTH - 1)) && (block_x_3 < (GRID_WIDTH - 1))) begin 
                        block_x_0 <= block_x_0 + 1;
                        block_x_1 <= block_x_1 + 1;
                        block_x_2 <= block_x_2 + 1;
                        block_x_3 <= block_x_3 + 1;
                    end
                end
                 else if ((keycode == 8'h04) && (keycode != prev_keycode)) begin // LEFT SHIFT
                    if ((block_x_0 > 0) && (block_x_1 > 0) && (block_x_2 > 0) && (block_x_3 > 0)) begin 
                        block_x_0 <= block_x_0 - 1;
                        block_x_1 <= block_x_1 - 1;
                        block_x_2 <= block_x_2 - 1;
                        block_x_3 <= block_x_3 - 1;
                    end
                end else if ((keycode == 8'h16) && (keycode != prev_keycode) && !game_over) begin // HARD DROP
                    
                    block_y_0 <= block_y_0 + final_drop_dist; block_y_1 <= block_y_1 + final_drop_dist;
                    block_y_2 <= block_y_2 + final_drop_dist; block_y_3 <= block_y_3 + final_drop_dist;
                    
                    grid[block_y_0 + final_drop_dist][block_x_0] <= {1'b1, shape_data_out};
                    grid[block_y_1 + final_drop_dist][block_x_1] <= {1'b1, shape_data_out};
                    grid[block_y_2 + final_drop_dist][block_x_2] <= {1'b1, shape_data_out};
                    grid[block_y_3 + final_drop_dist][block_x_3] <= {1'b1, shape_data_out};
                    
                    
                    for (int x = 0; x < GRID_WIDTH; x++) begin
                        if (grid[2][x][3]) begin // bit 3 indicates occupancy
                            game_over <= 1;
                        end
                    end
                        
                    spawn_ld_reg <= 1'b1;
                    spawn_data_in <= 1'b1;
                    block_dropped <= 1'b1;
                    lock_block <= 1'b1;
                    
                end else if ((keycode == 8'h2C) && (keycode != prev_keycode)) begin // ROTATION LOGIC
                    
                    block_x_0 <= new_block_x_0;
                    block_x_1 <= rot_x1; block_y_1 <= rot_y1;
                    block_x_2 <= rot_x2; block_y_2 <= rot_y2;
                    block_x_3 <= rot_x3; block_y_3 <= rot_y3;
                    
                end
                prev_keycode <= keycode;
    
                fall_rate <= fall_rate + 1;
                if (fall_rate >= FALL_SPEED) begin // GRAVITY/FALLING LOGIC
                    fall_rate <= 0;
                        if (!game_over && ((block_y_0 == GRID_HEIGHT-1 || grid[block_y_0+1][block_x_0]) ||
                            (block_y_1 == GRID_HEIGHT-1 || grid[block_y_1+1][block_x_1]) ||
                            (block_y_2 == GRID_HEIGHT-1 || grid[block_y_2+1][block_x_2]) ||
                            (block_y_3 == GRID_HEIGHT-1 || grid[block_y_3+1][block_x_3]))) begin
                                
                                grid[block_y_0][block_x_0] <= {1'b1, shape_data_out};
                                grid[block_y_1][block_x_1] <= {1'b1, shape_data_out};
                                grid[block_y_2][block_x_2] <= {1'b1, shape_data_out};
                                grid[block_y_3][block_x_3] <= {1'b1, shape_data_out};
                                
                                game_over <= 0;
                                for (int x = 0; x < GRID_WIDTH; x++) begin
                                    if (grid[2][x][3]) begin // bit 3 indicates occupancy
                                        game_over <= 1;
                                    end
                                end
                        
                                spawn_ld_reg <= 1'b1;
                                spawn_data_in <= 1'b1;
                                block_dropped <= 1'b1;
                                lock_block <= 1'b1;
                                
                        end else begin
                            block_y_0 <= block_y_0 + 1;
                            block_y_1 <= block_y_1 + 1;
                            block_y_2 <= block_y_2 + 1;
                            block_y_3 <= block_y_3 + 1;
                        end
                end  
                if (block_dropped) begin
                    for (int y = 0; y < GRID_HEIGHT; y++) begin
                        row_full = 1;
                        for (int x = 0; x < GRID_WIDTH; x++) begin 
                            if (grid[y][x] == 0) begin 
                                row_full = 0;
                            end
                        end
                        
                        if (row_full) begin
                            score <= score + 100; 
                            for (int k = y; k >= 0; k--) begin 
                                for (int x = 0; x < GRID_WIDTH; x++) begin 
                                    grid[k][x] <= grid[k-1][x];
                                end
                            end
                            
                            y <= y - 1;
                            
                        end
                    end
                 end
            end
        
          
    end
end
    
endmodule
