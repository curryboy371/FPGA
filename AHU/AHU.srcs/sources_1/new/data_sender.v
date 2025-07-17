`timescale 1ns / 1ps

module data_sender(
    input clk, 
    input reset,
    input start_trigger,
    input [13:0] send_data,
    input tx_busy,
    input tx_done,
    output reg tx_start,
    output reg [7:0] tx_data
    );
    
    reg [2:0] r_num_index = 0;

    reg [3:0] d1;
    reg [3:0] d10;
    reg [3:0] d100;
    reg [3:0] d1000;

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            tx_start <= 0;
            tx_data <= 0;
            r_num_index <= 0;
            d1 <= 0;
            d10 <= 0;
            d100 <= 0;
            d1000 <= 0;
        end
        else begin
            if(start_trigger && !tx_busy) begin
                // 자릿수만 갱신 (tx_start은 아직 안 켬)
                d1 <= send_data % 10;
                d10 <= (send_data / 10) % 10;
                d100 <= (send_data / 100) % 10;
                d1000 <= (send_data / 1000) % 10;

                r_num_index <= 1;  // 다음 tx_done부터 전송
                tx_start <= 1;
                tx_data <= 0;
            end
            else if (tx_done) begin
                if(r_num_index == 0) begin
                    tx_start <= 0;
                end
                else if(r_num_index == 6) begin
                    r_num_index <= 0;
                    tx_start <= 0;
                end
                else begin
                    // 전송
                    tx_start <= 1;

                    case (r_num_index)
                        3'd1: tx_data <= "0" + d1000;
                        3'd2: tx_data <= "0" + d100;
                        3'd3: tx_data <= "0" + d10;
                        3'd4: tx_data <= "0" + d1;
                        3'd5: tx_data <= " ";
                        default: tx_data <= "0";
                    endcase

                    r_num_index <= r_num_index + 1;
                end
            end
            else begin
                tx_start <= 0;
            end
        end
    end

endmodule
