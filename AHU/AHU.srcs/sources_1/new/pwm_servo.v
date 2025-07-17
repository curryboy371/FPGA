`timescale 1ns / 1ps

module pwm_servo(
    input clk,        
    input reset,      
    input [7:0] angle, // 0~180
    output reg pwm_out
);

    // 1ms → 0도
    // 1.5ms → 90도
    // 2ms → 180도
    parameter PWM_PERIOD = 2_000_000;  // 20ms @100MHz
    parameter MIN_PULSE  = 100_000;    // 1ms @100MHz
    parameter MAX_PULSE  = 200_000;    // 2ms @100MHz

    reg [19:0] cnt = 0;
    reg [19:0] pulse_width = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt <= 0;
            pwm_out <= 0;
        end else begin
            if (cnt < PWM_PERIOD - 1)
                cnt <= cnt + 1;
            else
                cnt <= 0;

            // pwm 파형 생성함
            // pulse_width 보다 cnt가 작으면 HIGH, 크면 LOW
            pwm_out <= (cnt < pulse_width) ? 1 : 0;
        end
    end

    // angle -> pulse width 계산
    // pulse_width = MIN_PULSE + (angle * (MAX_PULSE - MIN_PULSE) / 180)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pulse_width <= MIN_PULSE;
        end else begin
            pulse_width <= MIN_PULSE + ((angle * (MAX_PULSE - MIN_PULSE)) / 180);
        end
    end
endmodule