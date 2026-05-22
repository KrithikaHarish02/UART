
module u_rec #(
    parameter width = 8
)(
    input  wire             uart_clk,
    input  wire             sys_rst,
    input  wire             uart_REC_dataH,
    output reg              rec_readyH,
    output reg  [width-1:0] rec_dataH,
    output reg              rec_busyH
);

reg [3:0] count; 
reg [3:0] count_4bit;
reg       sync_ff1, sync_ff2;
reg [width-1:0] rx_shift_reg;

localparam [1:0] idle           = 2'd0,
                 receiving_data = 2'd1,
                 stopbit        = 2'd2;
reg [1:0] current_state, next_state;

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        sync_ff1 <= 1'b1;
        sync_ff2 <= 1'b1;
    end else begin
        sync_ff1 <= uart_REC_dataH;
        sync_ff2 <= sync_ff1;
    end
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        count_4bit <= 4'd0;
    end else if (current_state == idle) begin
        if (sync_ff2 == 1'b0)
            count_4bit <= count_4bit + 1'b1;
        else
            count_4bit <= 4'd0;
    end else begin
        count_4bit <= count_4bit + 1'b1;
    end
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) 
        count <= 0;
    else if (current_state == receiving_data && count_4bit == 4'd15) 
        count <= count + 1'b1;
    else if (current_state != receiving_data) 
        count <= 0;
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) 
        current_state <= idle;
    else 
        current_state <= next_state;
end

always @(*) begin
    case (current_state)
        idle: begin
            if (sync_ff2 == 1'b0 && count_4bit == 4'd7)
                next_state = receiving_data;
            else
                next_state = idle;
        end
        receiving_data: begin
            if (count == width - 1 && count_4bit == 4'd15)
                next_state = stopbit;
            else
                next_state = receiving_data;
        end
        stopbit: begin
            if (count_4bit == 4'd15)
                next_state = idle;
            else
                next_state = stopbit;
        end
        default: next_state = idle;
    endcase
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        rec_busyH  <= 1'b0;
        rec_readyH <= 1'b0;
        rec_dataH  <= 0;
    end else begin
        case (next_state)
            idle: begin 
                rec_busyH <= 1'b0;
                if (current_state == stopbit && sync_ff2 == 1'b1) begin
                    rec_readyH <= 1'b1;
                    rec_dataH  <= rx_shift_reg;
                end else if (current_state == idle) begin
                    rec_readyH <= rec_readyH;
                end else begin
                    rec_readyH <= 1'b0;
                end
            end
            receiving_data: begin 
                rec_busyH  <= 1'b1; 
                rec_readyH <= 1'b0; 
            end
            stopbit: begin 
                rec_busyH  <= 1'b1; 
                rec_readyH <= 1'b0; 
            end
            default: begin 
                rec_busyH  <= 1'b0; 
                rec_readyH <= 1'b0; 
            end
        endcase
    end
end

always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        rx_shift_reg <= 0;
    end else if (current_state == receiving_data && count_4bit == 4'd7) begin
        rx_shift_reg <= {sync_ff2, rx_shift_reg[width-1:1]};
    end
end

endmodule

