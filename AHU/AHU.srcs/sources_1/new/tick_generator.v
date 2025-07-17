`timescale 1ns / 1ps

 module tick_generator #(
    parameter integer INPUT_FREQ = 100_000_000, // 100Mhz
    parameter integer TICK_HZ = 1000            // 1000Hz  => 1ms

 ) (
    input clk,
    input reset,
    output reg tick,
    output reg toggle  // 토글 유지
 );   

    //parameter INPUT_FREQ = 100_000_000;
    //parameter TICK_HZ = 1000;  
    parameter TICK_COUNT =  INPUT_FREQ / TICK_HZ;   // 100_000

    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter =0;  // 16 bits

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_tick_counter <= 0;
            tick <= 0;
            toggle <= 0;
        end else begin
            if ( r_tick_counter == TICK_COUNT-1  ) begin
                r_tick_counter <= 0;
                tick <= 1'b1;
                toggle <= ~toggle; // 토글
            end else begin
                r_tick_counter <= r_tick_counter + 1;
                tick <= 1'b0;
            end 
        end 
    end 
endmodule
