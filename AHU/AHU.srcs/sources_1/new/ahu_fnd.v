module ahu_fnd(
    input clk,
    input reset,
    input tick,
    input toggle_1s,
    input [4:0] ahu_state,
    input door_state,
    input [12:0] ahu_time,
    output [7:0] seg,
    output [3:0] an
);

    parameter DOOR_CLOSED = 1'b0;
    parameter DOOR_OPEN   = 1'b1;

    // bit flag로 ( led 확인 쉽게할라구)
    parameter RESET      = 5'b00000;
    parameter IDLE       = 5'b00001;
    parameter TIME_SETUP = 5'b00010;
    parameter RUNNING    = 5'b00100;
    parameter FINISHED   = 5'b01000;
    parameter PAUSED     = 5'b10000;


    parameter SEG_ALL_ON = 8'b00000000;// 다 채움
    parameter SEG_BLANK = 8'b11111111; // 다 비움
    parameter SEG_IDLE  = 8'b10111111; // '-'
    parameter SEG_0     = 8'b11000000; // '0'
    
    parameter SEG_O = 8'b11000000; 
    parameter SEG_P = 8'b10001100; 
    parameter SEG_E = 8'b10000110; 
    parameter SEG_N = 8'b10101011; 

    // fnd 출력 모드
    parameter USE_SEG  = 2'b00;
    parameter USE_TIME = 2'b01;
    parameter USE_CYCLE = 2'b10;
    reg [1:0] fnd_mode = USE_SEG;

    reg [7:0] r_d [3:0];  // 배열로 변경
    reg [7:0] r_d1, r_d2, r_d3, r_d4;
    integer i;
    always @(*) begin
        if (door_state == DOOR_OPEN) begin
            fnd_mode = USE_SEG;
            r_d[0] = SEG_N;
            r_d[1] = SEG_E;
            r_d[2] = SEG_P;
            r_d[3] = SEG_O;
        end
        else begin
            case (ahu_state)
                IDLE: begin
                    // ---- 표시
                    fnd_mode = USE_SEG;
                    for (i = 0; i < 4; i = i + 1) r_d[i] = SEG_IDLE;
                end
                TIME_SETUP: begin
                    // 남은 시간 표시
                    fnd_mode = USE_TIME;
                end
                RUNNING: begin
                    if (toggle_1s) begin
                        fnd_mode = USE_TIME;
                    end else begin
                        fnd_mode = USE_CYCLE;
                    end
                end

                PAUSED: begin
                    // 남은 시간 표시
                    fnd_mode = USE_TIME;
                end

                FINISHED: begin
                    fnd_mode = USE_SEG;
                    if (toggle_1s) begin
                        for (i = 0; i < 4; i = i + 1) r_d[i] = SEG_0;
                    end else begin
                        for (i = 0; i < 4; i = i + 1) r_d[i] = SEG_BLANK;
                    end
                end

                RESET: begin
                    fnd_mode = USE_SEG;
                    for (i = 0; i < 4; i = i + 1) r_d[i] = SEG_ALL_ON;
                end

                default: begin
                    fnd_mode = USE_SEG;
                    for (i = 0; i < 4; i = i + 1) r_d[i] = SEG_BLANK;
                end
            endcase
        end


    end

    // cycle
    wire [7:0] w_seg_cycle;
    wire [3:0] w_an_cycle;
    fnd_cycle #(.CYCLE_TICK_MS(100)) u_fnd_cycle (
        .clk(clk),
        .reset(reset),
        .tick(tick),
        .seg_data(w_seg_cycle),
        .an(w_an_cycle)
    );

    // fnd_controller : MMSS
    wire [7:0] w_seg_data;
    wire [3:0] w_an_data;
    fnd_controller u_fnd_controller(
        .clk(clk),
        .reset(reset),
        .input_data((ahu_time / 60) * 100 + (ahu_time % 60)),
        .seg_data(w_seg_data),
        .an(w_an_data)
    );

    // fnd_controller_row
    wire [7:0] w_seg_row;
    wire [3:0] w_an_row;

    fnd_controller_row u_fnd_controller_row(
        .clk(clk),
        .reset(reset),
        .d1(r_d[0]),
        .d2(r_d[1]),
        .d3(r_d[2]),
        .d4(r_d[3]),
        .seg_data(w_seg_row),
        .an(w_an_row)
    );

    // 출력
    assign seg = (fnd_mode == USE_TIME)  ? w_seg_data :
                (fnd_mode == USE_CYCLE) ? w_seg_cycle :
                                        w_seg_row;
    assign an  = (fnd_mode == USE_TIME)  ? w_an_data :
                (fnd_mode == USE_CYCLE) ? w_an_cycle :
                                        w_an_row;


endmodule
