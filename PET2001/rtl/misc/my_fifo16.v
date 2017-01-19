`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:	Thomas Skibo
// 
// Create Date: 23:41:26 12/09/2007 
// Design Name: 
// Module Name: my_fifo16
//
// Description:
//	A simple, synchronous 16 byte FIFO.  Commonly used with uart.
//
//
//////////////////////////////////////////////////////////////////////////////
//2017 Fifo Buffer Changed in Size and FPGA Type by Gehstock
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2007, Thomas Skibo.  All rights reserved.
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

module my_fifo16(output [7:0]	rd_data,
		 output         rd_rdy,
		 input          rd_strobe,
		 input [7:0]    wr_data,
		 output         wr_rdy,
		 input          wr_strobe,

		 output		halffull,

		 input          clk,
		 input          reset
	 );

    reg [3:0]	wr_ptr;
    reg [3:0] 	rd_ptr;
    reg [4:0] 	count;

    // FIFO write pointer
    always @(posedge clk)
	if (reset)
            wr_ptr <= 4'd0;
	else if (wr_strobe && wr_rdy)
            wr_ptr <= wr_ptr + 4'd1;

    // FIFO read pointer
    always @(posedge clk)
	if (reset)
            rd_ptr <= 4'd0;
	else if (rd_strobe && rd_rdy)
            rd_ptr <= rd_ptr + 4'd1;

    // Count number of bytes in FIFO
    always @(posedge clk)
	if (reset)
            count <= 5'd0;
	else if (rd_strobe && rd_rdy && !wr_strobe)
            count <= count - 5'd1;
	else if (wr_strobe && wr_rdy && !rd_strobe)
	    count <= count + 5'd1;
   
    assign rd_rdy = (count != 5'd0);
    assign wr_rdy = (count != 5'd16);
    assign halffull = (count >= 5'd8);

    // FIFO 8x16 RAM built from 16x1 Spartan RAMs
    genvar i;
    generate
	for (i=0; i<8; i=i+1) begin:rams
            RAM16X1D ram(.q(wr_data[i]),
                         .wraddress(wr_ptr),
                         .clock(clk),
                         .wren(wr_strobe),
                         .data(rd_data[i]),
                         .rdaddress(rd_ptr)
		 );
	end
    endgenerate
  
endmodule // my_fifo16

