`timescale 1ns/1ps
`default_nettype none

module uart_top #(
    parameter integer SYS_CLK_FREQ = 50_000_000,
    parameter integer BAUD_RATE    = 9600
)(
    input wire sys_clk,
    input wire sys_rst_l,
    input wire xmitH,
    input wire [7:0] xmit_dataH,
    input wire uart_REC_dataH,
    output wire uart_XMIT_dataH,
    output wire xmit_doneH,
    output wire xmit_active,
    output wire [7:0] rec_dataH,
    output wire rec_readyH,
    output wire rec_busy,
    output wire frame_errorH
);

wire tick;

baud_gen_div #(
    .SYS_CLK_FREQ(SYS_CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)) u_baud_gen (
    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),
    .tick(tick));

uart_transmitter u_tx (
    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),
    .tick(tick),
    .xmitH(xmitH),
    .xmit_dataH(xmit_dataH),
    .uart_XMIT_dataH(uart_XMIT_dataH),
    .xmit_doneH(xmit_doneH),
    .xmit_active(xmit_active));

uart_receiver u_rx (
    .sys_clk(sys_clk),
    .sys_rst_l(sys_rst_l),
    .tick(tick),
    .uart_REC_dataH(uart_REC_dataH),
    .rec_dataH(rec_dataH),
    .rec_readyH (rec_readyH),
    .rec_busy(rec_busy),
    .frame_errorH(frame_errorH));

endmodule
