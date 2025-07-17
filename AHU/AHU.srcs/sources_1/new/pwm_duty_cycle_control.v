`timescale 1ns / 1ps

//----------------- pwm_duty_cycle_control ---------------------
module pwm_duty_cycle_control (
    input clk,
    input [3:0] duty_cycle,  // 0 ~ 9
    output PWM_OUT           // 10MHz PWM output signal
); 

    reg [3:0] r_counter_PWM = 0;

    // 100MHz 기준 10MHz PWM (10분주)
    always @(posedge clk) begin
        if (r_counter_PWM >= 9)
            r_counter_PWM <= 0;
        else
            r_counter_PWM <= r_counter_PWM + 1;
    end

    assign PWM_OUT = (r_counter_PWM < duty_cycle) ? 1 : 0;

endmodule
