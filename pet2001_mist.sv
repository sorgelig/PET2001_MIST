`timescale 1ns / 1ps
//Pet2001 Mist Toplevel 2017 Gehstock

module pet2001_mist
(	
	output       LED,						
	output [5:0] VGA_R,
	output [5:0] VGA_G,
	output [5:0] VGA_B,
	output       VGA_HS,
	output       VGA_VS,
	output       AUDIO_L,
	output       AUDIO_R,	
	input        SPI_SCK,
	output       SPI_DO,
	input        SPI_DI,
	input        SPI_SS2,
	input        SPI_SS3,
	input        CONF_DATA0,
	input        CLOCK_27
);

//////////////////////////////////////////////////////////////////////
//  ARM I/O                                                         //
//////////////////////////////////////////////////////////////////////
wire  [7:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        ps2_kbd_clk, ps2_kbd_data;

localparam CONF_STR = 
{
		  "PET2001;TAP;",
//		  "O1,Romtype,Level I,Level II;",
		  "O2,Screen Color,White,Green;",
		  "O3,Diag,Off,On(needs Reset);",
		  "O56,Scanlines,None,25%,50%,75%;",
        "T4,Reset;",
		  "V,v0.4;"
};


user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io
(
	.clk_sys        (clk            ),
	.conf_str       (CONF_STR       ),
	.SPI_SCK        (SPI_SCK        ),
	.CONF_DATA0     (CONF_DATA0     ),
	.SPI_SS2			 (SPI_SS2        ),
	.SPI_DO         (SPI_DO         ),
	.SPI_DI         (SPI_DI         ),
	.buttons        (buttons        ),
	.switches   	 (switches       ),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr          (ypbpr          ),
	.ps2_kbd_clk    (ps2_kbd_clk    ),
	.ps2_kbd_data   (ps2_kbd_data   ),
	.status         (status         )
);

//////////////////////////////////////////////////////////////////////
// Global Clock and System Reset.                //
//////////////////////////////////////////////////////////////////////
wire clk;
wire locked;

pll pll_inst
(
	.inclk0	(CLOCK_27),
	.c0		(clk),     //56Mhz
	.locked	(locked)
);

reg       reset = 1;
wire      RESET = status[0] | status[4];// | buttons[1];//Uses for Tape loading
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
// Clocks													     		//
////////////////////////////////////////////////////////////////////
reg  ce_14mp;
reg  ce_7mp;
reg  ce_7mn;
reg  ce_1m;
reg  ce_500k;

always @(negedge clk) begin
	reg  [3:0] div = 0;
	reg  [5:0] cpu_div = 0;
	reg  [6:0] tape_div = 0;

	div <= div + 1'd1;
	ce_14mp <= !div[1] & !div[0];
	ce_7mp  <= !div[2] & !div[1:0];
	ce_7mn  <=  div[2] & !div[1:0];
	
	cpu_div <= cpu_div + 1'd1;
	if(cpu_div == 55) cpu_div <= 0;
	ce_1m <= !cpu_div;

	tape_div <= tape_div + 1'd1;
	if(tape_div == 111) tape_div <= 0;
	ce_500k <= !tape_div;
end


///////////////////////////////////////////////////
// CPU
///////////////////////////////////////////////////

wire [15:0] addr;
wire [7:0] 	cpu_data_out;
wire [7:0] 	cpu_data_in;

wire we;
wire rdy;
wire nmi;
wire irq;

cpu6502 cpu
(
	.*,
	.data_out(cpu_data_out),
	.data_in(cpu_data_in)
);

///////////////////////////////////////////////////
// Commodore Pet hardware
///////////////////////////////////////////////////

wire pix;
wire HSync, VSync;
wire audioDat;

pet2001hw hw
(
	.*,
	.data_out(cpu_data_in),
	.data_in(cpu_data_out),

	.cass_motor_n(),
	.cass_write(),
	.audio(audioDat),
	.cass_sense_n(),
	.cass_read(tape_data),
	.tape_data(),
	.diag_l(!status[3]),

	.clk_speed(0),
	.clk_stop(0)
);

////////////////////////////////////////////////////////////////////
// Video 																			   //
////////////////////////////////////////////////////////////////////			

wire [7:0] G = {pix,pix,pix,pix,pix,pix,pix,pix};
wire [7:0] R = status[2] ? 8'd0 : G;
wire [7:0] B = R;

video_mixer #(10'd0, 10'd0, 3'd4) video_mixer
(
	.*,
	.clk_sys(clk),
	.ce_x2(ce_14mp),
	.ce_x1(ce_7mp),

	.scanlines(status[6:5]),
	.ypbpr_full(1)
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

	.clk        ( clk          ),
	.ce_500k    ( ce_500k      ),
	.play       ( buttons[1]   ),
   .tape_out   ( tape_data    )
);


//////////////////////////////////////////////////////////////////////
// PS/2 to PET keyboard interface
//////////////////////////////////////////////////////////////////////
wire [7:0] 	keyin;
wire [3:0] 	keyrow;	 

keyboard keyboard(.*, .Fn(), .mod());

endmodule // pet2001

