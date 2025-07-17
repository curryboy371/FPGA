`timescale 1ns / 1ps

// baudrate를 유동적으로 사용할 수 있게 parameter로 받아 사용
module uart_tx # ( 
    parameter BAUD_RATE = 9600
)
(
    input clk, 
    input reset,
    input [7:0] tx_data,
    input tx_start,

    // 기존 출력 정보를 유지하므로 reg
    output reg tx,
    output reg tx_busy,
    output reg tx_done

    );

    // 상태 설정
    parameter 
        IDLE = 2'b00,
        START_BIT = 2'b01,
        DATA_BITS = 2'b10,
        STOP_BIT = 2'b11;


    // 1bit 전송 주기
    // 9600bps인 경우 10416...
    parameter DIVIDER_COUNTER = 100_000_000 / BAUD_RATE;

    reg [15:0] r_baud_cnt; // 10416 ns count
    reg r_baud_tick; // 10416ns 마다 1 tick 발생
    reg [1:0] r_state;      // state
    reg [3:0] r_bit_cnt;    // bit count to transmission    
    reg [7:0] r_data_reg;   // 전송할 byte



    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_baud_cnt <= 0;
            r_baud_tick <= 0;
        end
        else begin
            if(r_baud_cnt == DIVIDER_COUNTER -1) begin

                r_baud_cnt<=0;
                r_baud_tick<=1;

            end
            else begin
                r_baud_cnt <= r_baud_cnt + 1;
                r_baud_tick <= 0;
            end

        end
    end




    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_state <= IDLE;

            r_bit_cnt <= 0;
            r_data_reg <= 0;
            tx_busy <= 0;
            tx_done <= 0;

            tx <= 1; // idle high

        end

        else begin
            case (r_state)

                IDLE: begin
                    tx_done <= 0;
                    if(tx_start) begin
                        r_state <= START_BIT;
                        r_data_reg <= tx_data;  // tx data 복사
                        tx_busy <= 1;   // 전송 start
                        r_bit_cnt <= 0; // bit count clear
                    end
                
                end

                START_BIT: begin
                    if(r_baud_tick == 1) begin // tick이 posedge일 때
                        tx <= 1'b0; // start bit
                        r_state <= DATA_BITS;
                    end

                end

                DATA_BITS: begin
                    if(r_baud_tick) begin
                        tx <= r_data_reg[r_bit_cnt];
                        if(r_bit_cnt == 7) begin
                            r_state <= STOP_BIT;
                        end
                        else begin
                            r_bit_cnt <= r_bit_cnt +1;
                        end
                    end
                
                end

                STOP_BIT: begin
                    if(r_baud_tick) begin
                        tx <= 1; // stop bit
                        tx_busy <= 0; // 전송 중단
                        r_state <= IDLE;
                        
                        tx_done <= 1;

                    end
                
                end

                default: begin
                    r_state <= IDLE;
                
                end
            endcase
            

        end


    end



endmodule
