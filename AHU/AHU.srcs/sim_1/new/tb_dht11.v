`timescale 1ns / 1ps

module tb_dht11;

    reg clk = 0;
    reg reset = 0;
    reg start = 0;
    wire data;
    wire enable;
    wire data_valid;
    wire [7:0] humidity_int, humidity_dec, temp_int, temp_dec, checksum;

    // data를 제어하기 위한 reg (DHT11 역할)
    reg data_driver_en = 0;
    reg data_driver_value = 1;


    reg [39:0] bits;


    // inout 연결
    assign data = data_driver_en ? data_driver_value : 1'bz;

    // DUT
    dht11 uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .data(data),
        .enable(enable),
        .data_valid(data_valid),
        .humidity_int(humidity_int),
        .humidity_dec(humidity_dec),
        .temp_int(temp_int),
        .temp_dec(temp_dec),
        .checksum(checksum)
    );

    // 100MHz clock (10ns 주기)
    always #5 clk = ~clk;

    integer i;

    initial begin
        // 초기화
        reset = 1;
        #100;
        reset = 0;
        #100;
        // start 신호
        data_driver_en = 0;
        start = 1;
        #100;
        start = 0;

        // DHT11이 응답하기 전에 충분한 시간 대기 (20ms)
        #20_000_000;

        // === DHT11 응답 시퀀스 시작 ===

        // LOW 80us
        data_driver_en = 1;
        data_driver_value = 0;
        #100_000;

        // HIGH 80us
        data_driver_value = 1;
        #100_000;

        // ==== 데이터 전송 시작 ====
        // 전송 데이터: 0x37 0x00 0x17 0x00 0x4E
        // 즉, 습도: 55.0  온도: 23.0  체크섬: 78

        // 비트 스트림 (MSB부터)
        bits = {8'h37, 8'h00, 8'h17, 8'h00, 8'h4E}; // 40bit 패킷

        for (i = 39; i >= 0; i = i - 1) begin
            // LOW 50us (bit 시작)
            data_driver_value = 0;
            #50_000;

            // HIGH: bit 값에 따라 시간 다름
            data_driver_value = 1;
            if (bits[i] == 1)
                #70_000;  // 1일 때: HIGH 70us
            else
                #26_000;  // 0일 때: HIGH 26us
        end

        // 전송 종료 → high-Z
        data_driver_en = 0;

        // 수신 완료 대기
        wait (data_valid == 1);

        // 결과 출력
        $display("Humidity: %d.%d", humidity_int, humidity_dec);
        $display("Temperature: %d.%d", temp_int, temp_dec);
        $display("Checksum: %d", checksum);

        #100_000;
        $finish;
    end

endmodule
