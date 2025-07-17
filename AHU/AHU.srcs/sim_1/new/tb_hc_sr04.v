`timescale 1ns / 1ps

module tb_hc_sr04;

    reg clk = 0;
    reg reset = 0;
    reg start = 1;  // active-low
    reg echo = 0;

    wire trigger;
    wire enable;
    wire [13:0] distance;

    // DUT 인스턴스
    hc_sr04 uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .echo(echo),
        .trigger(trigger),
        .enable(enable),
        .distance(distance)
    );

    // 100MHz 클럭 생성 (10ns 주기)
    always #5 clk = ~clk;

    // 1us 지연 함수
    task wait_us(input integer us);
        integer i;
        begin
            for (i = 0; i < us; i = i + 1)
                #(10); // 10ns * 100 = 1us
        end
    endtask

    initial begin
        $dumpfile("tb_hc_sr04.vcd");
        $dumpvars(0, tb_hc_sr04);

        // 초기화
        reset = 1;
        wait_us(5);
        reset = 0;
        echo = 0;

        // wait for enable HIGH
        wait (enable == 1);

        // 트리거 시작 (start active-low)
        start = 0;
        wait_us(20); // 약간 여유 있게
        start = 1;

        // 트리거 pulse 끝날 때까지 대기
        wait (trigger == 1);
        $display("[%t ns] Trigger HIGH 시작", $time);
        wait (trigger == 0);
        $display("[%t ns] Trigger 종료", $time);

        // echo HIGH 시작 (1160us → 약 20cm 거리)
        wait_us(200); // trigger 후 약간의 시간 후 echo HIGH 시작
        echo = 1;
        $display("[%t ns] Echo HIGH 시작", $time);
        #1160000;           // 1160us 유지 (직접 ns 단위로 줌)
        echo = 0;
        $display("[%t ns] Echo LOW (종료)", $time);

        // 거리 계산 끝날 때까지 enable HIGH 될 때까지 대기
        wait (enable == 1);
        $display("[%t ns] 거리 측정 완료: distance = %0d cm", $time, distance);

        wait_us(2000);
        $finish;
    end

endmodule
