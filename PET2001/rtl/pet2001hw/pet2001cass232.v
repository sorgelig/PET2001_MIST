`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
//
// Engineer:         	Thomas Skibo
// 
// Create Date:      	Oct 3, 2011
//
// Module Name:      	pet2001cass232
// Description:
//
//	A module that simulates a Pet cassette under control of
//	an RS232 running at 38,400 baud.
//
/////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011, Thomas Skibo.  All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
// * The names of contributors may not be used to endorse or promote products
//   derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL Thomas Skibo OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//
//////////////////////////////////////////////////////////////////////////////

module pet2001cass232(output		tx232,
                      input		rx232,
                      output reg	cts232n,

                      input		cass_motor_n,
                      input		cass_write,
                      output 		cass_read,

                      input		clk,
                      input		reset
	      );

    //////////////////////////////////////////////////////////////////////////
    // Run RS-232 at 38,400 baud.  Do sampling at 22,050 hz.
//`ifdef CLK100MHZ    
//    parameter RS232_CLK_DIV = 2604;
//    parameter SAMPLE_CLK_DIV = 4535;
//`elsif CLK25MHZ    
//    parameter RS232_CLK_DIV = 651;
//    parameter SAMPLE_CLK_DIV = 1134;
//`else
    parameter RS232_CLK_DIV = 1302;
    parameter SAMPLE_CLK_DIV = 2268;
//`endif

    reg 	samp_clk;
    reg [12:0] 	samp_clk_ctr;
    
    // free-running sample clock
    always @(posedge clk)
	if (reset || samp_clk)
            samp_clk_ctr <= (13'd0 + SAMPLE_CLK_DIV - 1);
	else
            samp_clk_ctr <= samp_clk_ctr - 1'b1;

    always @(posedge clk)
	if (reset)
            samp_clk <= 1'b0;
	else
            samp_clk <= (samp_clk_ctr == 13'd1);

    ///////////////////////////////////////////////////////////////////////////
    // UART
    wire        uart_write_rdy;
    wire [7:0] 	uart_write_data;
    reg       	uart_write_strobe;
    wire [7:0] 	uart_read_data;
    wire        uart_read_strobe;
   
    uart #(.CLK_DIVIDER(RS232_CLK_DIV))
	uart0(.serial_out(tx232),
              .serial_in(rx232),

              .write_rdy(uart_write_rdy),
              .write_data(uart_write_data),
              .write_strobe(uart_write_strobe),

              .read_data(uart_read_data),
              .read_strobe(uart_read_strobe),
              .reset(reset),
              .clk(clk)
          );

    ///////////////////////////////////////////////////////////////////////////
    // Cassette write (cass_write ---> tx232)
    // Enabled when motor comes on.
    //
    reg 	cass_write_active;
    reg [7:0] 	cass_write_sr;
    reg [2:0] 	cass_write_sr_ctr;

    // sample cassette write into a shift-register
    always @(posedge clk)
	if (reset)
            cass_write_sr <= 8'h00;
	else if (samp_clk)
            cass_write_sr <= { cass_write_sr[6:0], cass_write };

    assign uart_write_data = cass_write_sr;

    // count eight bits
    always @(posedge clk)
	if (reset || !cass_write_active)
            cass_write_sr_ctr <= 3'b000;
	else if (samp_clk)
            cass_write_sr_ctr <= cass_write_sr_ctr + 1'b1;

    // stretch cass_motor_n signal so we don't miss the last byte
    always @(posedge clk)
	if (reset)
            cass_write_active <= 1'b0;
	else if (!cass_motor_n)
            cass_write_active <= 1'b1;
        else if (cass_motor_n && samp_clk && cass_write_sr_ctr == 3'b111)
	    cass_write_active <= 1'b0;
    
    // generate strobe to uart.
    always @(posedge clk)
	if (reset)
            uart_write_strobe <= 1'b0;
	else
            uart_write_strobe <= uart_write_rdy && cass_write_active &&
				 cass_write_sr_ctr == 3'b111 && samp_clk;
    
`ifdef simulation
    // if we are going to fast (check baud, sample-rate params)
    always @(posedge clk)
	if (cass_write_active && cass_write_sr_ctr == 3'b111 && samp_clk &&
            !uart_write_rdy) begin
            $display("[%t] UART overflow on write!", $time);
            $stop;
	end
`endif

   
    ////////////////////// 16 byte receive FIFO   /////////////////////////////
    //
    wire [7:0]	fifo_data;
    wire        fifo_nempty;
    wire        fifo_nfull;
    wire        fifo_half_full;

    wire        cass_read_sr_strobe;

    my_fifo16 uartfifo(.rd_data(fifo_data),
                       .rd_rdy(fifo_nempty),
                       .rd_strobe(cass_read_sr_strobe),

                       .wr_data(uart_read_data),
                       .wr_rdy(fifo_nfull),
                       .wr_strobe(uart_read_strobe),

                       .halffull(fifo_half_full),

                       .clk(clk),
                       .reset(reset)
	       );

    // generate CTS signal with half-full indicator.
    always @(posedge clk)
	if (reset)
            cts232n <= 1'b1;
	else
            cts232n <= fifo_half_full;
    
    //////////////////////////////////////////////////////////////////////////
    // Cassette read (rx232 --> cass_read)
    //
    reg [7:0] 	cass_read_sr;
    reg [2:0] 	cass_read_sr_ctr;

    // an 8-bit shift register written by rs-232
    always @(posedge clk)
	if (reset)
            cass_read_sr <= 8'h00;
	else if (cass_read_sr_strobe)
            cass_read_sr <= fifo_data;
	else if (samp_clk)
            cass_read_sr <= { cass_read_sr[6:0] , cass_read_sr[0] };

    // count eight bits
    always @(posedge clk)
	if (reset || cass_read_sr_strobe)
            cass_read_sr_ctr <= 3'b000;
	else if (samp_clk && cass_read_sr_ctr != 3'b111)
            cass_read_sr_ctr <= cass_read_sr_ctr + 1'b1;

    assign cass_read = cass_read_sr[7];
    assign cass_read_sr_strobe = samp_clk && cass_read_sr_ctr == 3'b111 &&
                                 fifo_nempty && ! cass_motor_n;

endmodule // pet2001cass232

