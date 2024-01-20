/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains kuznechik_cipher module
 *
 ***********************************************************************************/

package kuznechik_cipher_p;
    typedef enum logic [4:0] {
        S_IDLE  = 5'b00001,
        S_KEYP  = 5'b00010,
        S_SP    = 5'b00100,
        S_LP    = 5'b01000,
        S_FIN   = 5'b10000
    } states_t;

    enum logic {
        NO  = 1'b0,
        YES = 1'b1
    } condition_t;
endpackage : kuznechik_cipher_p

module kuznechik_cipher(
    input               clk_i,л
                        resetn_i,
                        request_i,
                        ack_i,
                [127:0] data_i,

    output                busy_o,
           logic          valid_o,
           logic  [127:0] data_o
);

import kuznechik_cipher_p::*;

logic [127:0] key_mem [0:9];

logic [7:0] S_box_mem [0:255];

logic [7:0] L_mul_16_mem  [0:255];
logic [7:0] L_mul_32_mem  [0:255];
logic [7:0] L_mul_133_mem [0:255];
logic [7:0] L_mul_148_mem [0:255];
logic [7:0] L_mul_192_mem [0:255];
logic [7:0] L_mul_194_mem [0:255];
logic [7:0] L_mul_251_mem [0:255];

initial begin
    $readmemh("keys.mem",key_mem );
    $readmemh("S_box.mem",S_box_mem );

    $readmemh("L_16.mem", L_mul_16_mem );
    $readmemh("L_32.mem", L_mul_32_mem );
    $readmemh("L_133.mem",L_mul_133_mem);
    $readmemh("L_148.mem",L_mul_148_mem);
    $readmemh("L_192.mem",L_mul_192_mem);
    $readmemh("L_194.mem",L_mul_194_mem);
    $readmemh("L_251.mem",L_mul_251_mem);
end

localparam int ROUND_CNT  = 10;
localparam int LIN_CNT    = 16; 
localparam int DATA_WIDTH = 128;

states_t state, next_state;

logic [127:0] data_tmp;

logic [$clog2(ROUND_CNT)-1:0] round_cnt;
logic [$clog2(LIN_CNT)-1:0] lin_cnt;

logic valid;
// assign busy_o = state != S_IDLE;
logic busy;
assign busy_o = busy;

assign valid_o = valid;

wire [7:0] line_shift = L_mul_148_mem[data_tmp[127:120]] ^ L_mul_32_mem[data_tmp[119:112]]  ^ L_mul_133_mem[data_tmp[111:104]]  ^ L_mul_16_mem[data_tmp[103:96]] 
            ^ L_mul_194_mem[data_tmp[95:88]] ^ L_mul_192_mem[data_tmp[87:80]]   ^ data_tmp[79:72]                   ^ L_mul_251_mem[data_tmp[71:64]] 
            ^ data_tmp[63:56]                ^ L_mul_192_mem[data_tmp[55:48]]   ^ L_mul_194_mem[data_tmp[47:40]]    ^ L_mul_16_mem[data_tmp[39:32]] 
            ^ L_mul_133_mem[data_tmp[31:24]] ^ L_mul_32_mem[data_tmp[23:16]]    ^ L_mul_148_mem[data_tmp[15:8]]     ^ data_tmp[7:0];

wire [127:0] non_linear_tmp;   

generate
    genvar k;

    for(k = 0; k < 16; k = k + 1)
        assign non_linear_tmp[8 * ( k + 1 ) - 1 : 8 * k] = S_box_mem[data_tmp[8 * ( k + 1 ) - 1 : 8 * k]];

endgenerate

always_ff @(posedge clk_i) begin : proc_state_t
    if(~resetn_i) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end

always_comb begin : proc_state
    unique case (state)
        S_IDLE: next_state = request_i ? S_KEYP : S_IDLE;

        S_KEYP: next_state = (round_cnt == ROUND_CNT - 1) ? S_FIN : S_SP;        

        S_SP :  next_state = S_LP;

        S_LP:   next_state = (lin_cnt == LIN_CNT - 1) ? S_KEYP : S_LP;

        S_FIN:  next_state = ack_i ? S_IDLE : S_FIN;

    default : next_state = S_IDLE;
    endcase
end


always_ff @(posedge clk_i) begin : proc_ctrl
    if(~resetn_i) begin
        valid <= NO;
        round_cnt <= {ROUND_CNT{1'b0}};
        busy <= 1'b0;
    end else begin
        unique case (state)
            S_IDLE: begin

                round_cnt <= {ROUND_CNT{1'b0}};
                lin_cnt   <= {LIN_CNT{1'b0}};
                valid     <= NO;

                data_tmp <= request_i ? data_i : data_tmp;
                busy     <= request_i ? 1'b1 : 1'b0;

            end // S_IDLE

            S_KEYP: begin

                if(round_cnt == ROUND_CNT - 1) begin // If 10 rounds have passed
                    valid  <= YES;
                    busy   <= 1'b0;
                    data_o <= data_tmp ^ key_mem[round_cnt];
                end else begin
                    data_tmp  <= data_tmp ^ key_mem[round_cnt]; // Key overlay
                    round_cnt <= round_cnt + 1'b1;
                end

                // data_tmp <= data_tmp ^ key_mem[round_cnt]; // Key overlay
                // round_cnt <= round_cnt + 1'b1;
            end // S_KEYP
            S_SP : begin
                
                data_tmp <= non_linear_tmp;

            end
            S_LP: begin
                data_tmp <= {line_shift, data_tmp[DATA_WIDTH-1:8]}; // Linear transformation
                lin_cnt <= lin_cnt + 1'b1;
            end
            S_FIN: begin

                valid <= ack_i ? NO : valid;

            end
        default : begin
            valid     <= valid;
            data_o    <= data_o;
            data_tmp  <= data_tmp;
            lin_cnt   <= lin_cnt;
            round_cnt <= round_cnt;
        end
        endcase
    end
end
endmodule
