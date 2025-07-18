`timescale 1ns / 1ps

module hc_sr04(
    input clk,        
    input reset,
    input start,
    input echo,
    output reg enable,              // 사용 가능 여부 ( active high )
    output reg trigger,
    output [15:0] led,
    output reg [13:0] distance
    );

    // 상태 파라미터
    localparam IDLE = 3'b001;            // 대기상태
    localparam TRIGGER = 3'b010;         // 트리거 진행상태
    localparam ECHO = 3'b011;            // ECHO 진행상태
    localparam ECHO_BACK = 3'b100;       // ECHO 돌아온 상태
    localparam ECHO_FAILED = 3'b101;     // ECHO 돌아오지 못함 ( 측정실패 )
    localparam COOL_TIME = 3'b111;       // 실행 후 cool time 대기 ( 60ms)


    // 상수값 설정
    localparam TRIGGER_US = 15;
    localparam MAX_ECHO_US = 38000; // 38ms 38000us     측청 가능 최대 거리
    //localparam COOL_TIME_US = 80000; // 80ms 80000us    cool time
    localparam COOL_TIME_US = 1000000; // 1s 1000000us    cool time


    reg [2:0] debug_state; // 디버그용 상태 저장

    reg [2:0] hc_sr04_state = IDLE; // 초음파 모듈 상태

    wire w_tick_us;
    tick_generator #(.TICK_HZ(1000000)) u_us_tick ( // 1us @100MHz
        .clk(clk),
        .reset(reset),
        .tick(w_tick_us),
        .toggle(toggle_us)
    );

    reg [$clog2(COOL_TIME_US)-1:0] r_us_count =0; 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hc_sr04_state <= IDLE;
            r_us_count <= 0;
            distance <= 0;
            enable <= 1;
        end else begin

            case(hc_sr04_state)
                IDLE: begin
                    if(start && enable) begin 
                        r_us_count <= 0;
                        hc_sr04_state <= TRIGGER;
                        trigger <= 1;
                        enable <= 0;
                        
                    end
                end
                TRIGGER: begin 
                    if(w_tick_us) begin 
                        if(r_us_count == TRIGGER_US - 1) begin
                            r_us_count <= 0;
                            trigger <= 0; // 트리거 종료
                            hc_sr04_state <= ECHO;
                        end
                        else begin
                            r_us_count <= r_us_count + 1;
                        end
                    end

                end
                ECHO: begin
                    if (echo) begin // echo 시작 시점부터 카운트
                        r_us_count <= 0; 
                        hc_sr04_state <= ECHO_BACK;
                    end else if (w_tick_us) begin
                        r_us_count <= r_us_count + 1;
                        if (r_us_count == MAX_ECHO_US - 1) begin
                            debug_state <= ECHO;
                            hc_sr04_state <= ECHO_FAILED;
                        end
                    end
                end
                ECHO_BACK: begin
                    if (w_tick_us) begin
                        if (echo) begin
                            r_us_count <= r_us_count + 1;
                            if (r_us_count == MAX_ECHO_US - 1) begin
                                debug_state <= ECHO_BACK;
                                hc_sr04_state <= ECHO_FAILED;
                            end
                        end else begin
                            // echo falling edge → 거리 계산
                            //distance <= (r_us_count * 17) >> 10;
                            distance <= r_us_count / 58;
                            r_us_count <= 0;
                            hc_sr04_state <= COOL_TIME;
                        end
                    end
                end

                ECHO_FAILED: begin
                    distance <= 9999;
                    r_us_count <= 0;
                    hc_sr04_state <= COOL_TIME;
                end

                COOL_TIME: begin
                    if(w_tick_us) begin
                        r_us_count <= r_us_count + 1;
                        if(r_us_count == COOL_TIME_US - 1) begin
                            hc_sr04_state <= IDLE;
                            enable <= 1;
                        end
                    end
                end

                default: begin 
                    hc_sr04_state <= IDLE;
                end
            endcase
        end
    end

    assign led[2:0] = debug_state; // LED 3개에 상태 보여주기
    assign led[5:3] = hc_sr04_state; // LED 3개에 상태 보여주기
endmodule

