`timescale 1ns / 1ps

module hc_sr04 (
    input clk,
    input reset,
    input start,
    input echo,
    output reg enable,              // 사용 가능 여부 ( active high )
    output reg trigger,             // 트리거 신호
    output [15:0] led,
    output reg [13:0] distance      // 단위: cm
);

    // 상태 정의
    localparam IDLE         = 3'b001;
    localparam TRIGGER      = 3'b010;
    localparam ECHO         = 3'b011;
    localparam ECHO_BACK    = 3'b100;
    localparam ECHO_FAILED  = 3'b101;
    localparam COOL_TIME    = 3'b111;

    // 타이밍 상수
    localparam TRIGGER_US     = 10;
    localparam MAX_ECHO_US    = 38000;     // 38ms
    localparam COOL_TIME_US   = 60000;   // 60ms
    //localparam COOL_TIME_US   = 1000000;   // 1초 쿨타임

    // 내부 레지스터
    reg [2:0] hc_sr04_state = IDLE;
    reg [2:0] debug_state = IDLE;

    reg [$clog2(COOL_TIME_US)-1:0] r_us_count = 0;

    wire w_tick_us;
    tick_generator #(.TICK_HZ(1000000)) u_us_tick (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_us),
        .toggle(toggle_us)
    );

    // FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hc_sr04_state <= IDLE;
            debug_state <= IDLE;
            r_us_count <= 0;
            distance <= 0;
            trigger <= 0;
            enable <= 1;
        end else begin
            case (hc_sr04_state)

                IDLE: begin
                    if (start && enable) begin
                        trigger <= 1;
                        r_us_count <= 0;
                        enable <= 0;
                        hc_sr04_state <= TRIGGER;
                    end
                end

                TRIGGER: begin
                    if (w_tick_us) begin
                        if (r_us_count >= TRIGGER_US) begin
                            trigger <= 0;
                            r_us_count <= 0;
                            hc_sr04_state <= ECHO;
                        end else begin
                            r_us_count <= r_us_count + 1;
                        end
                    end
                end

                ECHO: begin
                    if (echo) begin
                        r_us_count <= 0;
                        hc_sr04_state <= ECHO_BACK;
                    end else if (w_tick_us) begin
                        r_us_count <= r_us_count + 1;
                        if (r_us_count >= MAX_ECHO_US) begin
                            distance <= 9996;
                            debug_state <= ECHO;
                            hc_sr04_state <= ECHO_FAILED;
                        end
                    end
                end

                ECHO_BACK: begin
                    if (w_tick_us) begin
                        if (echo) begin
                            r_us_count <= r_us_count + 1;
                            if (r_us_count >= MAX_ECHO_US) begin
                                distance <= 9997;
                                debug_state <= ECHO_BACK;
                                hc_sr04_state <= ECHO_FAILED;
                            end
                        end else begin
                            // 거리 계산 (음속 기준 58로 나눔)
                            if( r_us_count < 58) begin
                                debug_state <= ECHO_BACK;
                                distance <= 9998;
                                hc_sr04_state <= ECHO_FAILED;
                            end
                            else begin
                                hc_sr04_state <= COOL_TIME;
                                distance <= (r_us_count >> 6) + (r_us_count >> 7); // 대략 /58
                                //distance <= r_us_count / 58;
                            end
                            r_us_count <= 0;
                        end
                    end
                end

                ECHO_FAILED: begin
                    r_us_count <= 0;
                    hc_sr04_state <= COOL_TIME;
                end

                COOL_TIME: begin
                    if (w_tick_us) begin
                        r_us_count <= r_us_count + 1;
                        if (r_us_count >= COOL_TIME_US) begin
                            hc_sr04_state <= IDLE;
                            trigger <= 0;
                            r_us_count <= 0;
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

    assign led[2:0] = debug_state;
    assign led[5:3] = hc_sr04_state;

endmodule
