`timescale 1ns / 1ps


module top(clk, reset, btn, motor_direction, echo, trigger, RsRx, RsTx, PWM_OUT, in1_in2, led, an, seg, buzzer, servo, dht11_data);
    input clk, reset;
    input [4:0] btn;
    input [1:0] motor_direction;  // sw0 sw1 : motor direction
    input echo;          // hc_sr04
    output trigger;      // hc_sr04
    input RsRx;
    output RsTx;
    output PWM_OUT;       // 10MHz PWM output signal 
    output [1:0] in1_in2;  // motor direction switch sw[0] sw[1]
    output [15:0] led;
    output [3:0] an;
    output [7:0] seg;
    output buzzer;
    output servo;
    inout dht11_data;

    localparam BTN_CENTER = 3'd0;    // 선택
    localparam BTN_UP = 3'd1;        // depth up
    localparam BTN_LEFT = 3'd2;      // 모터 파워 다운
    localparam BTN_RIGHT = 3'd3;     // 모터 파워 UP
    localparam BTN_DOWN = 3'd4;      // depth down, back
    localparam BTN_MAX = 3'd5;


    localparam INDEX_TEMP = 3'd0;
    localparam INDEX_HUMID = 3'd1;
    localparam INDEX_TIME = 3'd2;
    localparam INDEX_STEP_MAX = 3'd3;

    localparam MIN_TEMP = 1;   
    localparam MAX_TEMP = 120;  

    localparam MIN_HUMID = 10;   
    localparam MAX_HUMID = 100;  

    localparam MIN_TIME = 30;   
    localparam MAX_TIME = 600;  


    localparam INDEX_DHT11          = 2'd0;
    localparam INDEX_HC_SR04        = 2'd1;
    localparam INDEX_DEVICE_MAX     = 2'd2;


    localparam MIN_DISTANCE = 5;  

    reg [13:0] ahu_setting_values [INDEX_STEP_MAX-1:0];     // 세팅값
    reg [13:0] ahu_getting_values [INDEX_STEP_MAX-1:0];     // 디바이스에서 받은 값

    reg [13:0] ahu_value; // 인자 전달용

    reg [13:0] step_min;
    reg [13:0] step_max;


    wire w_tick;
    tick_generator u_tick_generator (
        .clk(clk),           
        .reset(reset),         
        .tick(w_tick)         
    );

    wire w_tick_1s;
    wire w_toggle_1s; 
    tick_generator #(.TICK_HZ(1)) u_tick_generator_1s ( // 1s @100MHz  1s : 100_000_000
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1s),
        .toggle(w_toggle_1s)
    );



    wire [BTN_MAX-1:0] clean_btn_edge;
    btn_edge_detector #(.WIDTH(BTN_MAX)) U_btn_edge_detector (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .btn_edge(clean_btn_edge)
    );

    //  메인 모드..
    // bit flag로 ( led 확인 쉽게할라구)
    parameter WARN       = 5'b00000;
    parameter IDLE       = 5'b00001;
    parameter SETUP      = 5'b00010;
    parameter RUNNING    = 5'b00100;

    parameter FINISHED   = 5'b01000;
    parameter PAUSED     = 5'b10000;

    // door 상태
    parameter DOOR_CLOSED = 1'b0;
    parameter DOOR_OPEN   = 1'b1;


    parameter FINISH_WAIT_SEC = 5;

    reg door_state = DOOR_CLOSED;

    reg [4:0] ahu_state = IDLE;

    reg [2:0] state_step = 0;

    reg [12:0] ahu_time = 0;

    reg [4:0] finish_wait = 5; 
    reg [4:0] warn_wait = 5; 


    reg [3:0] r_duty_cycle; // 1~10

    wire w_done_cycle;  // 부저 완료 sign ( 버튼 입력 딜레이로 사용함)


    //  device_start[INDEX_DHT11] <= 0;
    //  device_start[INDEX_HC_SR04] <= 0;
    reg [INDEX_DEVICE_MAX -1:0] device_start;
    wire [INDEX_DEVICE_MAX -1:0] device_enable;

    wire [13:0] w_distance;
    hc_sr04 u_hc_sr04(
        .clk(clk),        
        .reset(reset),
        .start(device_start[INDEX_HC_SR04]),
        .enable(device_enable[INDEX_HC_SR04]),
        .trigger(trigger),
        .echo(echo),
        .led(led),
        .distance(w_distance)
    );

    // 내부 연결 신호 정의
    wire [7:0] humidity_int, humidity_dec, temp_int, temp_dec, checksum;
    wire data_valid;

    reg [13:0] input_data;


    localparam OPEN_ANGLE = 8'd0;
    localparam CLOSE_ANGLE = 8'd180;
    reg [7:0] angle = CLOSE_ANGLE;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            input_data <= 14'd0;
        end else if (data_valid) begin
            input_data <= {6'b000000, humidity_int};  // 상위 6비트 0 패딩
        end else begin
            input_data <= 0;
        end
    end

    // dht11 모듈 인스턴스
    dht11 u_dht11 (
        .clk(clk),
        .reset(reset),
        .start(device_start[INDEX_DHT11]),
        .data(dht11_data),                
        .data_valid(data_valid),
        .enable(device_enable[INDEX_DHT11]),
        .humidity_int(humidity_int),
        .humidity_dec(humidity_dec),
        .temp_int(temp_int),
        .temp_dec(temp_dec),
        .checksum(checksum)
        //.led(led)
    );







    // 전자레인지 상태에 따른 입력 및 time 처리
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ahu_state <= IDLE;
            state_step <= 0;
            r_duty_cycle <=0;
            door_state <= DOOR_OPEN;

            ahu_setting_values[INDEX_TEMP] <= 0;
            ahu_setting_values[INDEX_HUMID] <= 0;
            ahu_setting_values[INDEX_TIME] <= 0;

            ahu_getting_values[INDEX_TEMP] <= 0;
            ahu_getting_values[INDEX_HUMID] <= 0;
            ahu_getting_values[INDEX_TIME] <= 0;
            

            ahu_value <= 0;

            step_min <= 0;
            step_max <= 0;

            device_start[INDEX_DHT11] <= 0;
            device_start[INDEX_HC_SR04] <= 0;

            angle <= CLOSE_ANGLE;

        end else begin
            case (ahu_state)
                IDLE: begin
                    if(w_done_cycle) begin
                        if(clean_btn_edge[BTN_RIGHT]) begin
                            angle <= CLOSE_ANGLE;
                        end
                        
                        if(clean_btn_edge[BTN_LEFT]) begin
                            angle <= OPEN_ANGLE;
                        end

                        if(clean_btn_edge[BTN_CENTER] | clean_btn_edge[BTN_UP]) begin

                            angle <= CLOSE_ANGLE;

                            ahu_state <= SETUP;

                            ahu_setting_values[INDEX_TEMP] <= MIN_TEMP;
                            ahu_setting_values[INDEX_HUMID] <= MIN_HUMID;
                            ahu_setting_values[INDEX_TIME] <= MIN_TIME;
                            ahu_value <= MIN_TEMP;

                            state_step <= INDEX_TEMP;
                            step_min <= MIN_TEMP;
                            step_max <= MAX_TEMP;


                            finish_wait <= FINISH_WAIT_SEC;
                        end
                    end
                end
                SETUP: begin
                    if(w_done_cycle) begin

                        // 온,습,시 설정
                        case (state_step)
                            INDEX_TEMP: begin // 온도 설정

                                if(clean_btn_edge[BTN_UP]) begin
                                    step_min <=MIN_HUMID;
                                    step_max <= MAX_HUMID;
                                    ahu_value <= ahu_setting_values[INDEX_HUMID];
                                    state_step <= INDEX_HUMID;
                                end

                                // pre step이 없는데 down인 경우 취소
                                if(clean_btn_edge[BTN_DOWN]) begin
                                    ahu_state <= IDLE;
                                end
                            end

                            INDEX_HUMID: begin // 습도 설정
                            
                                if(clean_btn_edge[BTN_UP]) begin
                                    step_min <= MIN_TIME;
                                    step_max <= MAX_TIME;
                                    ahu_value <= ahu_setting_values[INDEX_TIME];
                                    state_step <= INDEX_TIME;
                                end

                                if(clean_btn_edge[BTN_DOWN]) begin
                                    step_min <= MIN_TEMP;
                                    step_max <= MAX_TEMP;
                                    ahu_value <= ahu_setting_values[INDEX_TEMP];
                                    state_step <= INDEX_TEMP;
                                end

                            end
                            
                            INDEX_TIME: begin // 시간 설정
                                // next step이 없는데 up인 경우 run
                                if(clean_btn_edge[BTN_UP]) begin
                                    ahu_state <= RUNNING;
                                    state_step <= INDEX_TEMP;
                                end

                                if(clean_btn_edge[BTN_DOWN]) begin
                                    step_min <= MIN_HUMID;
                                    step_max <= MAX_HUMID;
                                    ahu_value <= ahu_setting_values[INDEX_HUMID];
                                    state_step <= INDEX_HUMID;
                                end

                            end

                            default: begin
                                state_step <= INDEX_TEMP;
                            end

                        endcase

                        // 값 증가
                        if(clean_btn_edge[BTN_RIGHT]) begin
                            if (ahu_setting_values[state_step] + step_min <= step_max) begin
                                ahu_setting_values[state_step] <= ahu_setting_values[state_step] + step_min;
                                ahu_value <= ahu_setting_values[state_step] + step_min;
                            end
                            else begin
                                ahu_setting_values[state_step] <= step_max; 
                                ahu_value <= step_max;
                            end
                        end

                        // 값 감소
                        if(clean_btn_edge[BTN_LEFT]) begin
                            if (ahu_setting_values[state_step] - step_min > step_min) begin
                                ahu_setting_values[state_step] <= ahu_setting_values[state_step] - step_min;
                                ahu_value <= ahu_setting_values[state_step] - step_min;
                            end
                            else begin
                                ahu_setting_values[state_step] <= step_min; 
                                ahu_value <= step_min;
                            end
                        end

                        // run
                        if(clean_btn_edge[BTN_CENTER]) begin
                            ahu_state <= RUNNING;
                            state_step <= INDEX_TEMP;

                            ahu_getting_values[INDEX_TIME] <= ahu_setting_values[INDEX_TIME];

                        end

                    end
                end
                RUNNING: begin
                    device_start[INDEX_DHT11] <= 1;
                    device_start[INDEX_HC_SR04] <= 1;

                    // 현재 온도 출력
                    if(clean_btn_edge[BTN_UP]) begin
                        if(state_step + 1 == INDEX_STEP_MAX) begin
                            state_step <= INDEX_TEMP;
                            ahu_value <= ahu_getting_values[INDEX_TEMP];

                        end
                        else begin
                            ahu_value <= ahu_getting_values[state_step + 1];
                            state_step <= state_step + 1;
                        end
                    end
                    else if(clean_btn_edge[BTN_DOWN]) begin
                        if(state_step == INDEX_TEMP) begin
                            ahu_value <= ahu_getting_values[INDEX_TIME];
                            state_step <= INDEX_TIME;
                        end
                        else begin
                            ahu_value <= ahu_getting_values[state_step - 1];
                            state_step <= state_step - 1;
                        end
                    end
                    else begin
                        // 버튼 눌림 x
                        ahu_value <= ahu_getting_values[state_step];
                    end

                    // 거리 체크
                    // if(device_enable[INDEX_HC_SR04]) begin 

                    //     if(w_distance < MIN_DISTANCE) begin
                    //         ahu_state <= WARN;
                    //     end
                    //     else begin

                    //     end
                    // end

                    // 온도 체크 - dc 모터 제어
                    // 습도 체크 - 서보모터 제어
                    if(device_enable[INDEX_DHT11]) begin
                        if(data_valid) begin
                            ahu_getting_values[INDEX_TEMP] <= {6'b000000, temp_int};
                            ahu_getting_values[INDEX_HUMID] <= {6'b000000, humidity_int}; 

                            // 온도 비교
                            if({6'b000000, temp_int} > ahu_setting_values[INDEX_TEMP]) begin
                                r_duty_cycle <=7;
                            end
                            else begin
                                r_duty_cycle <=0;
                            end

                            // 습도 비교
                            if({6'b000000, humidity_int} > ahu_setting_values[INDEX_HUMID]) begin
                                angle <= OPEN_ANGLE;
                            end
                            else begin
                                angle <= CLOSE_ANGLE;
                            end



                        end
                        else begin
                            ahu_getting_values[INDEX_TEMP] <= 0;
                            ahu_getting_values[INDEX_HUMID] <= 0;
                        end

                    end

                    r_duty_cycle <=7;
                    if(w_tick_1s) begin
                        if(ahu_getting_values[INDEX_TIME] <= 0) begin
                            ahu_state <= FINISHED;
                        end
                        else begin
                            ahu_getting_values[INDEX_TIME] <= ahu_getting_values[INDEX_TIME] - 1;
                        end
                    end

                    // 일시정지 버튼
                    if(w_done_cycle) begin
                        if(clean_btn_edge[BTN_CENTER]) begin
                            ahu_state <= PAUSED;
                        end
                    end
                end

                PAUSED: begin
                    r_duty_cycle <=0;
                    if(w_done_cycle) begin
                        // 취소 버튼
                        if(clean_btn_edge[BTN_CENTER]) begin
                            ahu_state <= IDLE;
                        end

                        // 시간 입력버튼 누르면 다시 동작
                        if(clean_btn_edge[BTN_RIGHT] || clean_btn_edge[BTN_LEFT]) begin
                            ahu_state <= RUNNING;
                        end

                        // 완전히 취소 버튼
                        if(clean_btn_edge[BTN_CENTER]) begin
                            ahu_state <= IDLE;
                        end
                    end
                end

                FINISHED: begin
                    device_start[INDEX_DHT11] <= 0;
                    device_start[INDEX_HC_SR04] <= 0;
                    r_duty_cycle <=0;
                    if(finish_wait <= 0) begin
                        ahu_state <= IDLE;
                    end
                    else begin
                        if(w_tick_1s) begin
                            finish_wait <= finish_wait -1;
                        end
                    end

                end
                WARN: begin

                    r_duty_cycle <=0;



                end

                default:begin

                end
            endcase
        end
    end


    // 문열고 닫기 상태 + 부저상태도
    localparam BUZZER_IDLE   = 3'b000;
    localparam CLOSE         = 3'b001;
    localparam OPEN          = 3'b010;
    localparam BUTTON        = 3'b011;
    localparam BUTTON_HIGH   = 3'b100;
    localparam ALARM         = 3'b111;

    reg [2:0] buzzer_pulse = BUZZER_IDLE;

    // 문 열림, 닫힘 및 부저음
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            buzzer_pulse <= BUZZER_IDLE;
            door_state <=DOOR_CLOSED;

        end else begin
            buzzer_pulse <= BUZZER_IDLE;

            if (w_done_cycle) begin

                if (clean_btn_edge[BTN_CENTER]) begin
                    buzzer_pulse <= BUTTON;
                end

                // 버튼음 다르게 해도 됨
                if (clean_btn_edge[BTN_DOWN] | clean_btn_edge[BTN_UP] | clean_btn_edge[BTN_RIGHT] | clean_btn_edge[BTN_LEFT] ) begin
                    buzzer_pulse <= BUTTON_HIGH;
                end
            end

            // FINISHED 종료 알림을 여기서도 검사하도록
            // ahu state의 always에서 buzzer pulse를 또 <= 하면 안되므로
            // if (ahu_state == RUNNING && ahu_time <= 0 && w_tick_1s) begin
            //     buzzer_pulse <= ALARM; // 종료 알림
            // end
        end
    end

    buzzer_sequence u_buzzer_sequence (
        .clk(clk),
        .reset(reset),
        .tick(w_tick),
        .toggle_1s(w_toggle_1s),
        .buzzer_pulse(buzzer_pulse),  // BUZZER_STOP, CLOSE, OPEN
        .buzzer_done(w_done_cycle),
        .buzzer(buzzer)
    );

    ahu_fnd u_ahu_fnd(
        .clk(clk),
        .reset(reset), 
        .tick(w_tick),
        .toggle_1s(w_toggle_1s),
        .ahu_state(ahu_state),
        .ahu_value(ahu_value),
        .ahu_step(state_step),
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



            

    wire [7:0] w_rx_data;
    wire w_rx_done;
    uart_controller u_uart_controller(
        .clk(clk),
        .reset(reset),
        .print(device_enable[INDEX_HC_SR04]),
        .send_data(w_distance), 
        .rx(RsRx),
        .tx(RsTx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );


    //assign led[7:0] = w_rx_data;
    // assign led[15] = door_state;
    // assign led[14] = w_done_cycle;
    // assign led[13] = w_toggle_1s;

/////////////////////////////////////// simulation용
reg [39:0] state_str;

always @(*) begin
    case (ahu_state)
        IDLE:       state_str = "IDLE ";
        SETUP:      state_str = "SETUP";
        RUNNING:    state_str = "RUN  ";
        FINISHED:   state_str = "FINSH";
        PAUSED:     state_str = "PAUSE";
        default:    state_str = "UNDEF";
    endcase
end
///////////////////////////////////////


endmodule
