/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains kuznechik_cipher_apb_wrapper
 *
 ***********************************************************************************/
 
package kuznechik_apb_p;

	enum {
        S_DOUT_R  = 32'h00000014,
        S_DIN_R   = 32'h00000004,
        S_CTRL_R  = 32'h00000000
    } kuznechik_cipher_apb_addr_start;

    enum {
    	A_CTRL  = 8'h00,

    	A_DIN_0 = 8'h04,
    	A_DIN_1 = 8'h08,
    	A_DIN_2 = 8'h0C,
    	A_DIN_3 = 8'h10,

    	A_DOUT_0 = 8'h14,
    	A_DOUT_1 = 8'h18,
    	A_DOUT_2 = 8'h1C,
    	A_DOUT_3 = 8'h20
    } kuznechik_cipher_apb_addr_space;

    parameter int RDATA_WIDTH = 12;

	typedef enum logic [1:0] {
		S_IDLE,
		S_SETUP
	} apb_state_t;

	typedef struct packed {
		logic [7:0] rst;
		logic [7:0] req_ack;
	} r_ctrl_t;

	typedef struct packed {
		logic [7:0] valid;
		logic [7:0] busy;
	} r_sts_t;

endpackage : kuznechik_apb_p

module kuznechik_cipher_apb_wrapper #(
		int AWIDTH = 32,
		int DWIDTH = 32
	)(
	    input 						pclk,
        input 						presetn,
        input [AWIDTH-1:0] 			paddr,
        input 						psel,
        input 						penable,
        input 						pwrite,
        input [31:0]				pwdata_i,
        input [3:0] 				pstrb,
        output  					pready,
        output logic [DWIDTH-1:0] 	prdata,
        output logic 				pslverr
    );

	import kuznechik_apb_p::*;

	logic [3:0][7:0] pwdata;

	assign pwdata[0] = pwdata_i[7:0];
	assign pwdata[1] = pwdata_i[15:8];
	assign pwdata[2] = pwdata_i[23:16];
	assign pwdata[3] = pwdata_i[31:24];

	// Defines
	logic [3:0][3:0][7:0] d_in, d_out;

	logic c_rst_n, c_valid, c_busy;


	// WR_REG
	r_ctrl_t r_ctrl;
	r_sts_t r_sts;


	apb_state_t state;

	// ===========================================

    assign pready = penable;

    // Errors
	logic apb_write_to_data_out;

	// ===========================================

	always_ff @(posedge pclk) begin : proc_wr_reg
		if(~presetn) begin
			r_ctrl.rst     <= 8'hF;
			r_ctrl.req_ack <= 8'h0;

			state <= S_IDLE;
		end else begin
			unique case (state)
				S_IDLE: begin

					state <= S_IDLE;

					if(psel) begin // A transaction request has arrived
						state <= S_SETUP; 

						if(~pwrite) begin // If reading, set the data for the next clock cycle
							unique case({paddr[7:2], 2'b00})

								A_CTRL: prdata 		<= {r_sts.busy, r_sts.valid, r_ctrl.req_ack, r_ctrl.rst};

								A_DIN_0: prdata   	<= d_in[0];
								A_DIN_1: prdata   	<= d_in[1];
								A_DIN_2: prdata   	<= d_in[2];
								A_DIN_3: prdata   	<= d_in[3];

								A_DOUT_0: prdata   	<= d_out[0];
								A_DOUT_1: prdata   	<= d_out[1];
								A_DOUT_2: prdata   	<= d_out[2];
								A_DOUT_3: prdata   	<= d_out[3];
								
								default : prdata <= {DWIDTH{1'b0}};
							endcase
						end else begin // ~apb.pwrite;

							if(~pslverr) begin

								case({paddr[7:2], 2'b00})
									A_CTRL: begin
										if(pstrb[0])
											r_ctrl.rst     <= pwdata[0];
										if(pstrb[1])
											r_ctrl.req_ack <= pwdata[1];

									end

									A_DIN_0: d_in[0] <= pstrb_sel(pstrb, d_in[0], pwdata);
									A_DIN_1: d_in[1] <= pstrb_sel(pstrb, d_in[1], pwdata);
									A_DIN_2: d_in[2] <= pstrb_sel(pstrb, d_in[2], pwdata);
									A_DIN_3: d_in[3] <= pstrb_sel(pstrb, d_in[3], pwdata);
									
									// default :;
								endcase

							end // ~pslverr
						end // apb.pwrite
					end // apb.psel
				end // S_IDLE
				S_SETUP: begin

					state <= S_SETUP;

					if(penable) begin
						state <= S_IDLE;

						if(!r_ctrl.rst   [0]) r_ctrl.rst     <= 8'b1; // Soft-сброс на 1 такт
            			if(r_ctrl.req_ack[0]) r_ctrl.req_ack <= 8'b0; // Запрос-ответ на 1 такт

					end // apb.penable

				end // S_SETUP
				default : state <= S_IDLE;
			endcase
		end
	end

	assign apb_write_to_data_out = paddr inside {[S_DOUT_R:S_DOUT_R + RDATA_WIDTH]};

	always_comb begin : proc_slv_err
        pslverr = 0;
       
        if((state == S_IDLE)  & penable)  pslverr = 1; 

        if((state == S_SETUP) & !penable) pslverr = 1;
        
        if(pwrite) begin
            if(({paddr[7:2],2'b0} == 8'h00) & (pstrb[3] | pstrb[2]))   pslverr = 1;

            if(apb_write_to_data_out) pslverr = 1;
            
            if(({paddr[7:2],2'b0} == 8'h00) & pstrb[1]  & r_sts.busy[0]) pslverr = 1;

        end
       
    end


// kuznechik connect
	assign c_rst_n = presetn & r_ctrl.rst[0];
	assign r_sts.valid = {7'b0, c_valid};
	assign r_sts.busy  = {7'b0, c_busy};

	kuznechik_cipher cipher_inst(
		.clk_i(pclk), .resetn_i(c_rst_n),
	    .request_i(r_ctrl.req_ack[0]), .ack_i(r_ctrl.req_ack[0]), .data_i(d_in),
		.busy_o(c_busy), .valid_o(c_valid), .data_o(d_out)
	);

	function logic [3:0][7:0] pstrb_sel(input logic [3:0] pstrb, input logic [3:0][7:0] word, input logic [3:0][7:0] pwdata);

		for(int i = 0; i < 4; i++)
			if(pstrb[i]) 
				pstrb_sel[i] = pwdata[i];
			else
				pstrb_sel[i] = word[i];

	endfunction : pstrb_sel


endmodule // kuznechik_cipher_apb_wrapper
