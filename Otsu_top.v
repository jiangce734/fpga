`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
///对OTSU，方差求取时，对每个方差都扩大一样的倍数，并不影响比较结果，这么做是因为商的小数部分在FPGA中只能扩大为整数计算

module Otsu_top(
	input clk,
	input [7:0]img_y,
	input data_end,///只能在灰度直方图统计完成后拉高，灰度阈值求完后最好拉低
	input data_stare,///data_stare信号只能在灰度直方图统计时为高，其余拉低

	output threshold_finish_flag,
	output [7:0]otsu_k_value
    );

	// reg center_line_finish;///中心线提取完成的标志
	
	/*↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓灰度*数量、总点数统计 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓*/
	
	reg [8:0]i;
	reg [24:0]sum_n;
	reg [24:0]sum_mul_n;
	reg sum_en;
		
	always @ (posedge clk)
	begin
		if(data_end)
		begin
			if(i<=9'd255)
			begin
				sum_mul_n<=sum_mul_n+i*mem[i];
				sum_n<=sum_n+mem[i];
				i<=i+1'b1;
			end
			else
			begin
				sum_mul_n<=sum_mul_n;
				sum_n<=sum_n;
				sum_en<=1'b1;///灰度与点数乘积和、总点数求取完成
			end
		end
		else if(data_stare)
		begin
			sum_n<=25'd0;///data_stare为1，则说明正在进行灰度直方图统计，所以data_stare信号只能在灰度直方图统计时为高，其余拉低
			sum_mul_n<=25'd0;
			i<=1'b0;
			sum_en<=1'b0;		
		end
	end
	
	/*↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑灰度*数量、总点数统计↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑*/
	
	 reg threshold_finish;
	/*↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓求自适应阈值 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓*/
	 reg [7:0]threshold_k;
	 reg [7:0]threshold_i;
	 reg [24:0]sum_n0;
	 reg [24:0]sum_n1;
	 reg [24:0]sum_mul_n0;
	 reg [24:0]sum_mul_n1;
	 reg threshold_en;
	reg threshold_k_add;
	reg threshold_k_add_1;
	reg threshold_k_add_2;
	reg threshold_k_add_up;
	
	always @(posedge clk)///当一次threshold_i<threshold_k计算完成后，产生一个信号，使threshold_k值加1
	begin
		threshold_k_add_1<=threshold_k_add;
		threshold_k_add_2<=threshold_k_add_1;
		if(threshold_k_add_1 & !threshold_k_add_2 )
			threshold_k_add_up<=1'b1;
		else
			threshold_k_add_up<=1'b0;
	end
	
	always @(posedge clk)
	begin
		if(sum_en)
		begin
			if(threshold_k<=8'd250)///假设阈值小于250
			begin
				threshold_finish<=1'b0;
				if(threshold_i<threshold_k)
				begin
					sum_n0<=sum_n0+mem[threshold_i];
					sum_mul_n0<=sum_mul_n0+threshold_i*mem[threshold_i];
					threshold_i<=threshold_i+1'b1;
					threshold_en<=1'b0;
				end
				else
				begin
					sum_n1<=sum_n-sum_n0;
					sum_mul_n1<=sum_mul_n-sum_mul_n0;
					threshold_en<=1'b1;
					if(threshold_k_add_up)
						threshold_k<=threshold_k+1'b1;
				end
			end
			else
			begin
				threshold_en<=1'b0;///阈值求取完成，停止计算
				threshold_finish<=1'b1;///阈值求取完成，信号拉高
			end
		end
		else
		begin
			sum_n0<=25'd0;
			sum_mul_n0<=25'd0;
			threshold_k<=8'd10;///设定阈值在10开始，实际可以设更大，加快计算过程
			threshold_i<=8'd0;
		end
	end 
	
	wire [5:0]fractional_w0;
	wire [5:0]fractional_w1;
	wire [15:0]quotient;
	reg [24:0]quotient_n0;
	reg [24:0]quotient_n1;
	reg [9:0]currentstate;
	reg [9:0]nextstate;
	reg [24:0]sub_n;
	reg [49:0]sub_n_square;
	reg [5:0]timer_cnt;
	reg [61:0]threshold;
	reg [61:0]threshold_0;
	reg [61:0]otsu_threshold;
	reg [7:0]otsu_k;
	
	initial begin
		threshold_0<=62'd0;
	end
	
	parameter s0=10'b00000_00001,s1=10'b00000_00010,s2=10'b00000_00100,s3=10'b00000_01000,s4=10'b00000_10000,
				s5=10'b00001_00000,s6=10'b00010_00000,s7=10'b00100_00000,s8=10'b01000_00000,s9=10'b10000_00000,s10=10'b11000_00000;
	
	always @(posedge clk)
	begin
		if(!threshold_en)
		begin
			currentstate<=s0;
		end
		else
			currentstate<=nextstate;
	end
	always @(currentstate)
	begin
		nextstate=s0;///初始化
		case(currentstate)
			s0:nextstate=s1;
			s1:nextstate=s2;
			s2:
			begin
				if(quotient_n0>=quotient_n1)
					nextstate=s3;
				else
					nextstate=s4;
			end
			s3:
			begin
				nextstate=s5;
				timer_cnt=1'b0;
			end
			s4:
			begin
				nextstate=s5;
				timer_cnt=1'b0;
			end
			s5:nextstate=s6;
			s6:
			begin
				if(timer_cnt<=6'd30)///延时，等待除法器计算结果
				begin
					timer_cnt=timer_cnt+1'b1;
					nextstate=s7;
				end
				else
				begin
					timer_cnt=6'd0;
					nextstate=s8;
				end
			end
			s7:
			begin
				if(timer_cnt<=6'd30)
				begin
					timer_cnt=timer_cnt+1'b1;
					nextstate=s6;
				end
				else
				begin
					timer_cnt=6'd0;
					nextstate=s8;
				end
			end
			s8:nextstate=s9;
			s9:nextstate=s10;
			s10:nextstate=s0;
			default:nextstate=s0;
		endcase
	end
	always @(posedge clk)
	begin
		case(nextstate)
			s0:
			begin
				
			end
			s1:
			begin
				quotient_n0<=sum_mul_n0/sum_n0;
				quotient_n1<=sum_mul_n1/sum_n1;
				threshold_k_add<=1'b0;
				if(threshold_finish)
					threshold_0<=62'd0;///每次在一帧图开始求最佳阈值完成时初始化，第一次初始化为直接赋值
			end
			s2:begin end
			s3:
			begin
				sub_n<=quotient_n0-quotient_n1;
			end
			s4:
			begin
				sub_n<=quotient_n1-quotient_n0;
			end
			s5:
			begin
				sub_n_square<=sub_n*sub_n;
			end
			s6:
			begin 
			
			end
			s7:
			begin
				
			end
			s8:
			begin
				threshold<=fractional_w0*fractional_w1*sub_n_square;///并未延时
			end
			s9:
			begin
				if(threshold>threshold_0)
				begin
					otsu_threshold<=threshold;
					otsu_k<=threshold_k;
				end
				else
				begin
					otsu_threshold<=threshold_0;
					otsu_k<=otsu_k;
				end
			end
			s10:
			begin
				threshold_0<=otsu_threshold;
				threshold_k_add<=1'b1;
			end
			default:;
		endcase
	end
	
	
test_Div w0 (///33个周期就能跑完
.clk(clk), // input clk
.ce(threshold_en), // input ce
.rfd(rfd), // output rfd
.dividend(sum_n0), // input [24 : 0] dividend
.divisor(sum_n), // input [24 : 0] divisor
.quotient(quotient), // output [24 : 0] quotient
.fractional(fractional_w0)); // output [5 : 0] fractional
	
test_Div w1 (
.clk(clk), // input clk
.ce(threshold_en), // input ce
.rfd(rfd), // output rfd
.dividend(sum_n1), // input [24 : 0] dividend
.divisor(sum_n), // input [24 : 0] divisor
.quotient(quotient), // output [24 : 0] quotient
.fractional(fractional_w1)); // output [5 : 0] fractional
	
	assign threshold_finish_flag=threshold_finish;
	assign otsu_k_value=(threshold_finish_flag)?otsu_k:8'd0; 
	
	/*↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑求自适应阈值↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑*/
	
	/*↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓直方图寄存器赋初值0↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓*/
	 	reg[15:0]mem[255:0];///默认值为高阻状态,且不可赋初值
		reg [8:0]mem_i = 9'd0;///mem_i在中心线提取完成后，计数器恢复为0，将mem重新清零
		reg mem_en;
	
	/*↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓灰度直方图统计 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓*/
	reg threshold_finish_1;
	reg threshold_finish_2;
	reg threshold_finish_up;
	always @(posedge clk)///目的是产生一个阈值求取完成信号的上升沿，用于直方图寄存器初始化
	begin
		threshold_finish_1<=threshold_finish;
		threshold_finish_2<=threshold_finish_1;
		if(threshold_finish_1 & !threshold_finish_2)///&若不是布尔型则按位与，&&具有短路功能，即第一个表达式F,则后一个表达式不执行
			threshold_finish_up<=1'b1;              ///但&和&&都是表示与，这里两个都要判断，最好用&
		else
			threshold_finish_up<=1'b0;
	end
	
	always @ (posedge clk)
	begin
	/*↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓直方图寄存器赋初值0↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓*/
		if(mem_i<=255)
		begin
			mem_en<=1'b0;
			mem[mem_i]<=16'd0;
			mem_i<=mem_i+1'b1;
		end
		else if(threshold_finish_up)///中心线阈值提取完成后，计数器恢复为0，将mem重新清零，同时mem_en使能拉低
		begin
			mem_en<=1'b0;
			mem_i<=1'b0;
		end
		else
		begin
			mem_en<=1'b1;;///在256个时钟周期后，所有寄存器赋初值0，使能拉高
			mem_i<=mem_i;
		end
	/*↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑直方图寄存器赋初值0↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑*/
		if(mem_en && data_stare && !data_end)
		begin		
			case(img_y)
			0:mem[0]<=mem[0]+1'b1;
			1:mem[1]<=mem[1]+1'b1;
			2:mem[2]<=mem[2]+1'b1;
			3:mem[3]<=mem[3]+1'b1;
			4:mem[4]<=mem[4]+1'b1;
			5:mem[5]<=mem[5]+1'b1;
			6:mem[6]<=mem[6]+1'b1;
			7:mem[7]<=mem[7]+1'b1;
			8:mem[8]<=mem[8]+1'b1;
			9:mem[9]<=mem[9]+1'b1;
			10:mem[10]<=mem[10]+1'b1;
			11:mem[11]<=mem[11]+1'b1;
			12:mem[12]<=mem[12]+1'b1;
			13:mem[13]<=mem[13]+1'b1;
			14:mem[14]<=mem[14]+1'b1;
			15:mem[15]<=mem[15]+1'b1;
			16:mem[16]<=mem[16]+1'b1;
			17:mem[17]<=mem[17]+1'b1;
			18:mem[18]<=mem[18]+1'b1;
			19:mem[19]<=mem[19]+1'b1;
			20:mem[20]<=mem[20]+1'b1;
			21:mem[21]<=mem[21]+1'b1;
			22:mem[22]<=mem[22]+1'b1;
			23:mem[23]<=mem[23]+1'b1;
			24:mem[24]<=mem[24]+1'b1;
			25:mem[25]<=mem[25]+1'b1;
			26:mem[26]<=mem[26]+1'b1;
			27:mem[27]<=mem[27]+1'b1;
			28:mem[28]<=mem[28]+1'b1;
			29:mem[29]<=mem[29]+1'b1;
			30:mem[30]<=mem[30]+1'b1;
			31:mem[31]<=mem[31]+1'b1;
			32:mem[32]<=mem[32]+1'b1;
			33:mem[33]<=mem[33]+1'b1;
			34:mem[34]<=mem[34]+1'b1;
			35:mem[35]<=mem[35]+1'b1;
			36:mem[36]<=mem[36]+1'b1;
			37:mem[37]<=mem[37]+1'b1;
			38:mem[37]<=mem[38]+1'b1;
			39:mem[39]<=mem[39]+1'b1;
			40:mem[40]<=mem[40]+1'b1;
			41:mem[41]<=mem[41]+1'b1;
			42:mem[42]<=mem[42]+1'b1;
			43:mem[43]<=mem[43]+1'b1;
			44:mem[44]<=mem[44]+1'b1;
			45:mem[45]<=mem[45]+1'b1;
			46:mem[46]<=mem[46]+1'b1;
			47:mem[47]<=mem[47]+1'b1;
			48:mem[48]<=mem[48]+1'b1;
			49:mem[49]<=mem[49]+1'b1;
			50:mem[50]<=mem[50]+1'b1;
			51:mem[51]<=mem[51]+1'b1;
			52:mem[52]<=mem[52]+1'b1;
			53:mem[53]<=mem[53]+1'b1;
			54:mem[54]<=mem[54]+1'b1;
			55:mem[55]<=mem[55]+1'b1;
			56:mem[56]<=mem[56]+1'b1;
			57:mem[57]<=mem[57]+1'b1;
			58:mem[58]<=mem[58]+1'b1;
			59:mem[59]<=mem[59]+1'b1;
			60:mem[60]<=mem[60]+1'b1;
			61:mem[61]<=mem[61]+1'b1;
			62:mem[62]<=mem[62]+1'b1;
			63:mem[63]<=mem[63]+1'b1;
			64:mem[64]<=mem[64]+1'b1;
			65:mem[65]<=mem[65]+1'b1;
			66:mem[66]<=mem[66]+1'b1;
			67:mem[67]<=mem[67]+1'b1;
			68:mem[68]<=mem[68]+1'b1;
			69:mem[69]<=mem[69]+1'b1;
			70:mem[70]<=mem[70]+1'b1;
			71:mem[71]<=mem[71]+1'b1;
			72:mem[72]<=mem[72]+1'b1;
			73:mem[73]<=mem[73]+1'b1;
			74:mem[74]<=mem[74]+1'b1;
			75:mem[75]<=mem[75]+1'b1;
			76:mem[76]<=mem[76]+1'b1;
			77:mem[77]<=mem[77]+1'b1;
			78:mem[78]<=mem[78]+1'b1;
			79:mem[79]<=mem[79]+1'b1;
			80:mem[80]<=mem[80]+1'b1;
			81:mem[81]<=mem[81]+1'b1;
			82:mem[82]<=mem[82]+1'b1;
			83:mem[83]<=mem[83]+1'b1;
			84:mem[84]<=mem[84]+1'b1;
			85:mem[85]<=mem[85]+1'b1;
			86:mem[86]<=mem[86]+1'b1;
			87:mem[87]<=mem[87]+1'b1;
			88:mem[88]<=mem[88]+1'b1;
			89:mem[89]<=mem[89]+1'b1;
			90:mem[90]<=mem[90]+1'b1;
			91:mem[91]<=mem[91]+1'b1;
			92:mem[92]<=mem[92]+1'b1;
			93:mem[93]<=mem[93]+1'b1;
			94:mem[94]<=mem[94]+1'b1;
			95:mem[95]<=mem[95]+1'b1;
			96:mem[96]<=mem[96]+1'b1;
			97:mem[97]<=mem[97]+1'b1;
			98:mem[98]<=mem[98]+1'b1;
			99:mem[99]<=mem[99]+1'b1;
			100:mem[100]<=mem[100]+1'b1;
			101:mem[101]<=mem[101]+1'b1;
			102:mem[102]<=mem[102]+1'b1;
			103:mem[103]<=mem[103]+1'b1;
			104:mem[104]<=mem[104]+1'b1;
			105:mem[105]<=mem[105]+1'b1;
			106:mem[106]<=mem[106]+1'b1;
			107:mem[107]<=mem[107]+1'b1;
			108:mem[108]<=mem[108]+1'b1;
			109:mem[109]<=mem[109]+1'b1;
			110:mem[110]<=mem[110]+1'b1;
			111:mem[111]<=mem[111]+1'b1;
			112:mem[112]<=mem[112]+1'b1;
			113:mem[113]<=mem[113]+1'b1;
			114:mem[114]<=mem[114]+1'b1;
			115:mem[115]<=mem[115]+1'b1;
			116:mem[116]<=mem[116]+1'b1;
			117:mem[117]<=mem[117]+1'b1;
			118:mem[118]<=mem[118]+1'b1;
			119:mem[119]<=mem[119]+1'b1;
			120:mem[120]<=mem[120]+1'b1;
			121:mem[121]<=mem[121]+1'b1;
			122:mem[122]<=mem[122]+1'b1;
			123:mem[123]<=mem[123]+1'b1;
			124:mem[124]<=mem[124]+1'b1;
			125:mem[125]<=mem[125]+1'b1;
			126:mem[126]<=mem[126]+1'b1;
			127:mem[127]<=mem[127]+1'b1;
			128:mem[128]<=mem[128]+1'b1;
			129:mem[129]<=mem[129]+1'b1;
			130:mem[130]<=mem[130]+1'b1;
			131:mem[131]<=mem[131]+1'b1;
			132:mem[132]<=mem[132]+1'b1;
			133:mem[133]<=mem[133]+1'b1;
			134:mem[134]<=mem[134]+1'b1;
			135:mem[135]<=mem[135]+1'b1;
			136:mem[136]<=mem[136]+1'b1;
			137:mem[137]<=mem[137]+1'b1;
			138:mem[138]<=mem[138]+1'b1;
			139:mem[139]<=mem[139]+1'b1;
			140:mem[140]<=mem[140]+1'b1;
			141:mem[141]<=mem[141]+1'b1;
			142:mem[142]<=mem[142]+1'b1;
			143:mem[143]<=mem[143]+1'b1;
			144:mem[144]<=mem[144]+1'b1;
			145:mem[145]<=mem[145]+1'b1;
			146:mem[146]<=mem[146]+1'b1;
			147:mem[147]<=mem[147]+1'b1;
			148:mem[148]<=mem[148]+1'b1;
			149:mem[149]<=mem[149]+1'b1;
			150:mem[150]<=mem[150]+1'b1;
			151:mem[151]<=mem[151]+1'b1;
			152:mem[152]<=mem[152]+1'b1;
			153:mem[153]<=mem[153]+1'b1;
			154:mem[154]<=mem[154]+1'b1;
			155:mem[155]<=mem[155]+1'b1;
			156:mem[156]<=mem[156]+1'b1;
			157:mem[157]<=mem[157]+1'b1;
			158:mem[158]<=mem[158]+1'b1;
			159:mem[159]<=mem[159]+1'b1;
			160:mem[160]<=mem[160]+1'b1;
			161:mem[161]<=mem[161]+1'b1;
			162:mem[162]<=mem[162]+1'b1;
			163:mem[163]<=mem[163]+1'b1;
			164:mem[164]<=mem[164]+1'b1;
			165:mem[165]<=mem[165]+1'b1;
			166:mem[166]<=mem[166]+1'b1;
			167:mem[167]<=mem[167]+1'b1;
			168:mem[168]<=mem[168]+1'b1;
			169:mem[169]<=mem[169]+1'b1;
			170:mem[170]<=mem[170]+1'b1;
			171:mem[171]<=mem[171]+1'b1;
			172:mem[172]<=mem[172]+1'b1;
			173:mem[173]<=mem[173]+1'b1;
			174:mem[174]<=mem[174]+1'b1;
			175:mem[175]<=mem[175]+1'b1;
			176:mem[176]<=mem[176]+1'b1;
			177:mem[177]<=mem[177]+1'b1;
			178:mem[178]<=mem[178]+1'b1;
			179:mem[179]<=mem[179]+1'b1;
			180:mem[180]<=mem[180]+1'b1;
			181:mem[181]<=mem[181]+1'b1;
			182:mem[182]<=mem[182]+1'b1;
			183:mem[183]<=mem[183]+1'b1;
			184:mem[184]<=mem[184]+1'b1;
			185:mem[185]<=mem[185]+1'b1;
			186:mem[186]<=mem[186]+1'b1;
			187:mem[187]<=mem[187]+1'b1;
			188:mem[188]<=mem[188]+1'b1;
			189:mem[189]<=mem[189]+1'b1;
			190:mem[190]<=mem[190]+1'b1;
			191:mem[191]<=mem[191]+1'b1;
			192:mem[192]<=mem[192]+1'b1;
			193:mem[193]<=mem[193]+1'b1;
			194:mem[194]<=mem[194]+1'b1;
			195:mem[195]<=mem[195]+1'b1;
			196:mem[196]<=mem[196]+1'b1;
			197:mem[197]<=mem[197]+1'b1;
			198:mem[198]<=mem[198]+1'b1;
			199:mem[199]<=mem[199]+1'b1;
			200:mem[200]<=mem[200]+1'b1;
			201:mem[201]<=mem[201]+1'b1;
			202:mem[202]<=mem[202]+1'b1;
			203:mem[203]<=mem[203]+1'b1;
			204:mem[204]<=mem[204]+1'b1;
			205:mem[205]<=mem[205]+1'b1;
			206:mem[206]<=mem[206]+1'b1;
			207:mem[207]<=mem[207]+1'b1;
			208:mem[208]<=mem[208]+1'b1;
			209:mem[209]<=mem[209]+1'b1;
			210:mem[210]<=mem[210]+1'b1;
			211:mem[211]<=mem[211]+1'b1;
			212:mem[212]<=mem[212]+1'b1;
			213:mem[213]<=mem[213]+1'b1;
			214:mem[214]<=mem[214]+1'b1;
			215:mem[215]<=mem[215]+1'b1;
			216:mem[216]<=mem[216]+1'b1;
			217:mem[217]<=mem[217]+1'b1;
			218:mem[218]<=mem[218]+1'b1;
			219:mem[219]<=mem[219]+1'b1;
			220:mem[220]<=mem[220]+1'b1;
			221:mem[221]<=mem[221]+1'b1;
			222:mem[222]<=mem[222]+1'b1;
			223:mem[223]<=mem[223]+1'b1;
			224:mem[224]<=mem[224]+1'b1;
			225:mem[225]<=mem[225]+1'b1;
			226:mem[226]<=mem[226]+1'b1;
			227:mem[227]<=mem[227]+1'b1;
			228:mem[228]<=mem[228]+1'b1;
			229:mem[229]<=mem[229]+1'b1;
			230:mem[230]<=mem[230]+1'b1;
			231:mem[231]<=mem[231]+1'b1;
			232:mem[232]<=mem[232]+1'b1;
			233:mem[233]<=mem[233]+1'b1;
			234:mem[234]<=mem[234]+1'b1;
			235:mem[235]<=mem[235]+1'b1;
			236:mem[236]<=mem[236]+1'b1;
			237:mem[237]<=mem[237]+1'b1;
			238:mem[238]<=mem[238]+1'b1;
			239:mem[239]<=mem[239]+1'b1;
			240:mem[240]<=mem[240]+1'b1;
			241:mem[241]<=mem[241]+1'b1;
			242:mem[242]<=mem[242]+1'b1;
			243:mem[243]<=mem[243]+1'b1;
			244:mem[244]<=mem[244]+1'b1;
			245:mem[245]<=mem[245]+1'b1;
			246:mem[246]<=mem[246]+1'b1;
			247:mem[247]<=mem[247]+1'b1;
			248:mem[248]<=mem[248]+1'b1;
			249:mem[249]<=mem[249]+1'b1;
			250:mem[250]<=mem[250]+1'b1;
			251:mem[251]<=mem[251]+1'b1;
			252:mem[252]<=mem[252]+1'b1;
			253:mem[253]<=mem[253]+1'b1;
			254:mem[254]<=mem[254]+1'b1;
			255:mem[255]<=mem[255]+1'b1;
			default:;
			endcase
		end		
	end
		/*↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑灰度直方图统计↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑*/
	
	

endmodule
