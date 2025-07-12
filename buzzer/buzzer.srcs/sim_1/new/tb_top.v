`timescale 1ns / 1ps

module top_tb();

    reg clk = 0;
    reg reset = 1;
    reg [4:0] btn = 5'b0;
    reg [1:0] motor_direction = 2'b00;
    wire PWM_OUT;
    wire [1:0] in1_in2;
    wire [15:0] led;
    wire [3:0] an;
    wire [7:0] seg;
    wire buzzer;
    wire servo;

    // DUT
    top uut(
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .motor_direction(motor_direction),
        .PWM_OUT(PWM_OUT),
        .in1_in2(in1_in2),
        .led(led),
        .an(an),
        .seg(seg),
        .buzzer(buzzer),
        .servo(servo)
    );

    // 100MHz clock
    always #5 clk = ~clk;

    initial begin
        #100; 
        reset = 0;  // 리셋 

        press_btn(1);  // BTN_UP
        #2_00_000_000

        press_btn(4);
        #2_00_000_000 

        press_btn(1);  // BTN_UP
        #2_00_000_00

        press_btn(4);
        #2_00_000_00  

        $finish;
    end

    task press_btn(input [2:0] btn_index);
    begin
        btn[btn_index] = 1;
        #2_000_000_0;
        btn[btn_index] = 0;
    end
    endtask

endmodule
