
module keyboard
(
	input             reset,
	input             clk,

	input             ps2_kbd_clk,
	input             ps2_kbd_data,

	input       [3:0] keyrow,
	output      [7:0] keyin,
	output reg        shift_lock,

	output reg [11:1] Fn = 0,
	output reg  [2:0] mod = 0
);

reg  [3:0] prev_clk  = 0;
reg [11:0] shift_reg = 12'hFFF;
wire[11:0] kdata = {ps2_kbd_data,shift_reg[11:1]};
wire [7:0] kcode = kdata[9:2];
reg  [7:0] keys[10];
reg        release_btn = 0;
reg  [7:0] code;

assign     keyin = keys[keyrow];

reg        input_strobe = 0;
wire       shift = mod[0];

always @(negedge clk) begin
	reg old_reset = 0;

	old_reset <= reset;

	if(~old_reset & reset)begin
		keys[0] <= 8'hFF;
		keys[1] <= 8'hFF;
		keys[2] <= 8'hFF;
		keys[3] <= 8'hFF;
		keys[4] <= 8'hFF;
		keys[5] <= 8'hFF;
		keys[6] <= 8'hFF;
		keys[7] <= 8'hFF;
		keys[8] <= 8'hFF;
		keys[9] <= 8'hFF;
		shift_lock <= 0;
	end

	if(input_strobe) begin
		case(code)
			8'h59: mod[0]<= ~release_btn; // right shift
			8'h12: mod[0]<= ~release_btn; // Left shift
			8'h11: mod[1]<= ~release_btn; // alt
			8'h14: mod[2]<= ~release_btn; // ctrl
			8'h05: Fn[1] <= ~release_btn; // F1
			8'h06: Fn[2] <= ~release_btn; // F2
			8'h04: Fn[3] <= ~release_btn; // F3
			8'h0C: Fn[4] <= ~release_btn; // F4
			8'h03: Fn[5] <= ~release_btn; // F5
			8'h0B: Fn[6] <= ~release_btn; // F6
			8'h83: Fn[7] <= ~release_btn; // F7
			8'h0A: Fn[8] <= ~release_btn; // F8
			8'h01: Fn[9] <= ~release_btn; // F9
			8'h09: Fn[10]<= ~release_btn; // F10
			8'h78: Fn[11]<= ~release_btn; // F11
		endcase

		casex({shift, code})
			'hx_76: begin
						keys[9][4] <= release_btn; // ESC -> STOP
						if(~release_btn) keys[8][5] <= 1;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_05: begin
						keys[9][4] <= release_btn; // F1 -> RUN
						if(~release_btn) keys[8][5] <= 0;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_06: begin
						keys[0][6] <= release_btn; // F2 -> CLR
						if(~release_btn) keys[8][5] <= 0;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_71: begin
						keys[1][7] <= release_btn; // DEL
						if(~release_btn) keys[8][5] <= 1;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_70: begin
						keys[1][7] <= release_btn; // INSERT
						if(~release_btn) keys[8][5] <= 0;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_6C: begin
						keys[0][6] <= release_btn; // HOME
						if(~release_btn) keys[8][5] <= 1;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_72: begin
						keys[1][6] <= release_btn; // DOWN
						if(~release_btn) keys[8][5] <= 1;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_75: begin
						keys[1][6] <= release_btn; // UP
						if(~release_btn) keys[8][5] <= 0;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_74: begin
						keys[0][7] <= release_btn; // RIGHT
						if(~release_btn) keys[8][5] <= 1;
							else keys[8][5] <= ~shift_lock;
					end
			'hx_6B: begin
						keys[0][7] <= release_btn; // LEFT
						if(~release_btn) keys[8][5] <= 0;
							else keys[8][5] <= ~shift_lock;
					end

			'hx_58: begin
						keys[8][5] <= release_btn ^ shift_lock; // CAPS -> R SHIFT
						if(~release_btn) shift_lock <= ~shift_lock;
					end

			'hx_11: keys[8][5] <= release_btn ^ shift_lock;  // ALT  -> R SHIFT
			'hx_14: keys[8][0] <= release_btn;  // CTRL  -> L SHIFT
			'hx_1F: keys[9][0] <= release_btn;  // L GUI -> REV ON/OFF
			'hx_5A: keys[6][5] <= release_btn;  // RETURN
			'hx_66: keys[1][7] <= release_btn;  // BKSP  -> DEL

			'h0_16: keys[6][6] <= release_btn;  // 1
			'h1_16: keys[0][0] <= release_btn;  // !
			'h0_1E: keys[7][6] <= release_btn;  // 2
			'h1_1E: keys[8][1] <= release_btn;  // @
			'h0_26: keys[6][7] <= release_btn;  // 3
			'h1_26: keys[0][1] <= release_btn;  // #
			'h0_25: keys[4][6] <= release_btn;  // 4
			'h1_25: keys[1][1] <= release_btn;  // $
			'h0_2E: keys[5][6] <= release_btn;  // 5
			'h1_2E: keys[0][2] <= release_btn;  // %
			'h0_36: keys[4][7] <= release_btn;  // 6
			'h1_36: keys[2][5] <= release_btn;  // ^
			'h0_3D: keys[2][6] <= release_btn;  // 7
			'h1_3D: keys[0][3] <= release_btn;  // &
			'h0_3E: keys[3][6] <= release_btn;  // 8
			'h1_3E: keys[5][7] <= release_btn;  // *
			'h0_46: keys[2][7] <= release_btn;  // 9
			'h1_46: keys[0][4] <= release_btn;  // (
			'h0_45: keys[8][6] <= release_btn;  // 0
			'h1_45: keys[1][4] <= release_btn;  // )
						
			'hx_1C: keys[4][0] <= release_btn;  // a
			'hx_32: keys[6][2] <= release_btn;  // b
			'hx_21: keys[6][1] <= release_btn;  // c
			'hx_23: keys[4][1] <= release_btn;  // d
			'hx_24: keys[2][1] <= release_btn;  // e
			'hx_2B: keys[5][1] <= release_btn;  // f
			'hx_34: keys[4][2] <= release_btn;  // g
			'hx_33: keys[5][2] <= release_btn;  // h
			'hx_43: keys[3][3] <= release_btn;  // i
			'hx_3B: keys[4][3] <= release_btn;  // j
			'hx_42: keys[5][3] <= release_btn;  // k
			'hx_4B: keys[4][4] <= release_btn;  // l
			'hx_3A: keys[6][3] <= release_btn;  // m
			'hx_31: keys[7][2] <= release_btn;  // n
			'hx_44: keys[2][4] <= release_btn;  // o
			'hx_4D: keys[3][4] <= release_btn;  // p
			'hx_15: keys[2][0] <= release_btn;  // q
			'hx_2D: keys[3][1] <= release_btn;  // r
			'hx_1B: keys[5][0] <= release_btn;  // s
			'hx_2C: keys[2][2] <= release_btn;  // t
			'hx_3C: keys[2][3] <= release_btn;  // u
			'hx_2A: keys[7][1] <= release_btn;  // v
			'hx_1D: keys[3][0] <= release_btn;  // w
			'hx_22: keys[7][0] <= release_btn;  // x
			'hx_35: keys[3][2] <= release_btn;  // y
			'hx_1A: keys[6][0] <= release_btn;  // z
						
			'h0_41: keys[7][3] <= release_btn;  // ,
			'h1_41: keys[9][3] <= release_btn;  // <
			'h0_49: keys[9][6] <= release_btn;  // .
			'h1_49: keys[8][4] <= release_btn;  // >
			'h0_4A: keys[3][7] <= release_btn;  // /
			'h1_4A: keys[7][4] <= release_btn;  // ?
			'h0_4C: keys[6][4] <= release_btn;  // ;
			'h1_4C: keys[5][4] <= release_btn;  // :
			'h0_4E: keys[8][7] <= release_btn;  // -
			'h1_4E: keys[0][5] <= release_btn;  // _
			'h0_52: keys[1][2] <= release_btn;  // '
			'h1_52: keys[1][0] <= release_btn;  // "
			'h0_55: keys[9][7] <= release_btn;  // =
			'h1_55: keys[7][7] <= release_btn;  // +
			'hx_54: keys[9][1] <= release_btn;  // [
			'hx_5B: keys[8][2] <= release_btn;  // ]
			'hx_5D: keys[1][3] <= release_btn;  // \
			'hx_29: keys[9][2] <= release_btn;  // SPACE
			default:;
		endcase
	end
end

always @(posedge clk) begin
	reg old_reset = 0;
	reg action = 0;
	old_reset <= reset;
	input_strobe <= 0;

	if(~old_reset & reset)begin
		prev_clk  <= 0;
		shift_reg <= 12'hFFF;
	end else begin
		prev_clk <= {ps2_kbd_clk,prev_clk[3:1]};
		if(prev_clk == 1) begin
			if (kdata[11] & ^kdata[10:2] & ~kdata[1] & kdata[0]) begin
				shift_reg <= 12'hFFF;
				if (kcode == 8'he0) ;
				// Extended key code follows
				else if (kcode == 8'hf0)
					// Release code follows
					action <= 1;
				else begin
					// Cancel extended/release flags for next time
					action <= 0;
					release_btn <= action;
					code <= kcode;
					input_strobe <= 1;
				end
			end else begin
				shift_reg <= kdata;
			end
		end
	end
end
endmodule
