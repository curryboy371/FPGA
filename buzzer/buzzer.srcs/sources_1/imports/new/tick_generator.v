`timescale 1ns / 1ps

 module tick_generator (
    input clk,
    input reset,
    output reg tick
 );   

    parameter INPUT_FREQ = 100_000_000;
    parameter TICK_HZ = 1000;  
    parameter TICK_COUNT =  INPUT_FREQ / TICK_HZ;   // 100_000

    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter =0;  // 16 bits

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_tick_counter <= 0;
            tick <= 0;
        end else begin
            if ( r_tick_counter == TICK_COUNT-1  ) begin
                r_tick_counter <= 0;
                tick <= 1'b1;
            end else begin
                r_tick_counter = r_tick_counter + 1;
                tick <= 1'b0;
            end 
        end 
    end 
endmodule


module tick_generator_1s #(
    parameter TICK_COUNT = 100_000_000 // 1초 @100MHz
)(
    input clk,
    input reset,
    output reg tick_1s,   // 1사이클 pulse
    output reg toggle_1s  // 토글 유지
);

    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tick_counter <= 0;
            tick_1s <= 0;
            toggle_1s <= 0;
        end else begin
            if (r_tick_counter == TICK_COUNT-1) begin
                r_tick_counter <= 0;
                tick_1s <= 1'b1;
                toggle_1s <= ~toggle_1s; // 토글
            end else begin
                r_tick_counter <= r_tick_counter + 1;
                tick_1s <= 1'b0;
            end
        end
    end
endmodule