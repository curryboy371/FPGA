`timescale 1ns / 1ps

module uart_rx(
    input clk,
    input reset,
    input rx,
    output reg [7:0] data_out,
    output reg rx_done
    );

    parameter
        IDLE = 2'b00,
        START_BIT = 2'b01,
        DATA_BITS = 2'b10,
        STOP_BIT = 2'b11;

    parameter integer DIVIDER_COUNT = 100_000_000 / (9600 * 16);

    reg [2:0] r_state;
    reg [3:0] r_bit_cnt; // r_data_reg에 들어갈 index값
    reg [7:0] r_data_reg; //rx포트로 부터들어온 bit를 담을 그릇
    reg [15:0] r_baud_cnt; // 651 : 9600 오버샘플링 count변수
    reg r_baud_tick;
    reg [3:0] r_baud_tick_cnt; // 16개 오버샘플링값 count

    // 오버샘플링 tick 생성: DIVIDER_COUNT마다 1클럭 HIGH
    always @(posedge clk or posedge reset) begin
        if(reset)
        begin
            r_baud_cnt <= 0;
            r_baud_tick <= 0;
        end
        else
        begin
            if(r_baud_cnt == DIVIDER_COUNT - 1)
            begin
                r_baud_cnt <= 0;
                r_baud_tick <= 1;
            end
            else
            begin
                r_baud_tick <= 0;
                r_baud_cnt <= r_baud_cnt + 1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if(reset)
        begin
            r_state <= IDLE;
            data_out <= 0;
            rx_done <= 0;
            r_bit_cnt <= 0;
            r_data_reg <= 0;
            r_baud_tick_cnt <= 0;
        end
        else
        begin
            case(r_state)
             // 1. 대기 상태: start bit 감지
            IDLE:begin
                rx_done <= 0;
                if(!rx) // start bit (0) 감지
                begin
                    r_state <= START_BIT;
                    r_baud_tick_cnt <= 4'd0;
                end
                else
                begin
                    r_state <= IDLE;
                end
            end
            // 2. START_BIT 상태: 16샘플 중 15번째 클럭에서 비트 확정
            START_BIT:begin
                if(r_baud_tick)
                begin
                    r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                    if(r_baud_tick_cnt + 1 == 4'd15) // 16번 모았으면 1비트 (START_BIT) 수신
                    begin
                        r_state <= DATA_BITS;
                        r_bit_cnt <= 0;
                        r_baud_tick_cnt <= 0;
                    end
                end
            end
            // 3. DATA_BITS 상태: 8비트 수신
            DATA_BITS:begin
                if(r_baud_tick)
                begin
                    r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                    if(r_baud_tick_cnt + 1 == 4'd15) // 16번 모았으면 1비트 수신
                    begin
                        r_data_reg[r_bit_cnt] <= rx;
                        r_baud_tick_cnt <= 0;
                        if(r_bit_cnt == 4'd7) // 1 Byte 수신
                        begin
                            r_state <= STOP_BIT;
                        end
                        else
                        begin
                            r_bit_cnt <= r_bit_cnt + 1;
                        end
                    end
                end
            end
            // 4. STOP_BIT 상태: 정지 비트 수신 후 완료 처리
            STOP_BIT:begin
                if(r_baud_tick)
                begin
                    r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                    if(r_baud_tick_cnt + 1 == 4'd15) // 16번 모았으면 1비트 (STOP_BIT)수신
                    begin
                        r_state <= IDLE;
                        data_out <= r_data_reg;
                        rx_done <= 1;
                        r_baud_tick_cnt <= 0;
                    end
                end
            end
            // default. 초기 상태로 복귀
            default:begin
                r_state <= IDLE;
                r_baud_tick_cnt <= 0;
                r_bit_cnt <= 0;
                rx_done <= 0;
            end
            endcase
        end
    end
endmodule
