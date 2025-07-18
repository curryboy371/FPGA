`timescale 1ns / 1ps


module dht11(
    input clk,
    input reset,
    input start,
    inout data,
    output reg enable,
    output reg data_valid,
    output reg [7:0] humidity_int, humidity_dec, checksum,
    output reg [7:0] temp_int, temp_dec
    //output [15:0] led
);

    // 상태 파라미터
    localparam IDLE = 3'b001;             // 대기상태
    localparam TX_START = 3'b010;         // 시작 신호 전송
    localparam RX_RESPONSE = 3'b011;      // DHT11 응답
    localparam RX_DATA = 3'b100;          // 40bit 데이터 수신중
    localparam RX_DONE = 3'b101;          // 수신 완료 후 파싱 및 유효 처리
    localparam COOL_TIME = 3'b110;        // 쿨타임

    localparam RX_ERROR = 3'b111;         // 응답 실패, 시간 초과 등 오류 상태

    // DHT11 센서 통신 타이밍 상수 (단위: 마이크로초)
    localparam COOL_TIME_US = 1000000; // 1s 1000000us    cool time

    localparam DHT_COMMON_TIMEOUT      = 20000;   // 공통 타임아웃 (20ms)


    localparam DHT_START_LOW_US        = 18000;   // MCU가 data를 LOW로 유지 (최소 18ms)
    localparam DHT_START_RELEASE_US    = 50;      // MCU가 HIGH로 풀고 DHT 응답 대기 (20~40us)

    localparam DHT_RESP_LOW_US         = 100;      // DHT11 응답: LOW 유지 시간 ( 80us)
    localparam DHT_RESP_HIGH_US        = 100;      // DHT11 응답: HIGH 유지 시간 (데이터 준비 시간) ( 80us)

    localparam DHT_BIT_START_LOW_US    = 50;      // 각 bit 시작 LOW 구간

    localparam DHT_BIT_HIGH_0_US       = 28;      // bit 0: HIGH 약 26~28us
    localparam DHT_BIT_HIGH_1_US       = 70;      // bit 1: HIGH 약 70us

    localparam DHT_EXTRA_US            = 100;     // 추가 여유 us 

    localparam DHT_DATA_BITS           = 40;      // 총 데이터 비트 수 (5바이트 = 40비트)

    reg [2:0] dht11_state = IDLE;
    reg [2:0] debug_state; // 디버그용 상태 저장
    reg [1:0] step;

    reg [$clog2(COOL_TIME_US)-1:0] us_counter =0; 
    reg [5:0] bit_index;            // 0 ~ 39 비트 인덱스
    reg [39:0] data_bits;           // 수신 데이터

    reg [7:0]  high_counter;    // HIGH 유지 시간 측정용

    // inout 제어용
    reg data_out = 1'b1;        // 기본 high
    reg data_out_en = 0;        // 기본 input 상태

    wire data_in = data;
    assign data = data_out_en ? data_out : 1'bz;

    wire w_tick_us;
    tick_generator #(.TICK_HZ(1000000)) u_us_tick ( // 1us @100MHz
        .clk(clk),
        .reset(reset),
        .tick(w_tick_us),
        .toggle(toggle_us)
    );

    always @(posedge clk or posedge reset) begin
    if (reset) begin
        dht11_state <= IDLE;
        debug_state <= IDLE;

        us_counter <= 0;
        bit_index <= 0;
        data_bits <= 0;

        data_out_en <= 0;
        data_out <= 1;
        step <= 0;

        high_counter <= 0;
        data_valid <= 1'b0;
        enable <= 1;

    end else begin
        case (dht11_state)
            IDLE: begin
                if (enable && start) begin
                    // 최기화
                    data_valid <= 1'b0;
                    high_counter <= 0;


                    // Start 신호: LOW 18ms
                    data_out_en <= 1;
                    data_out <= 0;     // low
                    us_counter <= 0;
                    dht11_state <= TX_START;
                    step <= 1;

                    enable <= 0;
                end
            end

            TX_START: begin
                if (w_tick_us) begin
                    us_counter <= us_counter + 1;

                    // 1단계: LOW 유지 ( 18ms)
                    if (us_counter < DHT_START_LOW_US) begin
                        step <= 1;
                        data_out_en <= 1;
                        data_out <= 0; // LOW
                    end

                    // 2단계: HIGH 유지 ( 40us)
                    else if (us_counter < DHT_START_LOW_US + DHT_START_RELEASE_US) begin
                        step <= 2;
                        data_out_en <= 1;
                        data_out <= 1; // HIGH
                    end

                    // 3단계: 응답 대기모드로
                    else begin
                        step <= 1;
                        data_out_en <= 0;  // high-Z (입력 대기)
                        us_counter <= 0;
                        dht11_state <= RX_RESPONSE;
                    end
                end
            end

            RX_RESPONSE: begin
                if (w_tick_us) begin

                    us_counter <= us_counter + 1;

                    // 1단계: LOW 응답 대기
                    if (step == 1) begin
                        
                        // low 응답 대기 80us
                        if(data_in == 0) begin
                            if(us_counter > DHT_RESP_LOW_US + DHT_EXTRA_US) begin
                                debug_state <= RX_RESPONSE;
                                dht11_state <= RX_ERROR;
                                us_counter <= 0;
                            end
                        end
                        else if (data_in == 1) begin
                            // step2 전환
                            us_counter <= 0;
                            step <= 2;
                        end
                    end

                    // 2단계: HIGH 응답 대기
                    else if (step == 2) begin
                        if (data_in == 1) begin
                            // HIGH 응답대기 80us
                            if (us_counter > DHT_RESP_HIGH_US + DHT_EXTRA_US) begin
                                debug_state <= RX_RESPONSE;
                                dht11_state <= RX_ERROR;
                                us_counter <= 0;
                            end
                        end
                        else if(data_in == 0) begin
                            // data low로 전환, high 80us 이내 유지 성공
                            // 다음 state 전환
                            us_counter <= 0;
                            bit_index <= 0;
                            step <= 1;                // step 초기화
                            dht11_state <= RX_DATA;   // 다음 상태 전이
                        end
                    end

                    // 타임아웃 공통 처리
                    if (us_counter > DHT_COMMON_TIMEOUT) begin
                        dht11_state <= RX_ERROR;
                        debug_state <= RX_RESPONSE;
                    end
                end
            end

            RX_DATA: begin
                if (w_tick_us) begin
                    // dht11이 data 전송시 각 데이터 비트는 50us low로 유지
                    // 이후 들어오는 high 신호 길이에 따라 데이터 0인지 1인지 구분함
                    us_counter <= us_counter + 1;       // 공통 타임아웃 측정용 카운터 증가

                    // 1단계: low 50us 유지
                    if (step == 1) begin
                        // low 응답 유지

                        if(data_in == 0) begin
                            if(us_counter > DHT_BIT_START_LOW_US + DHT_EXTRA_US) begin
                                debug_state <= RX_DATA;
                                dht11_state <= RX_ERROR;
                                us_counter <= 0;
                            end
                        end
                        else if (data_in == 1) begin
                            // step2 전환
                            us_counter <= 0;
                            high_counter <= 0;
                            step <= 2;
                        end
                    end
                    else if(step == 2) begin

                        // high 상태의 길이를 체크
                        high_counter <= high_counter + 1;

                        // low상태로 전환되었을 때
                        if(data_in == 0) begin
                            data_bits[DHT_DATA_BITS - 1 - bit_index] <= (high_counter > DHT_BIT_HIGH_0_US) ? 1'b1 : 1'b0;
                            bit_index <= bit_index + 1;   // 다음 비트 수신 준비
                            step <= 1;                    // 다시 step 1로 복귀 (다음 비트 수신 대기)

                            // 모든 40비트 수신이 끝났다면 완료 처리
                            if (bit_index == DHT_DATA_BITS - 1) begin
                                step <= 1;
                                us_counter <= 0;              // 타이머 초기화
                                dht11_state <= RX_DONE;       // 수신 완료 상태로 전이
                            end
                        end
                    end

                    // 공통 타임아웃: 응답 지연이나 비정상 타이밍 시 오류 상태 전이
                    if (us_counter > DHT_COMMON_TIMEOUT) begin
                        dht11_state <= RX_ERROR;
                        debug_state <= RX_DATA;              // 디버깅을 위해 현재 상태 저장
                    end
                end
            end

            RX_DONE: begin
                // 비트 파싱
                humidity_int <= data_bits[39:32];
                humidity_dec <= data_bits[31:24];
                temp_int     <= data_bits[23:16];
                temp_dec     <= data_bits[15:8];
                checksum     <= data_bits[7:0];

                // 체크섬 확인
                if ((data_bits[39:32] + data_bits[31:24] + data_bits[23:16] + data_bits[15:8]) == data_bits[7:0]) begin
                    data_valid <= 1'b1; // 1 클럭 동안 HIGH
                end else begin
                    debug_state <= RX_DONE;
                end

                dht11_state <= COOL_TIME;
                us_counter <= 0;              // 타이머 초기화
            end

            COOL_TIME: begin
                if(w_tick_us) begin
                    if (us_counter == COOL_TIME_US) begin
                        us_counter <= 0;
                        dht11_state <= IDLE;
                        data_out_en <= 0;
                        data_out <= 1;
                        step <= 0;

                        enable <= 1; // 다시 enable 상태로
                    end else begin
                        us_counter <= us_counter + 1;
                    end
                end
            end

            RX_ERROR: begin
                dht11_state <= COOL_TIME;
                us_counter <= 0;              // 타이머 초기화
            end

            default: dht11_state <= IDLE;

        endcase
    end
end
    // assign led[2:0] = debug_state;    // 하위 3비트: 디버그 상태
    // assign led[5:3] = dht11_state;    // 중간 3비트: FSM 상태
    // assign led[7:6] = step;           // 상위 2비트: step 단계 (1~3)

endmodule
