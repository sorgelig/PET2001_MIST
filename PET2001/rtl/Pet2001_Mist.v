`timescale 1ns / 1ps
//Pet2001 Mist Toplevel 2017 Gehstock

module pet2001_mist(	
				output 				LED,						
				output[5:0]   		VGA_R,
				output[5:0]   		VGA_G,
				output[5:0]   		VGA_B,
				output         	VGA_HS,
				output         	VGA_VS,
				output         	AUDIO_L,
				output         	AUDIO_R,	
				input         		SPI_SCK,
				output        		SPI_DO,
				input         		SPI_DI,
				input         		SPI_SS2,
				input         		SPI_SS3,
				input					SPI_SS4,
				input         		CONF_DATA0,
				input          	CLOCK_27
	);
//////////////////////////////////////////////////////////////////////
//  ARM I/O                                                         //
//////////////////////////////////////////////////////////////////////
wire  [7:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ps2_kbd_clk, ps2_kbd_data;

parameter CONF_STR = {
		  "PET2001;TAP;",//12
//		  "O1,Romtype,Level I,Level II;",//28
		  "O2,Screen Color,Green,White;",//28
		  "O3,Diag,Off,On(needs Reset);",//28
		  "O4,Scanlines,Off,On;",//20
        "T5,Reset;",//9
		  "V,v0.3;"//7
};

parameter CONF_STR_LEN = 12+28+28+28+20+9+7    -28;  


user_io #(.STRLEN(CONF_STR_LEN)) user_io ( 
      .conf_str       ( CONF_STR       ),
      .SPI_CLK        ( SPI_SCK        ),
      .SPI_SS_IO      ( CONF_DATA0     ),
//		.SPI_SS2			 ( SPI_SS2        ),
      .SPI_MISO       ( SPI_DO         ),
      .SPI_MOSI       ( SPI_DI         ),
		.buttons        ( buttons        ),
		.switches   	 ( switches			),
//		.scandoubler_disable(scandoubler_disable),
      .ps2_clk        ( clk_ps2        ),
      .ps2_kbd_clk    ( ps2_kbd_clk    ),
      .ps2_kbd_data   ( ps2_kbd_data   ),
      .sd_lba         ( sd_lba 			),
      .sd_rd          ( sd_rd 			),
      .sd_wr          ( sd_wr 			),
      .sd_ack         ( sd_ack 			),
      .sd_conf        ( sd_conf 			),
      .sd_sdhc        ( sd_sdhc 			),
      .sd_dout        ( sd_dout 			),
      .sd_dout_strobe ( sd_dout_strobe ),
      .sd_din         ( sd_din 			),
      .sd_din_strobe  ( sd_din_strobe 	),
//    .sd_change      ( sd_change 		),
      .status         ( status         )
);

wire sd_dat;
wire sd_dat3;
wire sd_cmd;
wire sd_clk;

wire sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack;
wire sd_conf;
wire sd_sdhc;
wire sd_dout;
wire sd_dout_strobe;
wire sd_din;
wire sd_din_strobe;

sd_card sd_card (
	// connection to io controller
   .io_lba         ( sd_lba         ),
   .io_rd          ( sd_rd          ),
   .io_wr          ( sd_wr          ),
   .io_ack         ( sd_ack         ),
   .io_conf        ( sd_conf        ),
   .io_sdhc        ( sd_sdhc        ),
   .io_din         ( sd_dout        ),
  .io_din_strobe  ( sd_dout_strobe ),
   .io_dout        ( sd_din         ),
   .io_dout_strobe ( sd_din_strobe  ),
 
   .allow_sdhc     ( 1'b1           ),

   // connection to host
   .sd_cs          ( sd_dat3        ),
   .sd_sck         ( sd_clk         ),
   .sd_sdi         ( sd_cmd         ),
   .sd_sdo         ( sd_dat         )
);



wire clk;
wire clk_ps2;
wire clk_500k;
wire locked;

//////////////////////////////////////////////////////////////////////
// Global Clock and System Reset.                //
//////////////////////////////////////////////////////////////////////
	 pll pll_inst
	(
		.inclk0	(CLOCK_27),
		.c0		(clk),//50Mhz
		.c1		(clk_ps2),//12Khz
		.c2		(clk_500k),//500Khz
		.locked	(locked)
	);

	
reg       reset = 1;
wire      RESET = status[0] | status[5];// | buttons[1];//Uses for Tape loading
always @(posedge clk) begin
	integer   initRESET = 100000000;
	reg [3:0] reset_cnt;

	if ((!RESET && reset_cnt==4'd14) && !initRESET)
		reset <= 0;
	else begin
		if(initRESET) initRESET <= initRESET - 1;
		reset <= 1;
		reset_cnt <= reset_cnt+4'd1;
	end
end


////////////////////////////////////////////////////////////////////
// Top level module													     		//
////////////////////////////////////////////////////////////////////
wire  [5:0] R_out;
wire  [5:0] G_out;
wire  [5:0] B_out;
wire        HSync, VSync;
wire audioDat;

    pet2001_top pet_top(
			.vgaRed(R_out),
			.vgaGreen(G_out),
			.vgaBlue(B_out),
			.Hsync(HSync),
			.Vsync(VSync),
			.keyrow(keyrow),
			.keyin(keyin),	
			.cass_motor_n(),
			.cass_write(),
			.cass_sense_n(),
			.cass_read(tape_data),
			.tape_data(),
			.audio(audioDat),
			.diag_l(!status[3]),        
			.clk_speed(),
			.clk_stop(),
			.video_green(!status[2]),
			.clk(clk),
			.reset(reset)
		);
		

////////////////////////////////////////////////////////////////////
// OSD 																			   //
////////////////////////////////////////////////////////////////////			
osd #(10'd0,10'd0,3'd7) osd
(
	.red_in(R_out),
	.green_in(G_out),
	.blue_in(B_out),
	.hs_in(HSync),
	.vs_in(VSync),
	.red_out(VGA_R),
	.green_out(VGA_G),
	.blue_out(VGA_B),
	.hs_out(VGA_HS),
	.vs_out(VGA_VS),
	.pclk(CLOCK_27),
	.sck(SPI_SCK),
	.ss(SPI_SS3),
	.sdi(SPI_DI),
	.scanline_ena_h(status[4])
);


////////////////////////////////////////////////////////////////////
// Audio 																			//
////////////////////////////////////////////////////////////////////		
// use a pwm to reduce audio output volume
reg [7:0] aclk;
always @(posedge CLOCK_27) 
	aclk <= aclk + 8'd1;

// limit volume to 1/8 => pwm < 32 
wire tape_audio = tape_data && (aclk < 32);//only needed for Debug

assign AUDIO_R = AUDIO_L;
sigma_delta_dac #(.MSBI(9)) dac
(
	.CLK(clk),
	.RESET(reset),
	.DACin({1'b0, audioDat,tape_audio, 6'b000000}),
	.DACout(AUDIO_L)
);


assign LED = !tape_data;


wire tape_data;	
tape tape (
	// spi interface to io controller
   .sdi        ( SPI_DI       ),
   .sck        ( SPI_SCK      ),
   .ss         ( SPI_SS2      ),

	.clk        ( clk_500k     ),
	.play       ( buttons[1]   ),
   .tape_out   ( tape_data    )
);


 //   assign	JB[0] = audio;
 //   assign	JB[1] =	cass_write;
 //   assign	JB[2] =	cass_read;
 //   assign	JB[3] = ~cass_motor_n;

//////////////////////////////////////////////////////////////////////
// RS-232 to Cassette Interface
//////////////////////////////////////////////////////////////////////

 //   wire        Rs232CtsN;
   
 //   pet2001cass232 cass(.tx232(Rs232TxD),
//			.rx232(Rs232RxD),
//			.cts232n(Rs232CtsN),

//			.cass_motor_n(cass_motor_n),
//			.cass_write(cass_write),
//			.cass_read(cass_read),

//			.clk(clk),
//			.reset(reset)
//		);

  //  assign JA[3] = Rs232CtsN;

//////////////////////////////////////////////////////////////////////
// PS/2 to PET keyboard interface
//////////////////////////////////////////////////////////////////////
wire [7:0] 	keyin;
wire [3:0] 	keyrow;	 

    pet2001ps2_key ps2key(
			  .keyin(keyin),
			  .keyrow(keyrow),			  
			  .ps2_clk(ps2_kbd_clk),
			  .ps2_data(ps2_kbd_data),
			  .clk(clk),
			  .reset(reset)
		  );

    
endmodule // pet2001

