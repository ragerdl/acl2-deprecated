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

`include "spec.v"
`include "impl.v"



`define SIZE 1
`define MODNAME_SIZE \spec$width=1
`define COMPARE_NAME compare_aux_1
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 2
`define MODNAME_SIZE \spec$width=2
`define COMPARE_NAME compare_aux_2
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 3
`define MODNAME_SIZE \spec$width=3
`define COMPARE_NAME compare_aux_3
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 4
`define MODNAME_SIZE \spec$width=4
`define COMPARE_NAME compare_aux_4
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 5
`define MODNAME_SIZE \spec$width=5
`define COMPARE_NAME compare_aux_5
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 6
`define MODNAME_SIZE \spec$width=6
`define COMPARE_NAME compare_aux_6
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 7
`define MODNAME_SIZE \spec$width=7
`define COMPARE_NAME compare_aux_7
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 8
`define MODNAME_SIZE \spec$width=8
`define COMPARE_NAME compare_aux_8
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME


module convert_z_to_x (out, in);

   parameter size = 1;

   output [size-1:0] out;
   input [size-1:0] in;

   reg [size-1:0] out;

   integer i;
   always @(in)
   begin
      for(i = 0; i < size; i = i + 1)
      begin
	 out[i] = (in[i] === 1'bz) ? 1'bx : in[i];
      end
   end

endmodule

module test () ;

  reg [7:0] a, b, c;
  reg 	     check;

  compare_aux_1 test1 (a[0:0], b[0:0], c[0:0], check);
  compare_aux_2 test2 (a[1:0], b[1:0], c[1:0], check);
  compare_aux_3 test3 (a[2:0], b[2:0], c[2:0], check);
  compare_aux_4 test4 (a[3:0], b[3:0], c[3:0], check);
  compare_aux_5 test5 (a[4:0], b[4:0], c[4:0], check);
  compare_aux_6 test6 (a[5:0], b[5:0], c[5:0], check);
  compare_aux_7 test7 (a[6:0], b[6:0], c[6:0], check);
  compare_aux_8 test8 (a[7:0], b[7:0], c[7:0], check);

  reg [3:0]  V;
  integer    i0, i1, i2, i3, i4, i5, i6, i7;
  integer    j0, j1, j2, j3, j4, j5, j6, j7;
  integer    k0, k1, k2, k3, k4, k5, k6, k7;
  integer    seed;
  integer    times;
  

  initial begin
    V = 4'bzx10;
    seed = 0;
    check = 0;
    #5
      for(i0 = 0; i0 < 4; i0 = i0 + 1)
      for(i1 = 0; i1 < 4; i1 = i1 + 1)
      for(i2 = 0; i2 < 4; i2 = i2 + 1)
      for(j0 = 0; j0 < 4; j0 = j0 + 1)
      for(j1 = 0; j1 < 4; j1 = j1 + 1)
      for(j2 = 0; j2 < 4; j2 = j2 + 1)
      for(k0 = 0; k0 < 4; k0 = k0 + 1)
      for(k1 = 0; k1 < 4; k1 = k1 + 1)
      for(k2 = 0; k2 < 4; k2 = k2 + 1)
      for(times = 0;times < 5;times = times+1)
      begin
	a = { $random(seed), V[i0], V[i1], V[i2] };
 	b = { $random(seed), V[j0], V[j1], V[j2] };
 	c = { $random(seed), V[k0], V[k1], V[k2] };
 	#10;
	check = 0;
	#10;
	check = 1;
	#10;
      end
  end

endmodule
