/**
 * The MIT License
 * Copyright (c) 2016-2018 David Shah
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

/*
 * Simple downsampler and buffer 640x480 => 40x30
*/

module downsample (
	input pixel_clock,
	input in_line,
	input in_frame,
	input [31:0] pixel_data,
	input data_enable,

	input read_clock,
	input [5:0] read_x,
	input [4:0] read_y,
	output reg [31:0] read_q
);

	reg [7:0] R_buffer[0:2048-1];
	reg [7:0] G_buffer[0:2048-1];
	reg [7:0] B_buffer[0:2048-1];

	// each 16x16 (256 pixels) will have 64 R, 64 B, 128 G
	// bit growth R:6  B:6 G:7
	// taking in a 640 pixels per line we need to accumulate 640/16 = 40 R,G, and B accumulators
	// will 0 out as buffer is filled or treat as zero on new frame
	reg [7 + 7:0] R_accums [39:0];
	reg [7 + 7:0] G_accums [39:0];
	reg [7 + 7:0] B_accums [39:0];

	// count x by 4 pixels at a time, count y 1 at a time
	reg [7:0] pixel4_x;
	reg [8:0] pixel1_y;
	reg last_in_line;

	// divide by 4 to get output pixel index
	wire [5:0] pixel_x_out 	   = pixel4_x[7:2];

	// p0 is either R or Gb, p1 is either Gr or B based on line parity
	// (even lines and odd lines respectively)
	wire [7+7:0] pixel_acc_p0  = (pixel1_y == 0) ? 0 :
				 ((pixel1_y[0] == 0) ? R_accums[pixel_x_out] : G_accums[pixel_x_out]);
	wire [7+7:0] pixel_acc_p1  = (pixel1_y == 0) ? 0 :
				 ((pixel1_y[0] == 0) ? G_accums[pixel_x_out] : B_accums[pixel_x_out]);

	wire [7+7:0] next_acc_p0   = pixel_acc_p0 + pixel_data[7:0]  + pixel_data[23:16];
	wire [7+7:0] next_acc_p1   = pixel_acc_p1 + pixel_data[15:8] + pixel_data[31:24];

	always @(posedge pixel_clock)
	begin
		if (!in_frame) begin
			pixel4_x 	 <= 0;
			pixel1_y 	 <= 0;
			last_in_line <= in_line;
		end else begin
			if (in_line && data_enable) begin
				// output 1 RGB pixel every 16 lines and every 16/4 = 4 pixel4
				if (&(pixel1_y[3:0]) && &(pixel4_x[1:0])) begin
					// reset [RGB]_accumms
					R_accums[pixel_x_out] <= 0;
					G_accums[pixel_x_out] <= 0;
					B_accums[pixel_x_out] <= 0;

					R_buffer[{pixel1_y[8:4], pixel_x_out}] <= R_accums[pixel_x_out][13:6];
					G_buffer[{pixel1_y[8:4], pixel_x_out}] <= next_acc_p0[14:7];
					B_buffer[{pixel1_y[8:4], pixel_x_out}] <= next_acc_p1[13:6];
				end else begin
					// should set [RGB]_accumms
					if (pixel1_y[0] == 0) begin
						R_accums[pixel_x_out] <= next_acc_p0;
						G_accums[pixel_x_out] <= next_acc_p1;
					end else begin
						G_accums[pixel_x_out] <= next_acc_p0;
						B_accums[pixel_x_out] <= next_acc_p1;
					end
				end

				if (pixel4_x < 640/4) begin
					pixel4_x <= pixel4_x + 1;
				end
			end else if (!in_line) begin
				pixel4_x 	 <= 0;

				if (last_in_line)
					pixel1_y <= pixel1_y + 1'b1;
			end
			last_in_line <= in_line;
		end
	end

	always @(posedge read_clock) begin
		read_q <= {
				   8'hff, // ff for full opacitiy on alpha layer
				   R_buffer[{read_y, read_x}],
				   G_buffer[{read_y, read_x}],
				   B_buffer[{read_y, read_x}]
				   };
	end

endmodule
