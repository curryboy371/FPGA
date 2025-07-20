`timescale 1ns / 1ps

module oven (
    input clk,
    input reset,
    input tick,
    input tick_1s,
    input toggle_1s,
    input [4:0] clean_btn_edge,
    input [1:0] motor_direction,
    output PWM_OUT,
    output [1:0] in1_in2,
    output [15:0] led,
    output [3:0] an,
    output [7:0] seg,
    output buzzer,
    output servo
);

    parameter BTN_CENTER = 3'd0;
    parameter BTN_UP = 3'd1;        // 오픈
    parameter BTN_LEFT = 3'd2;      // 모터 파워 다운
    parameter BTN_RIGHT = 3'd3;     // 모터 파워 UP
    parameter BTN_DOWN = 3'd4;      // 클로즈
    parameter BTN_MAX = 3'd5;

    //  메인 모드..
    // bit flag로 ( led 확인 쉽게할라구)
    parameter RESET      = 5'b00000;
    parameter IDLE       = 5'b00001;
    parameter TIME_SETUP = 5'b00010;
    parameter RUNNING    = 5'b00100;
    parameter FINISHED   = 5'b01000;
    parameter PAUSED     = 5'b10000;

    // door 상태
    parameter DOOR_CLOSED = 1'b0;
    parameter DOOR_OPEN   = 1'b1;

    parameter DEFAULT_TIME = 5;
    parameter MIN_TIME = 5;  // 
    parameter MAX_TIME = 600; // 

    parameter FINISH_WAIT_SEC = 5;

    reg door_state = DOOR_CLOSED;

    reg [4:0] oven_state = IDLE;

    reg [12:0] oven_time = 0;

    reg [4:0] finish_wait = 5; 

    reg [3:0] r_duty_cycle; // 1~10

    wire w_done_cycle;  // 부저 완료 sign ( 버튼 입력 딜레이로 사용함)

    // 전자레인지 상태에 따른 입력 및 time 처리
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            oven_state <= RESET;
            r_duty_cycle <=0;
            door_state <= DOOR_OPEN;

        end else begin
            case (oven_state)
                IDLE: begin
                    if(door_state == DOOR_CLOSED) begin 

                        if(w_done_cycle) begin
                            if(clean_btn_edge[BTN_CENTER]) begin
                                oven_state <= TIME_SETUP;
                                oven_time <= DEFAULT_TIME;

                                finish_wait <= FINISH_WAIT_SEC;
                            end
                        end
                    end
                end
                TIME_SETUP: begin
                    if(door_state == DOOR_CLOSED) begin 

                        if(w_done_cycle) begin

                            if(clean_btn_edge[BTN_RIGHT]) begin
                                if (oven_time + MIN_TIME <= MAX_TIME)
                                    oven_time <= oven_time + MIN_TIME;
                                else
                                    oven_time <= MAX_TIME; 
                            end

                            if(clean_btn_edge[BTN_LEFT]) begin
                                if (oven_time >= MIN_TIME + MIN_TIME)
                                    oven_time <= oven_time - MIN_TIME;
                                else
                                    oven_time <= MIN_TIME;
                            end

                            if(clean_btn_edge[BTN_CENTER]) begin
                                oven_state <= RUNNING;
                            end
                        end
                    end

                end
                RUNNING: begin

                    if(door_state == DOOR_CLOSED) begin 
                        r_duty_cycle <=7;
                        if(tick_1s) begin
                            if(oven_time <= 0) begin
                                oven_state <= FINISHED;
                            end
                            else begin
                                oven_time <= oven_time - 1;
                            end
                        end

                        // 일시정지 버튼
                        if(w_done_cycle) begin
                            if(clean_btn_edge[BTN_CENTER]) begin
                                oven_state <= PAUSED;
                            end
                        end

                    end
                    else begin 
                        r_duty_cycle <=0;
                    end

                end

                PAUSED: begin
                    r_duty_cycle <=0;
                    if(door_state == DOOR_CLOSED) begin 
                        if(w_done_cycle) begin
                            // 취소 버튼
                            if(clean_btn_edge[BTN_CENTER]) begin
                                oven_state <= IDLE;
                            end

                            // 시간 입력버튼 누르면 다시 동작
                            if(clean_btn_edge[BTN_RIGHT] || clean_btn_edge[BTN_LEFT]) begin
                                oven_state <= RUNNING;
                            end

                            // 완전히 취소 버튼
                            if(clean_btn_edge[BTN_CENTER]) begin
                                oven_state <= IDLE;
                            end
                        end

                    end
                end

                FINISHED: begin
                    r_duty_cycle <=0;
                    if(finish_wait <= 0) begin
                        oven_state <= IDLE;
                    end
                    else begin
                        if(tick_1s) begin
                            finish_wait <= finish_wait -1;
                        end
                    end

                end
                RESET: begin
                    r_duty_cycle <=0;
                    oven_state <= IDLE;
                end

                default:begin

                end
            endcase
        end
    end


    // 문열고 닫기 상태 + 부저상태도
    parameter BUZZER_IDLE      = 3'b000;
    parameter CLOSE  = 3'b001;
    parameter OPEN      = 3'b010;
    parameter BUTTON      = 3'b011;
    parameter ALARM      = 3'b100;

    parameter OPEN_ANGLE = 8'd0;
    parameter CLOSE_ANGLE = 8'd180;

    reg [2:0] buzzer_pulse = BUZZER_IDLE;
    reg [7:0] angle = CLOSE_ANGLE;


    // 문 열림, 닫힘 및 부저음
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            buzzer_pulse <= BUZZER_IDLE;
            angle <= CLOSE_ANGLE;
            door_state <=DOOR_CLOSED;

        end else begin
            buzzer_pulse <= BUZZER_IDLE;

            if (w_done_cycle) begin

                if(door_state == DOOR_CLOSED) begin // 닫혀있는 경우에만 열기

                    // 버튼음 닫힌 상태에서만
                    // open, close에서는 버튼음이 안 나도록 가장 먼저
                    if (clean_btn_edge[BTN_CENTER] | clean_btn_edge[BTN_RIGHT] | clean_btn_edge[BTN_LEFT] ) begin
                        buzzer_pulse <= BUTTON;
                    end

                    if (clean_btn_edge[BTN_UP]) begin
                        door_state <= DOOR_OPEN;
                        buzzer_pulse <= OPEN;
                        angle <= OPEN_ANGLE;
                    end
                end
                else begin // 열려있는 경우에만 닫기
                    if (clean_btn_edge[BTN_DOWN]) begin
                        door_state <= DOOR_CLOSED;
                        buzzer_pulse <= CLOSE;
                        angle <= CLOSE_ANGLE;
                    end
                end


            end

            // FINISHED 종료 알림을 여기서도 검사하도록
            // oven state의 always에서 buzzer pulse를 또 <= 하면 안되므로
            if (oven_state == RUNNING && oven_time <= 0 && tick_1s) begin
                buzzer_pulse <= ALARM; // 종료 알림
            end
        end
    end

    buzzer_sequence u_buzzer_sequence (
        .clk(clk),
        .reset(reset),
        .tick(tick),
        .toggle_1s(toggle_1s),
        .buzzer_pulse(buzzer_pulse),  // BUZZER_STOP, CLOSE, OPEN
        .buzzer_done(w_done_cycle),
        .buzzer(buzzer)
    );

    oven_fnd u_oven_fnd(
        .clk(clk),
        .reset(reset), 
        .tick(tick),
        .toggle_1s(toggle_1s),
        .oven_state(oven_state),
        .oven_time(oven_time),
        .door_state(door_state),
        .seg(seg),
        .an(an)
        );

    pwm_duty_cycle_control u_pwm_duty_cycle_control (
        .clk(clk),
        .duty_cycle(r_duty_cycle),
        .PWM_OUT(PWM_OUT) 
    );
    assign in1_in2 = motor_direction;


    pwm_servo u_servo (
        .clk(clk),
        .reset(reset),
        .angle(angle),
        .pwm_out(servo)
    );


    assign led[4:0] = oven_state;
    assign led[15] = door_state;
    assign led[14] = w_done_cycle;
    assign led[13] = toggle_1s;

/////////////////////////////////////// simulation용
reg [39:0] state_str;

always @(*) begin
    case (oven_state)
        RESET:      state_str = "RESET";
        IDLE:       state_str = "IDLE ";
        TIME_SETUP: state_str = "SETUP";
        RUNNING:    state_str = "RUN  ";
        FINISHED:   state_str = "FINSH";
        PAUSED:     state_str = "PAUSE";
        default:    state_str = "UNDEF";
    endcase
end
///////////////////////////////////////


endmodule