//-------------------------------------------------------------------------
//    mb_usb_hdmi_top.sv                                                 --
//    Zuofu Cheng                                                        --
//    2-29-24                                                            --
//                                                                       --
//                                                                       --
//    Spring 2024 Distribution                                           --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------


module mb_usb_hdmi_top(
    input logic Clk,
    input logic reset_rtl_0,
    
    //USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
    
    //UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    //HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
        
    //HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB
);
    
    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk, clk_100MHz;
    logic locked;
    logic [9:0] drawX, drawY, blockxsig, blockysig, blocksizesig;

    logic hsync, vsync, vde;
    logic [3:0] red, green, blue, bg_red, bg_green, bg_blue, end_red, end_green, end_blue;
    logic reset_ah;
    logic [15:0] score;
    
    assign reset_ah = reset_rtl_0;
    assign clk_100MHz = Clk;
    
    hex_driver hex_drive_instance(
        .clk(clk_100MHz),
        .reset(reset_ah),
    
        .in({score[15:12], score[11:8], score[7:4], score[3:0]}),
    
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
);
    
    mb_block mb_block_i (
        .clk_100MHz(clk_100MHz),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_ah), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
        
    //clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(clk_100MHz)
    );
    
    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    
    
    tetris_background_example tetris_background(
        .vga_clk(clk_25MHz),
        .DrawX(drawX), 
        .DrawY(drawY),
        .blank(1'b1),
        .red(bg_red), 
        .green(bg_green), 
        .blue(bg_blue)
    );
    
    game_over_example game_over_insta(
        .vga_clk(clk_25MHz),
        .DrawX(drawX), 
        .DrawY(drawY),
        .blank(1'b1),
        .red(end_red), 
        .green(end_green), 
        .blue(end_blue)
    );

    tetris_grid tetris_grid_inst(
        .drawX(drawX), 
        .drawY(drawY), 
        .frame_clk(vsync), 
        .reset(reset_ah), 
        .keycode(keycode0_gpio[7:0]), 
        .bg_red(bg_red), 
        .bg_green(bg_green), 
        .bg_blue(bg_blue),
        .end_red(end_red), 
        .end_green(end_green),
        .end_blue(end_blue), 
       
        .red(red), 
        .green(green), 
        .blue(blue), 
        .score(score)
    );
    
    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        //Reset is active LOW
        .rst(reset_ah),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );

endmodule
