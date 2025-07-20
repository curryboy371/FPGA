`timescale 1ns / 1ps

module top(
    input clk,                 // 100MHz clock
    input reset,               // active-high reset
    input [4:0] btn,           // 버튼 입력
    input [14:0] sw,           // 스위치
    input echo,                // HC-SR04 센서 입력
    output trigger,            // HC-SR04 센서 트리거
    input RsRx,                // UART 수신
    output RsTx,               // UART 송신
    output reg PWM_OUT,            // DC 모터 제어용 PWM
    output reg [1:0] in1_in2,      // DC 모터 방향
    output reg [15:0] led,         // 디버깅용 LED
    output reg [3:0] an,           // FND 자리 선택
    output reg [7:0] seg,          // FND 세그먼트
    output reg buzzer,             // 부저 출력
    output reg servo,              // 서보모터 PWM
    inout dht11_data           // DHT11 센서 (inout)
);

    wire [2:0] sw_clean;
    sw_debouncer #(.WIDTH(3)) u_sw_debouncer (
        .clk(clk),
        .reset(reset),
        .sw_in(sw[2:0]),
        .sw_out(sw_clean)
    );


    reg [2:0] sw_mode_reg, prev_mode;
    reg [3:0] reset_cnt;
    wire soft_reset;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sw_mode_reg <= 3'b000;
            prev_mode <= 3'b000;
            reset_cnt <= 4'd0;
        end else begin
            sw_mode_reg <= sw_clean;

            if (sw_clean != prev_mode) begin
                prev_mode <= sw_clean;
                reset_cnt <= 4'd10; // 최소 10 클럭 유지
            end else if (reset_cnt != 0) begin
                reset_cnt <= reset_cnt - 1;
            end
        end
    end

    assign soft_reset = (reset || reset_cnt != 0);


    // 모드 정의
    localparam MODE_AHU   = 3'b001;
    localparam MODE_OVEN  = 3'b010;
    localparam MODE_CLOCK = 3'b100;


    localparam BTN_CENTER = 3'd0;
    localparam BTN_UP = 3'd1;        // 오픈
    localparam BTN_LEFT = 3'd2;      // 모터 파워 다운
    localparam BTN_RIGHT = 3'd3;     // 모터 파워 UP
    localparam BTN_DOWN = 3'd4;      // 클로즈
    localparam BTN_MAX = 3'd5;


    wire w_tick;
    tick_generator u_tick_generator (
        .clk(clk),           
        .reset(soft_reset),         
        .tick(w_tick)         
    );

    wire w_tick_1s;
    wire w_toggle_1s; 
    tick_generator #(.TICK_HZ(1)) u_tick_generator_1s ( // 1s @100MHz  1s : 100_000_000
    .clk(clk),
    .reset(soft_reset),
    .tick(w_tick_1s),
    .toggle(w_toggle_1s)
    );

    wire [BTN_MAX-1:0] clean_btn_edge;
    btn_edge_detector #(.WIDTH(BTN_MAX)) U_btn_edge_detector (
        .clk(clk),
        .reset(soft_reset),
        .btn(btn),
        .btn_edge(clean_btn_edge)
    );



    // Clock 출력 신호
    wire [15:0] led_clock;
    wire [3:0]  an_clock;
    wire [7:0]  seg_clock;
    wire        buzzer_clock;

    clock u_clock (
        .clk(clk),
        .reset(soft_reset), 
        .tick(w_tick),
        .tick_1s(w_tick_1s),
        .toggle_1s(w_toggle_1s),
        .clean_btn_edge(clean_btn_edge),
        .led(led_clock),
        .buzzer(buzzer_clock),
        .an(an_clock),
        .seg(seg_clock)
    );


    // AHU 출력 신호
    wire [15:0] led_ahu;
    wire [3:0]  an_ahu;
    wire [7:0]  seg_ahu;
    wire [1:0]  in1_in2_ahu;
    wire        PWM_OUT_ahu;
    wire        buzzer_ahu;
    wire        servo_ahu;

    // AHU 인스턴스
    ahu u_ahu (
        .clk(clk),
        .reset(soft_reset),
        .tick(w_tick),
        .tick_1s(w_tick_1s),
        .toggle_1s(w_toggle_1s),
        .clean_btn_edge(clean_btn_edge),
        .motor_direction(sw[14:13]),
        .echo(echo),
        .trigger(trigger),
        .RsRx(RsRx),
        .RsTx(RsTx),
        .PWM_OUT(PWM_OUT_ahu),
        .in1_in2(in1_in2_ahu),
        .led(led_ahu),
        .an(an_ahu),
        .seg(seg_ahu),
        .buzzer(buzzer_ahu),
        .servo(servo_ahu),
        .dht11_data(dht11_data)
    );

    // Oven 출력 신호
    wire [15:0] led_oven;
    wire [3:0]  an_oven;
    wire [7:0]  seg_oven;
    wire [1:0]  in1_in2_oven;
    wire        PWM_OUT_oven;
    wire        buzzer_oven;
    wire        servo_oven;


    // Oven 인스턴스
    oven u_oven (
        .clk(clk),
        .reset(soft_reset),
        .tick(w_tick),
        .tick_1s(w_tick_1s),
        .toggle_1s(w_toggle_1s),
        .clean_btn_edge(clean_btn_edge),
        .motor_direction(sw[14:13]),
        .PWM_OUT(PWM_OUT_oven),
        .in1_in2(in1_in2_oven),
        .led(led_oven),
        .an(an_oven),
        .seg(seg_oven),
        .buzzer(buzzer_oven),
        .servo(servo_oven)
    );

    always @(*) begin
        case (sw_mode_reg)
            MODE_AHU: begin // AHU
                led     = led_ahu;
                an      = an_ahu;
                seg     = seg_ahu;
                in1_in2 = in1_in2_ahu;
                PWM_OUT = PWM_OUT_ahu;
                buzzer  = buzzer_ahu;
                servo   = servo_ahu;
            end
            MODE_OVEN: begin // Oven
                led     = led_oven;
                an      = an_oven;
                seg     = seg_oven;
                in1_in2 = in1_in2_oven;
                PWM_OUT = PWM_OUT_oven;
                buzzer  = buzzer_oven;
                servo   = servo_oven;
            end
            MODE_CLOCK: begin // Clock
                led     = led_clock;
                an      = an_clock;
                seg     = seg_clock;
                in1_in2 = 2'b00;
                PWM_OUT = 1'b0;
                buzzer  = buzzer_clock;
                servo   = 1'b0;
            end
            default: begin
                led     = 16'h0000;
                an      = 4'b1111;
                seg     = 8'b11111111;
                in1_in2 = 2'b00;
                PWM_OUT = 1'b0;
                buzzer  = 1'b0;
                servo   = 1'b0;
            end
        endcase
end




endmodule