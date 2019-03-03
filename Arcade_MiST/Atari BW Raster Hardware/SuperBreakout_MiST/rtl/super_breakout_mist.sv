module super_breakout_mist(
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
	input         CLOCK_27
);

`include "rtl\build_id.sv" 

localparam CONF_STR = {
	"S. Breakout;;",
	"O1,Test Mode,Off,On;",
	"O2,Rotate Controls,Off,On;",
	"O34,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"T6,Reset;",
	"V,v1.20.",`BUILD_DATE
	};

wire clk_24, clk_12, clk_6;
wire locked;
pll pll(
	.inclk0(CLOCK_27),
	.c0(clk_24),//24.192
	.c1(clk_12),//12.096
	.c2(clk_6),//6.048
	.locked(locked)
	);
	
wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire  [9:0] kbjoy;
wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire        scandoubler_disable;
wire        ypbpr;
wire        ps2_kbd_clk, ps2_kbd_data;
wire  [7:0] audio;
wire 			hs, vs;
wire 			hb, vb;
wire			blankn = ~(hb | vb);
wire 			video;
mist_io #(
	.STRLEN(($size(CONF_STR)>>3)))
mist_io(
	.clk_sys        (clk_24   	     ),
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
	.joystick_0   	 (joystick_0     ),
	.joystick_1     (joystick_1     ),
	.status         (status         )
	);

video_mixer #(
	.LINE_LENGTH(480), 
	.HALF_DEPTH(0)) 
video_mixer(
	.clk_sys(clk_24),
	.ce_pix(clk_6),
	.ce_pix_actual(clk_6),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),
	.R({6{video}}),
	.G({6{video}}),
	.B({6{video}}),
//	.R(blankn ? {video,video,video,video,video,video} : "000000"),
//	.G(blankn ? {video,video,video,video,video,video} : "000000"),
//	.B(blankn ? {video,video,video,video,video,video} : "000000"),
	.HSync(hs),
	.VSync(vs),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.rotate({1'b0,status[2]}),//(left/right,on/off)
	.scandoubler_disable(scandoubler_disable),
	.scanlines(scandoubler_disable ? 2'b00 : {status[4:3] == 3, status[4:3] == 2}),
	.hq2x(status[4:3]==1),
	.ypbpr(ypbpr),
	.ypbpr_full(1),
	.line_start(0),
	.mono(1)
	);

keyboard keyboard(
	.clk(clk_24),
	.reset(),
	.ps2_kbd_clk(ps2_kbd_clk),
	.ps2_kbd_data(ps2_kbd_data),
	.joystick(kbjoy)
	);
	
dac dac(
	.CLK(clk_24),
	.RESET(1'b0),
	.DACin(audio),
	.DACout(AUDIO_L)
	);

assign AUDIO_R = AUDIO_L;	

//wire m_up     = (kbjoy[3] | joystick_0[3] | joystick_1[3]);
//wire m_down   = (kbjoy[2] | joystick_0[2] | joystick_1[2]);
wire m_left   = status[2] ? (kbjoy[1] | joystick_0[1] | joystick_1[1]) : (kbjoy[3] | joystick_0[3] | joystick_1[3]);
wire m_right  = status[2] ? (kbjoy[0] | joystick_0[0] | joystick_1[0]) : (kbjoy[2] | joystick_0[2] | joystick_1[2]);
wire m_fire   = ~(kbjoy[4] | joystick_0[4] | joystick_1[4]);
wire m_start = ~(kbjoy[5] | kbjoy[6]);
wire m_coin = ~(kbjoy[7]);

wire [1:0] steer;
joy2quad steer1(
	.CLK(clk_24),
	.clkdiv('d22500),	
	.right(m_right),
	.left(m_left),	
	.steer(steer)
	);

super_breakout super_breakout(
	.clk_12(clk_12),
	.Reset_n(~(status[0] | status[6] | buttons[1])),
	.CompSync_O(),					
	.HS(hs),
	.VS(vs),
	.VB(vb),		
	.HB(hb),
	.Video_O(video),			
	.Audio_O(audio),
	.Coin1_I(m_coin),
	.Coin2_I(1'b1),
	.Start1_I(m_start),
	.Start2_I(1'b1),
	.Select1_I(),
	.Select2_I(),
	.Enc_A(steer[1]),
	.Enc_B(steer[0]),
	.Pot_Comp1_I(),
	.Slam_I(1'b1),
	.Serve_I(m_fire),
	.Test_I(~status[1]),	
	.Lamp1_O(),
	.Lamp2_O(),
	.Serve_LED_O(LED),
	.Counter_O()
	);

endmodule
