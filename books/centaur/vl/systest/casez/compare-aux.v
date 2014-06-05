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


// compare-aux.v
//
// Stupid preprocessor hack to introduce a comparison module for some
// particular size.



module `COMPARE_NAME (src1, src2, src3, chk);

  input [`SIZE-1:0] src1 ;
  input [`SIZE-1:0] src2 ;
  input [`SIZE-1:0] src3 ;
  input 	    chk ;

  wire [`SIZE-1:0] spec_out1 ;
  wire [`SIZE-1:0] spec_out2 ;
  wire [`SIZE-1:0] spec_out3 ;
  wire [`SIZE-1:0] spec_out4 ;
  wire [`SIZE-1:0] spec_out5 ;

  wire [`SIZE-1:0] impl_out1 ;
  wire [`SIZE-1:0] impl_out2 ;
  wire [`SIZE-1:0] impl_out3 ;
  wire [`SIZE-1:0] impl_out4 ;
  wire [`SIZE-1:0] impl_out5 ;

  comb_test #(`SIZE) spec (.src1 (src1),
			   .src2 (src2),
			   .src3 (src3),
			   .out1 (spec_out1),
			   .out2 (spec_out2),
			   .out3 (spec_out3),
			   .out4 (spec_out4),
			   .out5 (spec_out5));

  `MODNAME_SIZE impl (.src1 (src1),
		      .src2 (src2),
		      .src3 (src3),
		      .out1 (impl_out1),
		      .out2 (impl_out2),
		      .out3 (impl_out3),
		      .out4 (impl_out4),
		      .out5 (impl_out5));

  wire [2:0] 	   lsbs = {src3[0], src2[0], src1[0]};

  wire 		   lsbsx;
  xz_detect #(3) lsbsx_inst (lsbsx, lsbs);

  // wire srcx1;
  // wire srcx2;
  // wire srcx3;
  // xz_detect #(`SIZE) srcx1_inst (srcx1, src1);
  // xz_detect #(`SIZE) srcx2_inst (srcx2, src2);
  // xz_detect #(`SIZE) srcx3_inst (srcx3, src3);

  wire approx1;
  wire approx2;
  wire approx3;
  wire approx4;
  wire approx5;
  approximates_p #(`SIZE) approx1_inst (approx1, impl_out1, spec_out1);
  approximates_p #(`SIZE) approx2_inst (approx2, impl_out2, spec_out2);
  approximates_p #(`SIZE) approx3_inst (approx3, impl_out3, spec_out3);
  approximates_p #(`SIZE) approx4_inst (approx4, impl_out4, spec_out4);
  approximates_p #(`SIZE) approx5_inst (approx5, impl_out5, spec_out5);

  wire ok1 = spec_out1 === impl_out1 | (lsbsx & approx1);
  wire ok2 = spec_out2 === impl_out2 | (lsbsx & approx2);
  wire ok3 = spec_out3 === impl_out3 | (lsbsx & approx3);
  wire ok4 = spec_out4 === impl_out4 | (lsbsx & approx4);
  wire ok5 = spec_out5 === impl_out5 | (lsbsx & approx5);

  always @(posedge chk)
    begin

//      $display("Checking size %0d: src1 %b, src2 %b, src3 %b",
//               `SIZE, src1, src2, src3);

      if (ok1 !== 1'b1)
	$display("out1 fail: size %0d, src1 %b, src2 %b, src3 %b, spec %b, impl %b, ok %b, approx %b",
		 `SIZE, src1, src2, src3, spec_out1, impl_out1, ok1, approx1);

      if (ok2 !== 1'b1)
	$display("out2 fail: size %0d, src1 %b, src2 %b, src3 %b, spec %b, impl %b, ok %b, approx %b",
		 `SIZE, src1, src2, src3, spec_out2, impl_out2, ok2, approx2);

      if (ok3 !== 1'b1)
	$display("out3 fail: size %0d, src1 %b, src2 %b, src3 %b, spec %b, impl %b, ok %b, approx %b",
		 `SIZE, src1, src2, src3, spec_out3, impl_out3, ok3, approx3);

      if (ok4 !== 1'b1)
	$display("out4 fail: size %0d, src1 %b, src2 %b, src3 %b, spec %b, impl %b, ok %b, approx %b",
		 `SIZE, src1, src2, src3, spec_out4, impl_out4, ok4, approx4);

      if (ok5 !== 1'b1)
	$display("out5 fail: size %0d, src1 %b, src2 %b, src3 %b, spec %b, impl %b, ok %b, approx %b",
		 `SIZE, src1, src2, src3, spec_out5, impl_out5, ok5, approx5);

   end

endmodule
