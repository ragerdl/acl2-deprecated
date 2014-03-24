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


// Exhaustive testing of binary operators up to some small size

`include "spec.v"
`include "impl.v"

// Nasty preprocessor garbage to introduce comparison modules for each of the
// various sizes.  See aux-compare-binary.v for details.

`define SIZE 1
`define MODNAME_SIZE \comb_test$size=1
`define COMPARE_NAME compare_aux_1
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 2
`define MODNAME_SIZE \comb_test$size=2
`define COMPARE_NAME compare_aux_2
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 3
`define MODNAME_SIZE \comb_test$size=3
`define COMPARE_NAME compare_aux_3
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 4
`define MODNAME_SIZE \comb_test$size=4
`define COMPARE_NAME compare_aux_4
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 5
`define MODNAME_SIZE \comb_test$size=5
`define COMPARE_NAME compare_aux_5
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 6
`define MODNAME_SIZE \comb_test$size=6
`define COMPARE_NAME compare_aux_6
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 7
`define MODNAME_SIZE \comb_test$size=7
`define COMPARE_NAME compare_aux_7
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME

`define SIZE 8
`define MODNAME_SIZE \comb_test$size=8
`define COMPARE_NAME compare_aux_8
`include "compare-aux.v"
`undef SIZE
`undef MODNAME_SIZE
`undef COMPARE_NAME




module xz_detect (out, in);
  parameter size = 1;
  output out;
  input [size-1:0] in;
  integer 	   i;
  reg 		   out;
  always @(in)
    begin
      out = 0;
      for(i = 0; i < size; i = i + 1)
	if (in[i] === 1'bx || in[i] === 1'bz)
	  out = 1;
    end
endmodule

module approximates_p (out, impl, spec);
  // Does impl conservatively approximate spec?
  // I.e., does it agree exactly with Spec or is it X whenever it disagrees?
  parameter size = 1;
  output out;
  input [size-1:0] impl;
  input [size-1:0] spec;

  integer 	   i;
  reg 		   out;
  always @(impl or spec)
    begin
      out = 1;
      for(i = 0; i < size; i = i + 1)
	out = out & ((impl[i] === spec[i] | impl[i] === 1'bx));
    end
endmodule

module compare () ;

  reg [7:0]  src1;
  reg [7:0]  src2;
  reg [7:0]  src3;
  reg 	     chk;

  compare_aux_1 test1 (src1[0:0], src2[0:0], src3[0:0], chk);
  compare_aux_2 test2 (src1[1:0], src2[1:0], src3[1:0], chk);
  compare_aux_3 test3 (src1[2:0], src2[2:0], src3[2:0], chk);
  compare_aux_4 test4 (src1[3:0], src2[3:0], src3[3:0], chk);
  compare_aux_5 test5 (src1[4:0], src2[4:0], src3[4:0], chk);
  compare_aux_6 test6 (src1[5:0], src2[5:0], src3[5:0], chk);
  compare_aux_7 test7 (src1[6:0], src2[6:0], src3[6:0], chk);
  compare_aux_8 test8 (src1[7:0], src2[7:0], src3[7:0], chk);

  reg [3:0]  Vals;
  integer    i0, i1, i2, i3, i4, i5, i6, i7, i8;
  integer    j0, j1, j2, j3, j4, j5, j6, j7, j8;
  integer    seed;

  initial
    begin
      Vals = 4'bZX10;  // The valid Verilog values
      chk = 1'b0;
      seed = 0;

      for(i0 = 0; i0 < 4; i0 = i0 + 1)
      for(i1 = 0; i1 < 4; i1 = i1 + 1)
      for(i2 = 0; i2 < 4; i2 = i2 + 1)
      for(i3 = 0; i3 < 4; i3 = i3 + 1)
      for(i4 = 0; i4 < 4; i4 = i4 + 1)
      for(i5 = 0; i5 < 4; i5 = i5 + 1)
      for(i6 = 0; i6 < 4; i6 = i6 + 1)
      for(i7 = 0; i7 < 4; i7 = i7 + 1)

      for(j0 = 0; j0 < 50; j0 = j0 + 1)
      begin

	src1 = $random(seed);
	src2 = $random(seed);
	src3 = $random(seed);
	src1[3:0] = {Vals[i0], Vals[i1], Vals[i2], Vals[i3]};
	src2[3:0] = {Vals[i4], Vals[i5], Vals[i6], Vals[i7]};
	#5 chk = 1;
	#5 chk = 0;

      end

   end

endmodule
