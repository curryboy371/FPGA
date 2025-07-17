`timescale 1ns / 1ps

module fnd_cycle #( 
    parameter CYCLE_TICK_MS = 100
)(
    input clk,
    input reset,
    input tick,                 
    output [7:0] seg_data,
    output [3:0] an
);

    parameter SEG_A    = 8'b11111110;
    parameter SEG_B    = 8'b11111101;
    parameter SEG_C    = 8'b11111011;
    parameter SEG_D    = 8'b11110111;
    parameter SEG_E    = 8'b11101111;
    parameter SEG_F    = 8'b11011111;
    parameter SEG_G    = 8'b10111111;
    parameter SEG_BLANK = 8'b11111111; // 다 비움

    parameter MAX_CYCLE = 12;

    // cycle tick 생성 및 cycle 인덱스 move
    reg [$clog2(CYCLE_TICK_MS)-1:0] r_cycle_tick_counter =0; 
    reg [3:0] cycle_index = 0;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_index <= 0;
            r_cycle_tick_counter <= 0;
        end
        else if (tick) begin
            if(r_cycle_tick_counter == CYCLE_TICK_MS -1) begin 
                r_cycle_tick_counter <= 0;

                if (cycle_index == MAX_CYCLE - 1)
                    cycle_index <= 0;
                else
                    cycle_index <= cycle_index + 1;

            end else begin
                r_cycle_tick_counter <= r_cycle_tick_counter + 1;
            end
        end
    end

    // cycle index case 별로 업데이트
    reg [7:0] d1, d2, d3, d4;
    always @(*) begin
        case (cycle_index)
            4'd0 : begin 
                d1=SEG_A;
                d2=SEG_BLANK;
                d3=SEG_BLANK;
                d4=SEG_BLANK;
            end
            4'd1 : begin 
                d1=SEG_A; 
                d2=SEG_A;    
                d3=SEG_BLANK; 
                d4=SEG_BLANK; 
            end

            4'd2 : begin 
                d1=SEG_A; 
                d2=SEG_A;    
                d3=SEG_A;    
                d4=SEG_BLANK; 
            end

            4'd3 : begin 
                d1=SEG_A; 
                d2=SEG_A;    
                d3=SEG_A;    
                d4=SEG_A;    
            end

            4'd4 : begin
                d1=SEG_A; 
                d2=SEG_A;    
                d3=SEG_A;    
                d4=SEG_A & SEG_F; 
                end
            4'd5 : begin
                d1=SEG_A;
                d2=SEG_A;
                d3=SEG_A;
                d4=SEG_A & SEG_F & SEG_E; 
                end
            4'd6 : begin
                d1=SEG_A; 
                d2=SEG_A;    
                d3=SEG_A;    
                d4=SEG_A & SEG_F & SEG_E & SEG_D; 
                end
            4'd7 : begin
                d1=SEG_A; 
                d2=SEG_A;    
                d3=SEG_A & SEG_D; 
                d4=SEG_A & SEG_F & SEG_E & SEG_D; 
                end

            4'd8 : begin
                d1=SEG_A; 
                d2=SEG_A & SEG_D; 
                d3=SEG_A & SEG_D; 
                d4=SEG_A & SEG_F & SEG_E & SEG_D; 
                end
            4'd9 : begin
                d1=SEG_A & SEG_D; 
                d2=SEG_A & SEG_D; 
                d3=SEG_A & SEG_D; 
                d4=SEG_A & SEG_F & SEG_E & SEG_D; 
                end
            4'd10: begin
                d1=SEG_A & SEG_D & SEG_C; 
                d2=SEG_A & SEG_D; 
                d3=SEG_A & SEG_D; 
                d4=SEG_A & SEG_F & SEG_E & SEG_D; 
                end
            4'd11: begin
                d1=SEG_A & SEG_D & SEG_C & SEG_B; 
                d2=SEG_A & SEG_D; 
                d3=SEG_A & SEG_D; 
                d4=SEG_A & SEG_F & SEG_E & SEG_D; 
                end
            default: begin 
                d1=SEG_BLANK; 
                d2=SEG_BLANK; 
                d3=SEG_BLANK; 
                d4=SEG_BLANK; 
                end
        endcase
    end


    fnd_controller_row u_fnd_controller_row(
        .clk(clk),
        .reset(reset),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .d4(d4),
        .seg_data(seg_data),
        .an(an)
    );

endmodule
