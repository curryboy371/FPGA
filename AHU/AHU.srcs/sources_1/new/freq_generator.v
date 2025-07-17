`timescale 1ns / 1ps

module freq_generator (
    input clk,
    input reset,
    input [20:0] clk_div,
    output reg buzzer
);
    reg [20:0] frequency_counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            frequency_counter <= 0;
            buzzer <= 0;
        end else if (clk_div == 0) begin
            frequency_counter <= 0;
            buzzer <= 0;
        end else begin
            if (frequency_counter >= clk_div - 1) begin
                frequency_counter <= 0;
                buzzer <= ~buzzer;
            end else begin
                frequency_counter <= frequency_counter + 1;
            end
        end
    end
endmodule