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

// see flopcode/compare.v

// Using a global random seed seems like a good idea -- When each instance of
// randomBit2 had its own seed, they seemed to just always produce the same
// values on NCVerilog, which was terrible.

module random_top ();
  integer seed;
endmodule

module randomBit2 (q) ;
  // Generates a random two-valued bit every #DELAY ticks.
  parameter delay = 1;
  output q;
  reg q;
  always #delay q <= $random(random_top.seed);
endmodule

module randomVec2 (q);
  // Generates a WIDTH-bit random two-valued vector every #DELAY ticks.
  parameter width = 1;
  parameter delay = 1;
  output [width-1:0] q;
  randomBit2 #(delay) core [width-1:0] (q[width-1:0]);
endmodule

module randomBit4 (q) ;
  // Generates a random four-valued bit every #DELAY ticks.
  parameter delay = 1;
  output q;
  reg [1:0] r;
  always #delay r <= $random(random_top.seed);
  assign q = (r == 2'b 00) ? 1'b0
	   : (r == 2'b 01) ? 1'b1
	   : (r == 2'b 10) ? 1'bX
           :                 1'bZ;
endmodule

module randomVec4 (q);
  // Generates an WIDTH-bit random four-valued vector every #DELAY ticks.
  parameter width = 1;
  parameter delay = 1;
  output [width-1:0] q;
  randomBit4 #(delay) core [width-1:0] (q[width-1:0]);
endmodule



module test () ;

  // This is a hard test bench to write.
  //
  // Problem 1.  Verilog semantics for four-valued clocks are, well, insane.
  // For instance, an X -> 1 transition is considered a posedge.  Because of
  // this sort of thing, we only try to show that our translated flops simulate
  // the same for a two-valued clock.  BOZO can we lift this restriction?
  //
  //
  // Problem 2.  Even the most basic flop imaginable, say:
  //
  //   always @(posedge clk) q <= d;     // "original"
  //
  // has a race condition(!) in Verilog when (posedge clk) happens at the same
  // time as d is changing.  This race condition ends up biting us because
  // "obviously" equivalent things, e.g.,
  //
  //   wire d_next = d;
  //   always @(posedge clk) q <= d;
  //
  // Can end up behaving differently than "original."  That's too bad, because
  // it means that if we want to write tests to show that our translated flops
  // simulate in the same way as the original flops, we have to set up our test
  // code to make sure that the data and clock don't simultaneously change.
  //
  //
  // Problem 3.  Verilog semantics for if-statements are also insane.  Because
  // of this, we only test that our translated G flops (which include
  // conditionals) are conservative approximations of the originals.



  // Basic scheme:
  // All inputs change together (randomly) every 3 ticks.
  // CLK is delayed to 1 tick later than the other inputs.

  wire clk_pre;
  wire [3:0] d1, d2, d3;
  wire 	     en;

  randomBit2 #(3)   mk_clk (clk_pre);
  randomBit4 #(3)   mk_en  (en);
  randomVec4 #(4,3) mk_d1  (d1);
  randomVec4 #(4,3) mk_d2  (d2);
  randomVec4 #(4,3) mk_d3  (d3);

  // Delayed clock to ensure that the clock doesn't change at the same time
  // as the other inputs; see Problem 2 above.
  wire #1 clk = clk_pre;

  // one-bit random data elements for one-bit tests
  wire c1 = d1[0];
  wire c2 = d2[0];
  wire c3 = d3[0];

  // F Modules -- Size 1 Tests
  wire sf1, sf2, sf3, sf4, sf5; // "spec f"
  wire if1, if2, if3, if4, if5; // "impl f"
  f1 f1spec (sf1, c1, clk);
  f2 f2spec (sf2, c1, clk);
  f3 f3spec (sf3, c1, clk);
  f4 f4spec (sf4, c1, c2, c3, clk);
  f5 f5spec (sf5, c1, c2, c3, clk);
  \f1$size=1 f1impl (if1, c1, clk);
  \f2$size=1 f2impl (if2, c1, clk);
  \f3$size=1 f3impl (if3, c1, clk);
  \f4$size=1 f4impl (if4, c1, c2, c3, clk);
  \f5$size=1 f5impl (if5, c1, c2, c3, clk);
  wire okf1 = (sf1 === if1);
  wire okf2 = (sf2 === if2);
  wire okf3 = (sf3 === if3);
  wire okf4 = (sf4 === if4);
  wire okf5 = (sf5 === if5);
  wire okf = &{okf1, okf2, okf3, okf4, okf5};

  // G Modules -- Size 1 Tests
  wire sg1, sg2, sg3, sg4, sg5, sg6; // "spec g"
  wire ig1, ig2, ig3, ig4, ig5, ig6; // "impl g"
  g1 g1spec (sg1, c1, en, clk);
  g2 g2spec (sg2, c1, c2, en, clk);
  g3 g3spec (sg3, c1, c2, en, clk);
  g4 g4spec (sg4, c1, c2, en, clk);
  g5 g5spec (sg5, c1, c2, en, clk);
  g6 g6spec (sg6, c1, c2, en, clk);
  \g1$size=1 g1impl (ig1, c1, en, clk);
  \g2$size=1 g2impl (ig2, c1, c2, en, clk);
  \g3$size=1 g3impl (ig3, c1, c2, en, clk);
  \g4$size=1 g4impl (ig4, c1, c2, en, clk);
  \g5$size=1 g5impl (ig5, c1, c2, en, clk);
  \g6$size=1 g6impl (ig6, c1, c2, en, clk);
  wire okg1 = (sg1 === ig1) | (ig1 === 1'bx);
  wire okg2 = (sg2 === ig2) | (ig2 === 1'bx);
  wire okg3 = (sg3 === ig3) | (ig3 === 1'bx);
  wire okg4 = (sg4 === ig4); // ifs are irrelevant so require exact matching
  wire okg5 = (sg5 === ig5) | (ig5 === 1'bx);
  wire okg6 = (sg6 === ig6); // ifs are irrelevant so require exact matching
  wire okg = &{okg1, okg2, okg3, okg4, okg5, okg6};

  // F Modules -- Size 4 Tests
  wire [3:0] swf1, swf2, swf3, swf4, swf5; // "spec wide f"
  wire [3:0] iwf1, iwf2, iwf3, iwf4, iwf5; // "impl wide f"
  f1 #(4) wf1spec (swf1, d1, clk);
  f2 #(4) wf2spec (swf2, d1, clk);
  f3 #(4) wf3spec (swf3, d1, clk);
  f4 #(4) wf4spec (swf4, d1, d2, d3, clk);
  f5 #(4) wf5spec (swf5, d1, d2, d3, clk);
  \f1$size=4 wf1impl (iwf1, d1, clk);
  \f2$size=4 wf2impl (iwf2, d1, clk);
  \f3$size=4 wf3impl (iwf3, d1, clk);
  \f4$size=4 wf4impl (iwf4, d1, d2, d3, clk);
  \f5$size=4 wf5impl (iwf5, d1, d2, d3, clk);
  wire okwf1 = (swf1 === iwf1);
  wire okwf2 = (swf2 === iwf2);
  wire okwf3 = (swf3 === iwf3);
  wire okwf4 = (swf4 === iwf4);
  wire okwf5 = (swf5 === iwf5);
  wire okwf = &{okwf1, okwf2, okwf3, okwf4, okwf5};

  // G Modules -- Size 4 Tests
  wire [3:0] swg1, swg2, swg3, swg4, swg5, swg6; // "spec wide g"
  wire [3:0] iwg1, iwg2, iwg3, iwg4, iwg5, iwg6; // "impl wide g"
  g1 #(4) wg1spec (swg1, d1, en, clk);
  g2 #(4) wg2spec (swg2, d1, d2, en, clk);
  g3 #(4) wg3spec (swg3, d1, d2, en, clk);
  g4 #(4) wg4spec (swg4, d1, d2, en, clk);
  g5 #(4) wg5spec (swg5, d1, d2, en, clk);
  g6 #(4) wg6spec (swg6, d1, d2, en, clk);
  \g1$size=4 wg1impl (iwg1, d1, en, clk);
  \g2$size=4 wg2impl (iwg2, d1, d2, en, clk);
  \g3$size=4 wg3impl (iwg3, d1, d2, en, clk);
  \g4$size=4 wg4impl (iwg4, d1, d2, en, clk);
  \g5$size=4 wg5impl (iwg5, d1, d2, en, clk);
  \g6$size=4 wg6impl (iwg6, d1, d2, en, clk);

  // The spec is essentially: if (en) q <= d;
  // The implementation will use: q <= en ? d : q;
  // Unfortunately if EN is X, then the spec is crazy/nonsense and
  // will fail to update Q.  The impl is better behaved and will X out
  // Q except for the bits that are identical.  So, we need to allow
  // the impl to have X bits anywhere it doesn't match the spec.
  wire okwg1 = (swg1 === iwg1)
                 | (  (iwg1[0] === swg1[0] | iwg1[0] === 1'bx)
		    & (iwg1[1] === swg1[1] | iwg1[1] === 1'bx)
		    & (iwg1[2] === swg1[2] | iwg1[2] === 1'bx)
		    & (iwg1[3] === swg1[3] | iwg1[3] === 1'bx) );

  // Same thing with IFs, so just require an approximation.
  wire okwg2 = (swg2 === iwg2)
                 | (  (iwg2[0] === swg2[0] | iwg2[0] === 1'bx)
		    & (iwg2[1] === swg2[1] | iwg2[1] === 1'bx)
		    & (iwg2[2] === swg2[2] | iwg2[2] === 1'bx)
		    & (iwg2[3] === swg2[3] | iwg2[3] === 1'bx) );

  // Same thing with IFs, so just require an approximation.
  wire okwg3 = (swg3 === iwg3)
                 | (  (iwg3[0] === swg3[0] | iwg3[0] === 1'bx)
		    & (iwg3[1] === swg3[1] | iwg3[1] === 1'bx)
		    & (iwg3[2] === swg3[2] | iwg3[2] === 1'bx)
		    & (iwg3[3] === swg3[3] | iwg3[3] === 1'bx) );

  // The ifs in g4 are irrelevant due to a later update, so require
  // exact matching.
  wire okwg4 = (swg4 === iwg4);

  // IFs, so just require an approximation.
  wire okwg5 = (swg5 === iwg5)
                 | (  (iwg4[0] === swg4[0] | iwg4[0] === 1'bx)
		    & (iwg4[1] === swg4[1] | iwg4[1] === 1'bx)
		    & (iwg4[2] === swg4[2] | iwg4[2] === 1'bx)
		    & (iwg4[3] === swg4[3] | iwg4[3] === 1'bx) );

  // Although there are IFs here, they are irrelevant because the
  // register always gets updated at the end, so require exact matching.
  wire okwg6 = swg6 === iwg6;
  wire okwg = &{okwg1, okwg2, okwg3, okwg4, okwg5, okwg6};

  wire allok = &{okf, okg, okwf, okwg};

  reg  check;

  /*

  // This is an alternate checking strategy that Sol suggested might be better.

  reg  everything_was_ok;

  always #1
    if (check)
      everything_was_ok <= allok;

  always @(everything_was_ok)
    if (check && everything_was_ok !== 1'b1)
      begin
	$display("failure at time %d", $time);
	$display("okf = %b, [%b]", okf, {okf5, okf4, okf3, okf2, okf1});
	$display("okg = %b, [%b]", okg, {okg6, okg5, okg4, okg3, okg2, okg1});
	$display("okwf = %b, [%b]", okwf, {okwf5, okwf4, okwf3, okwf2, okwf1});
	$display("okwg = %b, [%b]", okwg, {okwg6, okwg5, okwg4, okwg3, okwg2, okwg1});
	$display("");
      end

  */

  // Simple checking strategy:
  always #1
    begin
    $display("checking at time %d", $time);
    if (check && allok !== 1'b1)
      begin
  	$display("failure at time %d", $time);
  	$display("okf = %b, [%b]", okf, {okf5, okf4, okf3, okf2, okf1});
  	$display("okg = %b, [%b]", okg, {okg6, okg5, okg4, okg3, okg2, okg1});
  	$display("okwf = %b, [%b]", okwf, {okwf5, okwf4, okwf3, okwf2, okwf1});
  	$display("okwg = %b, [%b]", okwg, {okwg6, okwg5, okwg4, okwg3, okwg2, okwg1});
  	$display("");
      end
    end

  initial begin
    $dumpfile("compare-flopcode4.vcd");
    $dumpvars();
    check = 0;
//    everything_was_ok = 1;
    #30;
    check = 1;
    #100000;
    $finish;
  end

endmodule






