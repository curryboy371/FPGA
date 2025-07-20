`timescale 1ns / 1ps



module sw_debouncer #(
    parameter WIDTH = 3,              // 사용할 스위치 수
    parameter CNT_MAX = 2000000        // debounce 시간
)(
    input clk,
    input reset,
    input [WIDTH-1:0] sw_in,
    output reg [WIDTH-1:0] sw_out
);

    reg [WIDTH-1:0] sw_sync_0, sw_sync_1;
    reg [$clog2(CNT_MAX):0] counter [WIDTH-1:0];

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sw_sync_0 <= 0;
            sw_sync_1 <= 0;
            sw_out <= 0;
            for (i = 0; i < WIDTH; i = i + 1)
                counter[i] <= 0;
        end else begin
            sw_sync_0 <= sw_in;
            sw_sync_1 <= sw_sync_0;
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (sw_sync_1[i] != sw_out[i]) begin
                    counter[i] <= counter[i] + 1;
                    if (counter[i] >= CNT_MAX) begin
                        sw_out[i] <= sw_sync_1[i];
                        counter[i] <= 0;
                    end
                end else begin
                    counter[i] <= 0;
                end
            end
        end
    end
endmodule