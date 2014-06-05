// VL Verilog Toolkit
// Copyright (C) 2008-2014 Centaur Technology
//
// Contact:
//   Centaur Technology Formal Verification Group
//   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
//   http://www.centtech.com/
//
// This program is free software; you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 2 of the License, or (at your option) any later
// version.  This program is distributed in the hope that it will be useful but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.  You should have received a copy of the GNU General Public
// License along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
//
// Original author: Jared Davis <jared@centtech.com>

// basic tests of combinational blocks

module comb_test (

src1,
src2,
src3,

out1,
out2,
out3,
out4,
out5

);

  parameter size = 1;

  input [size-1:0] src1;
  input [size-1:0] src2;
  input [size-1:0] src3;

  output [size-1:0] out1;
  output [size-1:0] out2;
  output [size-1:0] out3;
  output [size-1:0] out4;
  output [size-1:0] out5;

  reg [size-1:0]    out1, out2, out3, out4, out5;

  wire [2:0] 	    lsbs = {src1[0], src2[0], src3[0]};

  always @(lsbs)
    casez(lsbs)
      3'b 000: out1 = 0;
      3'b 001: out1 = 1;
      3'b 010: out1 = 2;
      3'b 011: out1 = 3;
      3'b 100: out1 = 4;
      3'b 101: out1 = 5;
      3'b 110: out1 = 6;
      3'b 111: out1 = 7;
      default: out1 = {size{1'bx}};
    endcase

  always @(lsbs)
    casez(lsbs)
      3'b 1??: out2 = 0;
      3'b 01?: out2 = 1;
      3'b 001: out2 = 2;
      3'b 000: out2 = 3;
      default: out2 = {size{1'bx}};
    endcase

  always @(lsbs)
    casez(lsbs)
      3'b 1xx: out3 = 0;
      3'b 01x: out3 = 1;
      3'b 001: out3 = 2;
      3'b 000: out3 = 3;
      default: out3 = {size{1'bx}};
    endcase

  always @(lsbs)
    casez(lsbs)

      3'b 1x?,
      3'b 1?x,
      3'b 1??,
      3'b 1x?:
	out4 = 0;

      3'b 01?,
      3'b 01x,
      3'b 01z:
	out4 = 1;

      3'b 001: out4 = 2;
      3'b 000: out4 = 3;
      default: out4 = {size{1'bx}};
    endcase

  always @(lsbs)
    casez(lsbs)
      3'b x?x: out5 = 0;
      3'b 001: out5 = 1;
      3'b 010: out5 = 2;
      3'b 100: out5 = 3;
      default: out5 = {size{1'bx}};
    endcase

endmodule



/*+VL

module make_tests () ;

 wire [7:0] w;

 comb_test #(1) test1 (w[0:0], w[0:0], w[0:0],
                       w[0:0], w[0:0], w[0:0], w[0:0], w[0:0]);

 comb_test #(2) test2 (w[1:0], w[1:0], w[1:0],
                       w[1:0], w[1:0], w[1:0], w[1:0], w[1:0]);

 comb_test #(3) test3 (w[2:0], w[2:0], w[2:0],
                       w[2:0], w[2:0], w[2:0], w[2:0], w[2:0]);

 comb_test #(4) test4 (w[3:0], w[3:0], w[3:0],
                       w[3:0], w[3:0], w[3:0], w[3:0], w[3:0]);

 comb_test #(5) test5 (w[4:0], w[4:0], w[4:0],
                       w[4:0], w[4:0], w[4:0], w[4:0], w[4:0]);

 comb_test #(6) test6 (w[5:0], w[5:0], w[5:0],
                       w[5:0], w[5:0], w[5:0], w[5:0], w[5:0]);

 comb_test #(7) test7 (w[6:0], w[6:0], w[6:0],
                       w[6:0], w[6:0], w[6:0], w[6:0], w[6:0]);

 comb_test #(8) test8 (w[7:0], w[7:0], w[7:0],
                       w[7:0], w[7:0], w[7:0], w[7:0], w[7:0]);

endmodule

*/


