`timescale 1ns / 1ps

module clock (
    input clk,
    input reset,
    input tick,
    input tick_1s,
    input toggle_1s,
    input [4:0] clean_btn_edge,
    output buzzer,
    output [15:0] led,
    output [3:0] an,
    output [7:0] seg
);

    parameter BTN_CENTER = 3'd0;
    parameter BTN_UP     = 3'd1;
    parameter BTN_LEFT   = 3'd2;
    parameter BTN_RIGHT  = 3'd3;
    parameter BTN_DOWN   = 3'd4;

    localparam MODE_UP        = 2'd0;
    localparam MODE_DOWN      = 2'd1;
    localparam MODE_STOPWATCH = 2'd2;
    localparam MODE_IDLE      = 2'd3;

    parameter SEG_IDLE  = 8'b10111111; // '-'

    reg [3:0] tick_10ms_cnt;
    reg tick_10ms;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tick_10ms_cnt <= 0;
            tick_10ms <= 0;
        end else begin
            if (tick) begin
                if (tick_10ms_cnt == 10-1) begin
                    tick_10ms_cnt <= 0;
                    tick_10ms <= 1;
                end else begin
                    tick_10ms_cnt <= tick_10ms_cnt + 1;
                    tick_10ms <= 0;
                end
            end else begin
                tick_10ms <= 0;
            end
        end
    end


    reg [1:0] clock_mode;
    reg [13:0] time_counter [3:0];
    reg is_running;

    // 메인 FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clock_mode   <= MODE_IDLE;
            is_running   <= 1'b0;
            time_counter[0] <= 0;
            time_counter[1] <= 0;
            time_counter[2] <= 0;
        end else begin
            // 공통 처리 (모드 전환 및 실행/정지)
            if (clean_btn_edge[BTN_UP])   clock_mode <= clock_mode + 1;
            if (clean_btn_edge[BTN_DOWN]) clock_mode <= clock_mode - 1;

            case (clock_mode)
                MODE_IDLE: begin
                    
                end

                MODE_UP: begin
                    if (tick_10ms) begin
                        if (time_counter[0] >= 9999)
                            time_counter[0] <= 14'd1;
                        else
                            time_counter[0] <= time_counter[0] + 1;
                    end
                end

                MODE_DOWN: begin
                    if (tick_10ms) begin
                        if (time_counter[1] == 0)
                            time_counter[1] <= 14'd9999;
                        else
                            time_counter[1] <= time_counter[1] - 1;
                    end
                end

                MODE_STOPWATCH: begin
                    if (clean_btn_edge[BTN_CENTER]) 
                        is_running <= ~is_running;

                    if (clean_btn_edge[BTN_RIGHT])
                        time_counter[2] <= (time_counter[2] >= 9999 - 60) ? 14'd9999 : time_counter[2] + 60;

                    if (clean_btn_edge[BTN_LEFT])
                        time_counter[2] <= (time_counter[2] >= 60) ? time_counter[2] - 60 : 14'd0;

                    if (tick_1s && is_running)
                        time_counter[2] <= time_counter[2] + 1;

                end

                default: begin
                    time_counter[0] <= 0;
                    time_counter[1] <= 0;
                    time_counter[2] <= 0;
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


    // fnd_controller : number
    wire [7:0] w_seg_num;
    wire [3:0] w_an_num;
    fnd_controller u_fnd_controller_num2(
        .clk(clk),
        .reset(reset),
        .input_data(time_counter[clock_mode]),
        .seg_data(w_seg_num),
        .an(w_an_num)
    );

    // fnd_controller : MMSS
    wire [7:0] w_seg_data;
    wire [3:0] w_an_data;
    fnd_controller u_fnd_controller2(
        .clk(clk),
        .reset(reset),
        .input_data((time_counter[clock_mode] / 60) * 100 + (time_counter[clock_mode] % 60)),
        .seg_data(w_seg_data),
        .an(w_an_data)
    );

    // fnd_controller_row
    wire [7:0] w_seg_row;
    wire [3:0] w_an_row;

    fnd_controller_row u_fnd_controller_row2(
        .clk(clk),
        .reset(reset),
        .d1(SEG_IDLE),
        .d2(SEG_IDLE),
        .d3(SEG_IDLE),
        .d4(SEG_IDLE),
        .seg_data(w_seg_row),
        .an(w_an_row)
    );

    assign seg = (clock_mode == MODE_IDLE)      ? w_seg_row  :
                 (clock_mode == MODE_STOPWATCH) ? w_seg_data :
                                                  w_seg_num;

    assign an  = (clock_mode == MODE_IDLE)      ? w_an_row   :
                 (clock_mode == MODE_STOPWATCH) ? w_an_data  :
                                                  w_an_num;


    assign led = {13'b0, clock_mode, is_running};

endmodule
