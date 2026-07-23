# FPGA Tetris
Tetris implemented in hardware on a Xilinx FPGA: SystemVerilog game logic, a VGA display pipeline with HDMI output, and USB keyboard control through a MicroBlaze soft processor. Fully playable: piece movement, 90° rotation, hard drop, line clearing, per-piece colors, and a game-over screen. Driven by custom RTL synchronized to the display's frame rate.

<img width="534" height="410" alt="Screenshot 2026-07-23 at 11 38 57 AM" src="https://github.com/user-attachments/assets/b378538e-e94d-4cbf-a09e-acfca192ded8" />
*FPGA Demo*

<img width="657" height="306" alt="Screenshot 2026-07-23 at 11 36 53 AM" src="https://github.com/user-attachments/assets/238b6821-57b5-4c5f-8179-0ff22e3d4e96" />
*System Block Diagram*

The system has three domains working together:

**Game logic (custom RTL):** The playfield is modeled as a 2D grid register array rather than sprite objects — each cell holds an occupancy/color state, and the tetris_grid module updates the grid once per frame (synchronized to VSync): interpreting keycodes, moving and rotating the active tetromino, detecting collisions, clearing completed lines, and accumulating a 16-bit score driven out to the board's seven-segment displays. We initially prototyped a sprite-based approach and rewrote around the grid model, which made drawing, collision detection, and line clearing dramatically simpler.

**Display pipeline:** A VGA controller generates 640×480 timing from a 25 MHz pixel clock (sync pulses, blanking, pixel coordinates). Background and game-over screens are stored as palette-indexed images in block RAM at 320×240 and scaled 2× at scan-out — index lookup on the negative clock edge, palette-to-RGB mapping on the positive edge — which halves the memory footprint versus storing raw RGB. Game content is overlaid on the background per-pixel, and the final RGB stream is serialized to HDMI (TMDS).

**Input path:** A USB keyboard connects through a MAX3421E USB host controller, which the MicroBlaze soft processor drives over SPI (AXI Quad SPI). Keycodes are passed from software to the game logic through AXI GPIO registers, with an AXI interrupt controller coordinating USB and timer events.

## Implementation Results

| Resource | Utilization |
|---|---|
| LUTs | 17,052 |
| Flip-flops | 3,591 |
| BRAM | 58.5 blocks |
| DSP slices | 6 |
| Total power | 0.489 W (0.078 static / 0.411 dynamic) |

## Verification

RTL modules were verified with SystemVerilog testbenches, and the USB/SPI input path was debugged on hardware with a logic analyzer — capturing SPI transactions to the MAX3421E to isolate protocol timing faults between MicroBlaze register accesses and the USB controller.


