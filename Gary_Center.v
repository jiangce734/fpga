`timescale 1ns / 1ps
//图片大小改变，中心线位置改变，需要修正的数据：35 82 89 98 105 112 161      
//////////////////////////////////////////////////////////////////////////////////
module Gary_Center(
	input clk,
	input [7:0]img_gary,
	input threshold_finish_glag,
	input [7:0]otsu_k_value,
	
	output [10:0]coordinate_x,  ///从1开始计数
	output [9:0]coordinate_y,
	output img_gary_en,           ///使能读取Y坐标
	output center_coordinate_finish_flag,
	output coordinate_y_r_flag_t
	
    );

	reg [7:0]mem[100:0];
	reg [9:0]coordinate_y_cnt;
	reg [9:0]coordinate_y_r;
	reg img_gary_en_r;
	reg [7:0]img_gary_en_r_cnt;
	reg center_coordinate_finish_flag_r;
	
	assign img_gary_en=img_gary_en_r;
	assign coordinate_y=coordinate_y_r_flag?coordinate_y_r:8'd0;
	assign coordinate_x=coordinate_y_r_flag?coordinate_x_cnt:8'd0;
	assign center_coordinate_finish_flag=center_coordinate_finish_flag_r;
	assign coordinate_y_r_flag_t=coordinate_y_r_flag;
	
	/*↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓求中心纵坐标 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓*/
	
	reg [10:0]coordinate_x_cnt;
/* 	always @(posedge clk)
	begin
		if(!threshold_finish_glag)
		begin
			
			
		end
	end */

	reg [9:0]currentstate;///三段式次态现态进行时都是在同一状态下，现态执行S1，那么次态也是S1
	reg [9:0]nextstate;

	parameter s0=10'd0,s1=10'd1,s2=10'd2,s3=10'd3,s4=10'd4,
				s5=10'd5,s6=10'd6,s7=10'd7,s8=10'd8,s9=10'd9,s10=10'd10;

	always @(posedge clk)
	begin
		if(!threshold_finish_glag)//阀值求取完成后threshold_finish_glag置为一
		begin
			currentstate<=s0;
		end
		else
			currentstate<=nextstate;
	end 
	
	always @(currentstate)///nextstate的状态是根据currentstate同步变化的，currentstate变化，则对应状态里nextstate同步变化
	begin
		nextstate=s0;
		case(currentstate)
			s0:nextstate=s1;
			s1:
			begin
				if(img_gary_en_r_cnt<=8'd100)///s1、s2两个状态将一次性接受41个灰度值
					nextstate=s2;
				else
					nextstate=s3;
			end
			s2:
			begin
				if(img_gary_en_r_cnt<=8'd100)
					nextstate=s1;
				else
					nextstate=s3;
			end
			s3:nextstate=s4;
			s4:nextstate=s5;
			s5:
			begin
				if(img_gary_big || (img_gary_en_r_cnt>8'd100))////逻辑陷阱
					nextstate=s6;
				else
					nextstate=s4;
			end
			s6:
			begin
				if(img_gary_en_r_cnt<=8'd100)
					nextstate=s4;
				else
					nextstate=s7;
			end
			s7:
			begin
				if(coordinate_x_cnt<=11'd639)
					nextstate=s1;
				else
					nextstate=s8;
			end
			s8:nextstate=s0;
			default:nextstate=s0;
		endcase
	end
	
	reg img_gary_big;
	reg [7:0] img_gary_r;
	reg [24:0]img_gary_square;
	reg [24:0]img_gary_square_y;
	reg [30:0]img_gary_square_sum;///位宽与img_gary_square_y_sum匹配
	reg [30:0]img_gary_square_y_sum;
	reg coordinate_y_r_flag;
	
	always @(posedge clk)
	begin
		case(nextstate)
			s0:begin end
			s1:
			begin
				if(!threshold_finish_glag)///
				begin
					img_gary_en_r_cnt<=8'd0;
					center_coordinate_finish_flag_r<=1'b0;
					coordinate_x_cnt<=11'd0;
				end
				else 
				begin
					img_gary_en_r<=1'b1;///img_gary_en_r持续40个时钟
					img_gary_en_r_cnt<=img_gary_en_r_cnt+1'b1;
					mem[img_gary_en_r_cnt]<=img_gary;
					
					
				end
			end
			s2:
			begin
				img_gary_en_r<=1'b1;///img_gary_en_r持续40个时钟
				img_gary_en_r_cnt<=img_gary_en_r_cnt+1'b1;
				mem[img_gary_en_r_cnt]<=img_gary;		
			end
			s3:
			begin
				img_gary_en_r<=1'b0;
				img_gary_en_r_cnt<=8'd0;
				coordinate_y_cnt<=10'd235;///求取坐标的起始位置，很重要
				img_gary_square_sum<=31'd0;
				img_gary_square_y_sum<=31'd0;
			end
			s4:
			begin
				if(mem[img_gary_en_r_cnt]>=otsu_k_value)
				begin
					img_gary_big<=1'b1;///s5进入s6
				end
				else
					img_gary_big<=1'b0;//s5回到s4
				img_gary_r<=mem[img_gary_en_r_cnt];
				img_gary_en_r_cnt<=img_gary_en_r_cnt+1'b1;
				coordinate_y_cnt<=coordinate_y_cnt+1'b1;
			end
			s5:
			begin
				img_gary_square<=img_gary_r*img_gary_r;///灰度值平方
				img_gary_square_y<=img_gary_r*img_gary_r*coordinate_y_cnt;///灰度值平方*纵坐标			
			end
			s6:
			begin
				img_gary_square_sum<=img_gary_square+img_gary_square_sum;///灰度值平方求和
				img_gary_square_y_sum<=img_gary_square_y+img_gary_square_y_sum;///灰度值平方*纵坐标求和
				coordinate_y_r_flag<=1'b0;
			end
			s7:
			begin
				coordinate_y_r<=img_gary_square_y_sum/img_gary_square_sum;///重心纵坐标
				coordinate_y_r_flag<=1'b1;///一个重心坐标求取完成信号
				coordinate_x_cnt<=coordinate_x_cnt+1'b1;
				img_gary_en_r_cnt<=6'd0;
			end
			s8:
			begin
				center_coordinate_finish_flag_r<=1'b1;
				coordinate_x_cnt<=1'b0;
			end
			default:;
		endcase
	end

endmodule
