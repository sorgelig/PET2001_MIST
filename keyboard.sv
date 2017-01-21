
module keyboard
(
	input             reset,
	input             clk,

	input             ps2_kbd_clk,
	input             ps2_kbd_data,

	input       [3:0] keyrow,
	output      [7:0] keyin,

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

function [6:0] ps2_to_pet(input shift, input [7:0] code);
begin
	case ({shift, code})
		9'h0_05:	ps2_to_pet = 7'h49;	// 0x03 (STOP)
		9'h1_05:	ps2_to_pet = 7'h49;	// 0x03
		9'h0_11:	ps2_to_pet = 7'h08;	// ALT
		9'h1_11:	ps2_to_pet = 7'h08;	// ALT
		9'h0_15:	ps2_to_pet = 7'h02;	// 'q'
		9'h1_15:	ps2_to_pet = 7'h02;	// 'Q'
		9'h0_16:	ps2_to_pet = 7'h66;	// '1'
		9'h1_16:	ps2_to_pet = 7'h00;	// '!'
		9'h0_1A:	ps2_to_pet = 7'h06;	// 'z'
		9'h1_1A:	ps2_to_pet = 7'h06;	// 'Z'
		9'h0_1B:	ps2_to_pet = 7'h05;	// 's'
		9'h1_1B:	ps2_to_pet = 7'h05;	// 'S'
		9'h0_1C:	ps2_to_pet = 7'h04;	// 'a'
		9'h1_1C:	ps2_to_pet = 7'h04;	// 'A'
		9'h0_1D:	ps2_to_pet = 7'h03;	// 'w'
		9'h1_1D:	ps2_to_pet = 7'h03;	// 'W'
		9'h0_1E:	ps2_to_pet = 7'h67;	// '2'
		9'h1_1E:	ps2_to_pet = 7'h18;	// '@'
		9'h0_21:	ps2_to_pet = 7'h16;	// 'c'
		9'h1_21:	ps2_to_pet = 7'h16;	// 'C'
		9'h0_22:	ps2_to_pet = 7'h07;	// 'x'
		9'h1_22:	ps2_to_pet = 7'h07;	// 'X'
		9'h0_23:	ps2_to_pet = 7'h14;	// 'd'
		9'h1_23:	ps2_to_pet = 7'h14;	// 'D'
		9'h0_24:	ps2_to_pet = 7'h12;	// 'e'
		9'h1_24:	ps2_to_pet = 7'h12;	// 'E'
		9'h0_25:	ps2_to_pet = 7'h64;	// '4'
		9'h1_25:	ps2_to_pet = 7'h11;	// '$'
		9'h0_26:	ps2_to_pet = 7'h76;	// '3'
		9'h1_26:	ps2_to_pet = 7'h10;	// '#'
		9'h0_29:	ps2_to_pet = 7'h29;	// ' '
		9'h1_29:	ps2_to_pet = 7'h29;	// ' '
		9'h0_2A:	ps2_to_pet = 7'h17;	// 'v'
		9'h1_2A:	ps2_to_pet = 7'h17;	// 'V'
		9'h0_2B:	ps2_to_pet = 7'h15;	// 'f'
		9'h1_2B:	ps2_to_pet = 7'h15;	// 'F'
		9'h0_2C:	ps2_to_pet = 7'h22;	// 't'
		9'h1_2C:	ps2_to_pet = 7'h22;	// 'T'
		9'h0_2D:	ps2_to_pet = 7'h13;	// 'r'
		9'h1_2D:	ps2_to_pet = 7'h13;	// 'R'
		9'h0_2E:	ps2_to_pet = 7'h65;	// '5'
		9'h1_2E:	ps2_to_pet = 7'h20;	// '%'
		9'h0_2F:	ps2_to_pet = 7'h09;	// 0x12
		9'h1_2F:	ps2_to_pet = 7'h09;	// 0x12
		9'h0_31:	ps2_to_pet = 7'h27;	// 'n'
		9'h1_31:	ps2_to_pet = 7'h27;	// 'N'
		9'h0_32:	ps2_to_pet = 7'h26;	// 'b'
		9'h1_32:	ps2_to_pet = 7'h26;	// 'B'
		9'h0_33:	ps2_to_pet = 7'h25;	// 'h'
		9'h1_33:	ps2_to_pet = 7'h25;	// 'H'
		9'h0_34:	ps2_to_pet = 7'h24;	// 'g'
		9'h1_34:	ps2_to_pet = 7'h24;	// 'G'
		9'h0_35:	ps2_to_pet = 7'h23;	// 'y'
		9'h1_35:	ps2_to_pet = 7'h23;	// 'Y'
		9'h0_36:	ps2_to_pet = 7'h74;	// '6'
		9'h1_36:	ps2_to_pet = 7'h52;	// '^'
		9'h0_3A:	ps2_to_pet = 7'h36;	// 'm'
		9'h1_3A:	ps2_to_pet = 7'h36;	// 'M'
		9'h0_3B:	ps2_to_pet = 7'h34;	// 'j'
		9'h1_3B:	ps2_to_pet = 7'h34;	// 'J'
		9'h0_3C:	ps2_to_pet = 7'h32;	// 'u'
		9'h1_3C:	ps2_to_pet = 7'h32;	// 'U'
		9'h0_3D:	ps2_to_pet = 7'h62;	// '7'
		9'h1_3D:	ps2_to_pet = 7'h30;	// '&'
		9'h0_3E:	ps2_to_pet = 7'h63;	// '8'
		9'h1_3E:	ps2_to_pet = 7'h75;	// '*'
		9'h0_41:	ps2_to_pet = 7'h37;	// ','
		9'h1_41:	ps2_to_pet = 7'h39;	// '<'
		9'h0_42:	ps2_to_pet = 7'h35;	// 'k'
		9'h1_42:	ps2_to_pet = 7'h35;	// 'K'
		9'h0_43:	ps2_to_pet = 7'h33;	// 'i'
		9'h1_43:	ps2_to_pet = 7'h33;	// 'I'
		9'h0_44:	ps2_to_pet = 7'h42;	// 'o'
		9'h1_44:	ps2_to_pet = 7'h42;	// 'O'
		9'h0_45:	ps2_to_pet = 7'h68;	// '0'
		9'h1_45:	ps2_to_pet = 7'h41;	// ')'
		9'h0_46:	ps2_to_pet = 7'h72;	// '9'
		9'h1_46:	ps2_to_pet = 7'h40;	// '('
		9'h0_49:	ps2_to_pet = 7'h69;	// '.'
		9'h1_49:	ps2_to_pet = 7'h48;	// '>'
		9'h0_4A:	ps2_to_pet = 7'h73;	// '/'
		9'h1_4A:	ps2_to_pet = 7'h47;	// '?'
		9'h0_4B:	ps2_to_pet = 7'h44;	// 'l'
		9'h1_4B:	ps2_to_pet = 7'h44;	// 'L'
		9'h0_4C:	ps2_to_pet = 7'h46;	// ';'
		9'h1_4C:	ps2_to_pet = 7'h45;	// ':'
		9'h0_4D:	ps2_to_pet = 7'h43;	// 'p'
		9'h1_4D:	ps2_to_pet = 7'h43;	// 'P'
		9'h0_4E:	ps2_to_pet = 7'h78;	// '-'
		9'h1_4E:	ps2_to_pet = 7'h50;	// '_'
		9'h0_52:	ps2_to_pet = 7'h21;	// '''
		9'h1_52:	ps2_to_pet = 7'h01;	// '"'
		9'h0_54:	ps2_to_pet = 7'h19;	// '['
		9'h0_55:	ps2_to_pet = 7'h79;	// '='
		9'h1_55:	ps2_to_pet = 7'h77;	// '+'
		9'h0_5A:	ps2_to_pet = 7'h56;	// 0x0d
		9'h1_5A:	ps2_to_pet = 7'h56;	// 0x0d
		9'h0_5B:	ps2_to_pet = 7'h28;	// ']'
		9'h0_5D:	ps2_to_pet = 7'h31;	// '\'
		9'h0_66:	ps2_to_pet = 7'h71;	// 0x08
		9'h1_66:	ps2_to_pet = 7'h71;	// 0x08
		9'h0_6C:	ps2_to_pet = 7'h60;	// 0x13
		9'h1_6C:	ps2_to_pet = 7'h60;	// 0x13
		9'h0_72:	ps2_to_pet = 7'h61;	// 0x11
		9'h1_72:	ps2_to_pet = 7'h61;	// 0x11
		9'h0_74:	ps2_to_pet = 7'h70;	// 0x1d
		9'h1_74:	ps2_to_pet = 7'h70;	// 0x1d

		default:	ps2_to_pet = 7'h7f;
	endcase
end
endfunction

wire [3:0] key_row;
wire [2:0] key_col;

assign {key_col, key_row} = ps2_to_pet(shift, code);


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
		
		if(key_row < 10) keys[key_row][key_col] <= release_btn;
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
