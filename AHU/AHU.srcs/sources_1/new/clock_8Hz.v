`timescale 1ns / 1ps

module clock_8Hz(
    input i_clk,    // 100MHz
    input i_reset,
    output reg o_clk8Hz   // 8Hz
    );

    reg [19:0] i_count=0;

    always @(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin // 0-->1 비동기 reset 
            o_clk8Hz <= 0;
            i_count <= 0;
        end else begin
            if (i_count == (1_250_000/2)-1) begin  // 8Hz 12_500_000 /2 --> 62500 125_000
                i_count <= 0;
                o_clk8Hz <= ~o_clk8Hz;
            end begin
                i_count <= i_count + 1;
            end
        end
    end
endmodule
