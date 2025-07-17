`timescale 1ns / 1ps
module buzzer_sequence(
    input clk,
    input reset,
    input tick,
    input toggle_1s,
    input [2:0] buzzer_pulse,   // pulse (1클럭)
    output buzzer_done,
    output buzzer
);

    parameter TIME_30MS = 30;
    parameter TIME_70MS = 70;
    parameter TIME_1S   = 1000;


    parameter DIV_1KHZ  = 50000;
    parameter DIV_2KHZ  = 25000;
    parameter DIV_3KHZ  = 16666;
    parameter DIV_4KHZ  = 12500;
    parameter DIV_C4    = 191110;
    parameter DIV_E4    = 151689;
    parameter DIV_G4    = 127551;
    parameter DIV_CS5   = 90252;

    parameter BUZZER_IDLE       = 3'b000;
    parameter CLOSE             = 3'b001;
    parameter OPEN              = 3'b010;
    parameter BUTTON            = 3'b011;
    parameter ALARM             = 3'b100;

    reg [2:0] buzzer_state = BUZZER_IDLE;

    reg [2:0] step_max = 0;
    reg [2:0] step_index = 0;
    reg [27:0] step_timer = 0;

    reg [20:0] freq_div_arr [0:4];
    reg [27:0] delay_arr [0:4];

    integer i;

    reg buzzer_start = 0;
    reg done_cycle = 1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            step_index <= 0;
            step_timer <= 0;
            done_cycle <= 1;
            buzzer_state <= BUZZER_IDLE;
        end else begin
            case (buzzer_state)
                BUZZER_IDLE: begin
                    done_cycle <= 1;
                    step_index <= 0;
                    step_timer <= 0;
                    if (buzzer_pulse != BUZZER_IDLE) begin
                        buzzer_state <= buzzer_pulse;
                        done_cycle <= 0;
                        case (buzzer_pulse)
                            CLOSE: begin
                                freq_div_arr[0] <= DIV_1KHZ; delay_arr[0] <= TIME_70MS;
                                freq_div_arr[1] <= DIV_2KHZ; delay_arr[1] <= TIME_70MS;
                                freq_div_arr[2] <= DIV_3KHZ; delay_arr[2] <= TIME_70MS;
                                freq_div_arr[3] <= DIV_4KHZ; delay_arr[3] <= TIME_70MS;
                                freq_div_arr[4] <= 0;         delay_arr[4] <= TIME_1S;
                                step_max <= 5;
                            end
                            OPEN: begin
                                freq_div_arr[0] <= DIV_C4;   delay_arr[0] <= TIME_70MS;
                                freq_div_arr[1] <= DIV_E4;   delay_arr[1] <= TIME_70MS;
                                freq_div_arr[2] <= DIV_G4;   delay_arr[2] <= TIME_70MS;
                                freq_div_arr[3] <= DIV_CS5;  delay_arr[3] <= TIME_70MS;
                                freq_div_arr[4] <= 0;        delay_arr[4] <= TIME_1S;
                                step_max <= 5;
                            end
                            BUTTON: begin
                                freq_div_arr[0] <= DIV_2KHZ; delay_arr[0] <= TIME_30MS;
                                freq_div_arr[1] <= DIV_1KHZ; delay_arr[1] <= TIME_30MS;
                                freq_div_arr[2] <= 0;        delay_arr[2] <= TIME_30MS;
                                step_max <= 3;
                            end

                            ALARM: begin
                                freq_div_arr[0] <= DIV_1KHZ;    delay_arr[0] <= TIME_1S;
                                freq_div_arr[1] <= DIV_C4;      delay_arr[1] <= TIME_1S;
                                freq_div_arr[2] <= DIV_2KHZ;    delay_arr[2] <= TIME_1S;
                                freq_div_arr[3] <= DIV_E4;      delay_arr[3] <= TIME_1S;
                                freq_div_arr[4] <= DIV_4KHZ;    delay_arr[4] <= TIME_1S;
                                step_max <= 5;
                            end
                        endcase
                    end
                end
                default: begin
                    if (tick) begin
                        if (step_timer >= delay_arr[step_index] - 1) begin
                            if (step_index == step_max - 1) begin
                                done_cycle <= 1;
                                buzzer_state <= BUZZER_IDLE;
                            end else begin
                                step_index <= step_index + 1;
                                step_timer <= 0;
                            end
                        end else begin
                            step_timer <= step_timer + 1;
                        end
                    end
                end
            endcase
        end
    end

    assign buzzer_done = done_cycle;

    wire [20:0] clk_div;
    // idle일 때는 소리x
    // alarm 중인 경우는 fnd 신호에 맞게 음을 출력하기 위해 toggle_1s 사용
    assign clk_div = (buzzer_state == BUZZER_IDLE || (buzzer_state == ALARM && !toggle_1s) ) ? 0 : freq_div_arr[step_index];

    freq_generator u_freq_gen (
        .clk(clk),
        .reset(reset),
        .clk_div(clk_div),
        .buzzer(buzzer)
    );

endmodule
