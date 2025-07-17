`timescale 1ns / 1ps

module uart_controller(

    input clk, 
    input reset,
    input [13:0] send_data,
    input rx,
    output tx,
    output [7:0] rx_data,
    output rx_done

    );

    wire w_tick_1Hz;
    wire [7:0] w_tx_data;

    tick_generator #(
        .INPUT_FREQ(100_000_000),
        .TICK_HZ(1) 
    ) u_tick_1Hz (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1Hz)
    );

    wire [7:0] data_out;
    wire w_tx_busy;

    data_sender u_data_sender (
        .clk(clk), 
        .reset(reset),
        .start_trigger(w_tick_1Hz),
        .send_data(send_data),
        .tx_busy(w_tx_busy),
        .tx_done(tx_done),
        .tx_start(tx_start),    // 1bit wire라 선언 없이 사용
        .tx_data(w_tx_data)
    ); 


    uart_tx u_uart_tx (
        .clk(clk), 
        .reset(reset),
        .tx_data(w_tx_data),
        .tx_start(tx_start),    // 1bit wire라 선언 없이 사용
        .tx(tx),
        .tx_busy(w_tx_busy),
        .tx_done(tx_done)
    );

    uart_rx u_uart_rx (
        .clk(clk), 
        .reset(reset),
        .rx(rx),
        .data_out(rx_data),  
        .rx_done(rx_done)
    );


endmodule
