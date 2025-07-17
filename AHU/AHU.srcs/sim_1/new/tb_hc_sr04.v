`timescale 1ns / 1ps

module tb_hc_sr04;

    // DUT 포트
    reg clk = 0;
    reg reset = 0;
    reg start = 1;          // active-low
    wire enable;
    wire trigger;
    reg echo = 0;
    wire [13:0] distance;

    // DUT 인스턴스
    hc_sr04 uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .enable(enable),
        .trigger(trigger),
        .echo(echo),
        .distance(distance)
    );

    // 클럭 생성 (100MHz)
    always #5 clk = ~clk;

    // 유틸리티: us 단위 딜레이 (100MHz 기준)
    task wait_us(input integer us);
        integer i;
        begin
            for (i = 0; i < us; i = i + 1)
                #(10);  // 10ns * 100 = 1us
        end
    endtask

    initial begin
        $dumpfile("hc_sr04_tb.vcd");
        $dumpvars(0, tb_hc_sr04);

        // 초기화
        reset = 1;
        wait_us(5);
        reset = 0;

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
        wait_us(2000);
        $finish;
    end

endmodule
