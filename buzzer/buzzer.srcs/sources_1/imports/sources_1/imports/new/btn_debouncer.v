
// 버튼 디바운스 + 엣지 검출
// 엣지되는 순간을 검출
module btn_edge_detector #(
    parameter WIDTH = 1,
    parameter DEBOUNCE_LIMIT = 20'd999_999 //  10 ms
)(
    input               clk,
    input               reset,
    input  [WIDTH-1:0]  btn,
    output [WIDTH-1:0]  btn_edge
);

    wire [WIDTH-1:0] clean_btn;

    // 내부에서 debounce 처리
    btn_debounce #(
        .WIDTH(WIDTH),
        .DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)
    ) U_btn_debounce (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .clean_btn(clean_btn)
    );

    // 이전 상태 기억
    reg [WIDTH-1:0] clean_btn_prev;

    always @(posedge clk or posedge reset) begin
        if (reset)
            clean_btn_prev <= 0;
        else
            clean_btn_prev <= clean_btn;
    end

    // rising edge 검출
    assign btn_edge = clean_btn & ~clean_btn_prev;

endmodule

// 버튼 디바운스 처리
module btn_debounce #(
    parameter WIDTH = 1,
    parameter DEBOUNCE_LIMIT = 20'd999_999 //  10 ms
)(
    input                clk,
    input                reset,
    input  [WIDTH-1:0]   btn,
    output reg [WIDTH-1:0] clean_btn
);

    reg [19:0] count     [0:WIDTH-1];
    reg        btn_state [0:WIDTH-1];

    integer i;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                count[i] <= 0;
                btn_state[i] <= 0;
                clean_btn[i] <= 0;
            end
        end else begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (btn[i] == btn_state[i]) begin
                    count[i] <= 0;
                end else begin
                    if (count[i] < DEBOUNCE_LIMIT)
                        count[i] <= count[i] + 1;
                    else begin
                        btn_state[i] <= btn[i];
                        clean_btn[i] <= btn[i];
                        count[i] <= 0;
                    end
                end
            end
        end
    end

endmodule