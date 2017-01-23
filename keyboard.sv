
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

assign keyin = keys[keyrow];

reg  input_strobe = 0;
wire shift = mod[0];

function [8:0] ps2_to_pet(input shift, input [7:0] code);
begin
	casex({shift, code})
		'hx_76:	ps2_to_pet = 'h149;	// ESC   -> STOP
		'hx_05:	ps2_to_pet = 'h1C9;	// F1    -> RUN
		'hx_06:	ps2_to_pet = 'h1E0;	// F2    -> CLR
		'hx_11:	ps2_to_pet = 'h58;	// ALT   -> R SHIFT
		'hx_14:	ps2_to_pet = 'h08;	// CTRL  -> L SHIFT
		'hx_1F:	ps2_to_pet = 'h09;	// L GUI -> REV ON/OFF
		'hx_58:	ps2_to_pet = 'h58;	// CAPS  -> R SHIFT
		'hx_5A:	ps2_to_pet = 'h56;	// RETURN
		'hx_66:	ps2_to_pet = 'h71;	// BKSP  -> DEL
		'hx_71:	ps2_to_pet = 'h171;	// DEL
		'hx_70:	ps2_to_pet = 'h1F1;	// INSERT
		'hx_6C:	ps2_to_pet = 'h160;	// HOME
		'hx_72:	ps2_to_pet = 'h161;	// DOWN
		'hx_75:	ps2_to_pet = 'h1E1;	// UP
		'hx_74:	ps2_to_pet = 'h170;	// RIGHT
		'hx_6B:	ps2_to_pet = 'h1F0;	// LEFT

		'h0_16:	ps2_to_pet = 'h66;	// '1'
		'h1_16:	ps2_to_pet = 'h00;	// '!'
		'h0_1E:	ps2_to_pet = 'h67;	// '2'
		'h1_1E:	ps2_to_pet = 'h18;	// '@'
		'h0_26:	ps2_to_pet = 'h76;	// '3'
		'h1_26:	ps2_to_pet = 'h10;	// '#'
		'h0_25:	ps2_to_pet = 'h64;	// '4'
		'h1_25:	ps2_to_pet = 'h11;	// '$'
		'h0_2E:	ps2_to_pet = 'h65;	// '5'
		'h1_2E:	ps2_to_pet = 'h20;	// '%'
		'h0_36:	ps2_to_pet = 'h74;	// '6'
		'h1_36:	ps2_to_pet = 'h52;	// '^'
		'h0_3D:	ps2_to_pet = 'h62;	// '7'
		'h1_3D:	ps2_to_pet = 'h30;	// '&'
		'h0_3E:	ps2_to_pet = 'h63;	// '8'
		'h1_3E:	ps2_to_pet = 'h75;	// '*'
		'h0_46:	ps2_to_pet = 'h72;	// '9'
		'h1_46:	ps2_to_pet = 'h40;	// '('
		'h0_45:	ps2_to_pet = 'h68;	// '0'
		'h1_45:	ps2_to_pet = 'h41;	// ')'

		'hx_1C:	ps2_to_pet = 'h04;	// 'a'
		'hx_32:	ps2_to_pet = 'h26;	// 'b'
		'hx_21:	ps2_to_pet = 'h16;	// 'c'
		'hx_23:	ps2_to_pet = 'h14;	// 'd'
		'hx_24:	ps2_to_pet = 'h12;	// 'e'
		'hx_2B:	ps2_to_pet = 'h15;	// 'f'
		'hx_34:	ps2_to_pet = 'h24;	// 'g'
		'hx_33:	ps2_to_pet = 'h25;	// 'h'
		'hx_43:	ps2_to_pet = 'h33;	// 'i'
		'hx_3B:	ps2_to_pet = 'h34;	// 'j'
		'hx_42:	ps2_to_pet = 'h35;	// 'k'
		'hx_4B:	ps2_to_pet = 'h44;	// 'l'
		'hx_3A:	ps2_to_pet = 'h36;	// 'm'
		'hx_31:	ps2_to_pet = 'h27;	// 'n'
		'hx_44:	ps2_to_pet = 'h42;	// 'o'
		'hx_4D:	ps2_to_pet = 'h43;	// 'p'
		'hx_15:	ps2_to_pet = 'h02;	// 'q'
		'hx_2D:	ps2_to_pet = 'h13;	// 'r'
		'hx_1B:	ps2_to_pet = 'h05;	// 's'
		'hx_2C:	ps2_to_pet = 'h22;	// 't'
		'hx_3C:	ps2_to_pet = 'h32;	// 'u'
		'hx_2A:	ps2_to_pet = 'h17;	// 'v'
		'hx_1D:	ps2_to_pet = 'h03;	// 'w'
		'hx_22:	ps2_to_pet = 'h07;	// 'x'
		'hx_35:	ps2_to_pet = 'h23;	// 'y'
		'hx_1A:	ps2_to_pet = 'h06;	// 'z'

		'h0_41:	ps2_to_pet = 'h37;	// ','
		'h1_41:	ps2_to_pet = 'h39;	// '<'
		'h0_49:	ps2_to_pet = 'h69;	// '.'
		'h1_49:	ps2_to_pet = 'h48;	// '>'
		'h0_4A:	ps2_to_pet = 'h73;	// '/'
		'h1_4A:	ps2_to_pet = 'h47;	// '?'
		'h0_4C:	ps2_to_pet = 'h46;	// ';'
		'h1_4C:	ps2_to_pet = 'h45;	// ':'
		'h0_4E:	ps2_to_pet = 'h78;	// '-'
		'h1_4E:	ps2_to_pet = 'h50;	// '_'
		'h0_52:	ps2_to_pet = 'h21;	// '''
		'h1_52:	ps2_to_pet = 'h01;	// '"'
		'h0_55:	ps2_to_pet = 'h79;	// '='
		'h1_55:	ps2_to_pet = 'h77;	// '+'
		'hx_54:	ps2_to_pet = 'h19;	// '['
		'hx_5B:	ps2_to_pet = 'h28;	// ']'
		'hx_5D:	ps2_to_pet = 'h31;	// '\'
		'hx_29:	ps2_to_pet = 'h29;	// ' '

		default:	ps2_to_pet = 'h7f;
	endcase
end
endfunction

wire [3:0] key_row;
wire [2:0] key_col;
wire       key_shift;
wire       key_shift_state;

assign {key_shift, key_shift_state, key_col, key_row} = ps2_to_pet(shift, code);

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
		
		if((code == 'h58) && ~release_btn) shift_lock <= ~shift_lock;

		if(key_row < 10) begin
			keys[key_row][key_col] <= ({key_col, key_row}=='h58) ? release_btn ^ shift_lock : release_btn;
			if(key_shift) begin
				if(~release_btn) begin
					keys[8][5] <= ~key_shift_state;
				end else begin
					keys[8][5] <= ~shift_lock;
				end
			end
		end
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
