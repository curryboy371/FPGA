`timescale 1ns / 1ps

module tb_hc_sr04;

<<<<<<< HEAD
    reg clk = 0;
    reg reset = 0;
    reg start = 1;  // active-low
    reg echo = 0;

    wire trigger;
    wire enable;
=======
    // DUT 포트
    reg clk = 0;
    reg reset = 0;
    reg start = 1;          // active-low
    wire enable;
    wire trigger;
    reg echo = 0;
>>>>>>> 134525a36c2a604b3872dcf31189640a4c7bab1c
    wire [13:0] distance;

    // DUT 인스턴스
    hc_sr04 uut (
        .clk(clk),
        .reset(reset),
        .start(start),
<<<<<<< HEAD
        .echo(echo),
        .trigger(trigger),
        .enable(enable),
        .distance(distance)
    );

    // 100MHz 클럭 생성 (10ns 주기)
    always #5 clk = ~clk;

    // 1us 지연 함수
=======
        .enable(enable),
        .trigger(trigger),
        .echo(echo),
        .distance(distance)
    );

    // 클럭 생성 (100MHz)
    always #5 clk = ~clk;

    // 유틸리티: us 단위 딜레이 (100MHz 기준)
>>>>>>> 134525a36c2a604b3872dcf31189640a4c7bab1c
    task wait_us(input integer us);
        integer i;
        begin
            for (i = 0; i < us; i = i + 1)
<<<<<<< HEAD
                #(10); // 10ns * 100 = 1us
=======
                #(10);  // 10ns * 100 = 1us
>>>>>>> 134525a36c2a604b3872dcf31189640a4c7bab1c
        end
    endtask

    initial begin
<<<<<<< HEAD
        $dumpfile("tb_hc_sr04.vcd");
=======
        $dumpfile("hc_sr04_tb.vcd");
>>>>>>> 134525a36c2a604b3872dcf31189640a4c7bab1c
        $dumpvars(0, tb_hc_sr04);

        // 초기화
        reset = 1;
        wait_us(5);
        reset = 0;
<<<<<<< HEAD
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

=======

        // wait for enable
        wait (enable == 1);

        // ★ 시나리오 1: 정상 측정 흐름 ★
        $display("Start test at time %t", $time);

        // start 신호 활성화 (active-low)
        start = 0;
        wait_us(20); // 충분히 잡음 방지
        start = 1;

        // trigger 구간을 기다린다
        wait (trigger == 1);
        $display("Trigger ON at time %t", $time);
        wait (trigger == 0);
        $display("Trigger OFF at time %t", $time);

        // 일정 시간 후 echo HIGH (물체 반사 시점)
        wait_us(1000);    // 약 1160us 동안 echo HIGH → 1160 / 58 = 약 20cm
        echo = 1;
        $display("ECHO ON at time %t", $time);


        // 거리 측정 완료까지 대기
        wait (enable == 1); // 다음 사이클 enable 될 때까지

        $display("Measured distance = %0d cm", distance); // 기대: 약 20cm

        // 끝
>>>>>>> 134525a36c2a604b3872dcf31189640a4c7bab1c
        wait_us(2000);
        $finish;
    end

endmodule
