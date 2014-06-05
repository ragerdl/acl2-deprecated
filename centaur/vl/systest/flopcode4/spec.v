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


// Similar to flopcode, but focuses on statement rewriting...

module f1 (q, d, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d;
  input 	    clk;

  reg [size-1:0]    q;

  always @(q or clk or d)
    // this should just all fizzle away into nothing
    begin
      $display("; stmtrewrite should take care of this");
      $display("; and this, too!");
      repeat(3)
	begin
	  $display("; and this tambien!");
	  $display("; this also");
	end
    end

  always @(negedge clk)
    begin
      begin
      end
      if (clk)
	$display("; clock on");
      else
	$display("; clock off");
      begin
      end
      begin
	begin
	  begin
	    q <= d;
	  end
	  $display("; hello");
	end
      end
      begin
      end
    end

endmodule


module f2 (q, d, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d;
  input 	    clk;

  reg [size-1:0]    q;

  always @(posedge clk)
    begin
      q <= #2 d;
      q <= #2 d;
      q <= #2 d;
      q <= #2 0;
      q <= #2 1;
      q <= #2 2;
      begin
	q <= #2 6;
	q <= #2 clk;
        $display("; blah");
	q <= #2 d;
      end
    end

endmodule


module f3 (q, d, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d;
  input 	    clk;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      q <= #3 d;
      begin
	q <= #3 d;
	begin
	  q <= #3 {size {1'b0}};
	end
	q <= #3 {size {1'b1}};
      end
      q <= #3 d;
    end

endmodule


module f4 (q, d1, d2, d3, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2, d3;
  input 	    clk;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      q <= d1;
      $display("; q is %b", q);
      q <= d2;
      $display("; q is %b", q);
      q <= d3;
      $display("; q is %b", q);
    end

endmodule


module f5 (q, d1, d2, d3, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2, d3;
  input 	    clk;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      q <= #1 d1;
      q <= #1 d2;
      q <= #1 d3;
      q <= #1 d1;
      q <= #1 d2;
      q <= #1 d3;
    end

endmodule


// G modules: flops with various conditional and unconditional always assignments.

module g1 (q, d, en, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d;
  input 	    clk, en;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      if (en)
	begin
	  q <= #3 d;
	end
    end

endmodule


module g2 (q, d1, d2, en, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2;
  input 	    clk, en;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      if (en)
	q <= #2 d1;
      else
	begin
	  q <= #2 d2;
	  $display("; else statement");
	end
    end

endmodule


module g3 (q, d1, d2, en, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2;
  input 	    clk, en;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      q <= d1;
      if (en)
	begin
	  if (d1)
	    q <= d2;
          else
	    q <= d1;
	end
    end

endmodule


module g4 (q, d1, d2, en, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2;
  input 	    clk, en;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      if (en)
	q <= #3 d1;
      else
	q <= #3 0;
      q <= #3 d2;
    end

endmodule


module g5 (q, d1, d2, en, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2;
  input 	    clk, en;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      q <= d1;
      if (en)
	q <= d1;
      else if (0)
	q <= d2;
      else
	q <= en;
    end

endmodule


module g6 (q, d1, d2, en, clk);

  parameter size = 1;

  output [size-1:0] q;
  input [size-1:0]  d1, d2;
  input 	    clk, en;

  reg [size-1:0]    q;

  always @(negedge clk)
    begin
      q <= d1;
      begin
	if (en) q <= d1;
	else q <= d2;
      end
      q <= d2;
    end

endmodule



/*+VL

module make_tests();

  wire  q, d1, d2, d3, en, clk;

  f1 f1spec (q, d1, clk);
  f2 f2spec (q, d1, clk);
  f3 f3spec (q, d1, clk);
  f4 f4spec (q, d1, d2, d3, clk);
  f5 f5spec (q, d1, d2, d3, clk);

  g1 g1spec (q, d1, en, clk);
  g2 g2spec (q, d1, d2, en, clk);
  g3 g3spec (q, d1, d2, en, clk);
  g4 g4spec (q, d1, d2, en, clk);
  g5 g5spec (q, d1, d2, en, clk);
  g6 g6spec (q, d1, d2, en, clk);


 wire [3:0] q4, d4;

  f1 #(4) f1spec4 (q4, d4, clk);
  f2 #(4) f2spec4 (q4, d4, clk);
  f3 #(4) f3spec4 (q4, d4, clk);
  f4 #(4) f4spec4 (q4, d4, d4, d4, clk);
  f5 #(4) f5spec4 (q4, d4, d4, d4, clk);

  g1 #(4) g1spec4 (q4, d4, en, clk);
  g2 #(4) g2spec4 (q4, d4, d4, en, clk);
  g3 #(4) g3spec4 (q4, d4, d4, en, clk);
  g4 #(4) g4spec4 (q4, d4, d4, en, clk);
  g5 #(4) g5spec4 (q4, d4, d4, en, clk);
  g6 #(4) g6spec4 (q4, d4, d4, en, clk);

endmodule

*/
