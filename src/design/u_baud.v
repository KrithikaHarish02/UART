`timescale 1ns/1ps
`default_nettype none

module baud_gen_div #(
    parameter integer SYS_CLK_FREQ=50_000_000,
    parameter integer BAUD_RATE= 9600)
    (
    input  wire sys_clk,
    input  wire sys_rst_l,
    output reg  tick);
localparam integer DIV_VALUE=SYS_CLK_FREQ/(BAUD_RATE*16);
reg [31:0] count;

always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l) begin
        count<=32'd0;
        tick<=1'b0;
    end else begin
        if (count==DIV_VALUE-1) begin
            count<=32'd0;
            tick<=1'b1;
        end else begin
            count<=count + 32'd1;
            tick<=1'b0;
        end
    end
end

endmodule
