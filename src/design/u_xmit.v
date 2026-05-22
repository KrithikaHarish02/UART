module transmitter #(
    parameter width = 8
)(
    input  wire             uart_clk,
    input  wire             sys_rst,
    input  wire             xmitH,
    input  wire [width-1:0] xmit_dataH,
    output reg              xmit_done,
    output reg              xmit_active,
    output reg              uart_XMIT_dataH
);

localparam [1:0] idle           = 2'd0,
                 send_startbit  = 2'd1,
                 send_data      = 2'd2,
                 send_stopbit   = 2'd3;

reg [1:0]  current_state, next_state;
reg [3:0]  count_4bit;
reg [3:0]  count;
reg [width-1:0] temp_data;

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) 
        count_4bit <= 4'd0;
    else if (current_state == idle) 
        count_4bit <= 4'd0;
    else 
        count_4bit <= count_4bit + 1'b1;
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) 
        count <= 0;
    else if (current_state == send_data && count_4bit == 4'd15) 
        count <= count + 1'b1;
    else if (current_state != send_data) 
        count <= 0;
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) 
        temp_data <= 0;
    else if (current_state == idle) 
        temp_data <= xmit_dataH;
    else if (current_state == send_data && count_4bit == 4'd15) 
        temp_data <= temp_data >> 1;
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) current_state <= idle;
    else          current_state <= next_state;
end

always @(*) begin
    case (current_state)
        idle:          next_state = xmitH ? send_startbit : idle;
        send_startbit: next_state = (count_4bit == 4'd15) ? send_data : send_startbit;
        send_data:     next_state = (count_4bit == 4'd15 && count == width - 1) ? send_stopbit : send_data;
        send_stopbit:  next_state = (count_4bit == 4'd15) ? idle : send_stopbit;
        default:       next_state = idle;
    endcase
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        uart_XMIT_dataH <= 1'b1;
        xmit_done       <= 1'b0;
        xmit_active     <= 1'b0;
    end else begin
        case (next_state)
            idle: begin
                uart_XMIT_dataH <= 1'b1;
                xmit_done       <= 1'b1;
                xmit_active     <= 1'b0;
            end
            send_startbit: begin
                uart_XMIT_dataH <= 1'b0;
                xmit_done       <= 1'b0;
                xmit_active     <= 1'b1;
            end
            send_data: begin
                uart_XMIT_dataH <= temp_data[0];
                xmit_done       <= 1'b0;
                xmit_active     <= 1'b1;
            end
            send_stopbit: begin
                uart_XMIT_dataH <= 1'b1;
                xmit_done       <= 1'b0;
                xmit_active     <= 1'b1;
            end
            default: begin
                uart_XMIT_dataH <= 1'b1;
                xmit_done       <= 1'b0;
                xmit_active     <= 1'b0;
            end
        endcase
    end
end

endmodule
