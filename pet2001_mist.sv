`timescale 1ns / 1ps
//Pet2001 Mist Toplevel 2017 Gehstock

module pet2001_mist
(	
	output        LED,						
	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        AUDIO_L,
	output        AUDIO_R,	
	input         SPI_SCK,
	output        SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,
	input         CLOCK_27,

   output [12:0] SDRAM_A,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nWE,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nCS,
   output  [1:0] SDRAM_BA,
   output        SDRAM_CLK,
   output        SDRAM_CKE
);


//////////////////////////////////////////////////////////////////////
//  MiST I/O                                                         //
//////////////////////////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        ps2_kbd_clk, ps2_kbd_data;

localparam CONF_STR = 
{
	"PET2001;TAP;",
// "O1,Romtype,Level I,Level II;",
   "O7,Fast TAP loading,On,Off;",
	"O2,Screen Color,White,Green;",
	"O3,Diag,Off,On(needs Reset);",
	"O56,Scanlines,None,25%,50%,75%;",
	"T4,Reset;",
	"V,v0.5;"
};

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

mist_io #(.STRLEN(($size(CONF_STR)>>3))) mist_io
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
	.status         (status         ),
	
	.ioctl_download (ioctl_download ),
	.ioctl_index    (ioctl_index    ),
	.ioctl_wr       (ioctl_wr       ),
	.ioctl_addr     (ioctl_addr     ),
	.ioctl_dout     (ioctl_dout     )
);


//////////////////////////////////////////////////////////////////////
// Global Clock and System Reset.                //
//////////////////////////////////////////////////////////////////////

wire clk;
wire locked;

pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk),          //112Mhz
	.c1(SDRAM_CLK),    //112Mhz
	.locked(locked)
);

reg       reset = 1;
wire      RESET = status[0] | status[4] | buttons[1];
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
// Clocks
////////////////////////////////////////////////////////////////////

reg  ce_14mp;
reg  ce_7mp;
reg  ce_7mn;
reg  ce_1m;

always @(negedge clk) begin
	reg  [4:0] div = 0;
	reg  [6:0] cpu_div = 0;
	reg  [6:0] cpu_rate = 111;

	div <= div + 1'd1;
	ce_14mp <= !div[2] & !div[1:0];
	ce_7mp  <= !div[3] & !div[2:0];
	ce_7mn  <=  div[3] & !div[2:0];
	
	cpu_div <= cpu_div + 1'd1;
	if(cpu_div == cpu_rate) begin
		cpu_div  <= 0;
		cpu_rate <= (tape_active && !status[7]) ? 7'd20 : 7'd111;
	end
	ce_1m <= !cpu_div;
end


///////////////////////////////////////////////////
// RAM
///////////////////////////////////////////////////

sram ram
(
	.*,
	.init(~locked),
	.dout(tape_data),
	.din (ioctl_dout),
	.addr(ioctl_download ? ioctl_addr : tape_addr),
	.wtbt(0),
	.we( ioctl_download && ioctl_wr && (ioctl_index == 1)),
	.rd(!ioctl_download && tape_rd),
	.ready()
);


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
	.cass_write(tape_write),
	.audio(audioDat),
	.cass_sense_n(0),
	.cass_read(tape_audio),
	.diag_l(!status[3]),

	.clk_speed(0),
	.clk_stop(0)
);


////////////////////////////////////////////////////////////////////
// Video 																			   //
////////////////////////////////////////////////////////////////////			

wire [7:0] G = {8{pix}};
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

assign AUDIO_R = AUDIO_L;
sigma_delta_dac #(.MSBI(1)) dac
(
	.CLK(clk),
	.RESET(reset),
	.DACin({audioDat^tape_write,tape_audio&tape_active}),
	.DACout(AUDIO_L)
);

assign LED = ~(tape_active | ioctl_download);

wire        tape_audio;
wire        tape_rd;
wire [24:0] tape_addr;
wire  [7:0] tape_data;
wire        tape_pause = 0;
wire        tape_active;
wire        tape_write;

tape tape(.*);


//////////////////////////////////////////////////////////////////////
// PS/2 to PET keyboard interface
//////////////////////////////////////////////////////////////////////
wire [7:0] 	keyin;
wire [3:0] 	keyrow;	 

keyboard keyboard(.*, .Fn(), .mod());

endmodule // pet2001

