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


// exhaustive teseting of basic gates

`include "spec.v"
`include "impl.v"

module compare_gates () ;

  reg src1;
  reg src2;
  reg src3;

  wire spec_not;
  wire spec_buf;
  wire spec_and;
  wire spec_or;
  wire spec_xor;
  wire spec_nand;
  wire spec_nor;
  wire spec_xnor;
  wire spec_bufif0;
  wire spec_bufif1;
  wire spec_notif0;
  wire spec_notif1;
  wire spec_nmos;
  wire spec_pmos;
  wire spec_cmos;
  wire spec_rnmos;
  wire spec_rpmos;
  wire spec_rcmos;

  wire impl_not;
  wire impl_buf;
  wire impl_and;
  wire impl_or;
  wire impl_xor;
  wire impl_nand;
  wire impl_nor;
  wire impl_xnor;
  wire impl_bufif0;
  wire impl_bufif1;
  wire impl_notif0;
  wire impl_notif1;
  wire impl_nmos;
  wire impl_pmos;
  wire impl_cmos;
  wire impl_rnmos;
  wire impl_rpmos;
  wire impl_rcmos;

  gates_test spec (
     src1,
     src2,
     src3,
     spec_not,
     spec_buf,
     spec_and,
     spec_or,
     spec_xor,
     spec_nand,
     spec_nor,
     spec_xnor,
     spec_bufif0,
     spec_bufif1,
     spec_notif0,
     spec_notif1,
     spec_nmos,
     spec_pmos,
     spec_cmos,
     spec_rnmos,
     spec_rpmos,
     spec_rcmos
  );

  \gates_test$size=1 impl (
     src1,
     src2,
     src3,
     impl_not,
     impl_buf,
     impl_and,
     impl_or,
     impl_xor,
     impl_nand,
     impl_nor,
     impl_xnor,
     impl_bufif0,
     impl_bufif1,
     impl_notif0,
     impl_notif1,
     impl_nmos,
     impl_pmos,
     impl_cmos,
     impl_rnmos,
     impl_rpmos,
     impl_rcmos
  );

  reg [3:0] Vals;
  integer i0, i1, i2;

  reg check;

  initial begin
    src1 <= 1'b0;
    src2 <= 1'b0;
    src3 <= 1'b0;

    Vals <= 4'bZX10;

    for(i0 = 0; i0 < 4; i0 = i0 + 1)
    for(i1 = 0; i1 < 4; i1 = i1 + 1)
    for(i2 = 0; i2 < 4; i2 = i2 + 1)
    begin
       src1 = Vals[i0];
       src2 = Vals[i1];
       src3 = Vals[i2];
       #100
       check = 1;
       #100
       check = 0;
    end
  end

  always @(posedge check)
  begin

     if ((impl_not !== spec_not)      ||
        (impl_buf !== spec_buf)       ||
        (impl_and !== spec_and)       ||
        (impl_or !== spec_or)         ||
        (impl_xor !== spec_xor)       ||
        (impl_nand !== spec_nand)     ||
        (impl_nor !== spec_nor)       ||
        (impl_xnor !== spec_xnor)     ||
        (impl_bufif0 !== spec_bufif0) ||
        (impl_bufif1 !== spec_bufif1) ||
        (impl_notif0 !== spec_notif0) ||
        (impl_notif1 !== spec_notif1) ||
        (impl_nmos !== spec_nmos)     ||
        (impl_pmos !== spec_pmos)     ||
        (impl_cmos !== spec_cmos)     ||
        (impl_rnmos !== spec_rnmos)   ||
        (impl_rpmos !== spec_rpmos)   ||
        (impl_rcmos !== spec_rcmos))
     begin
     $display("--- src1 = %b, src2 = %b, src3 = %b -------", src1, src2, src3);

     if (impl_not !== spec_not)       $display("fail not:    impl = %b, spec = %b", impl_not,  spec_not);
     if (impl_buf !== spec_buf)       $display("fail buf:    impl = %b, spec = %b", impl_buf,  spec_buf);
     if (impl_and !== spec_and)       $display("fail and:    impl = %b, spec = %b", impl_and,  spec_and);
     if (impl_or !== spec_or)         $display("fail or:     impl = %b, spec = %b", impl_or,   spec_or);
     if (impl_xor !== spec_xor)       $display("fail xor:    impl = %b, spec = %b", impl_xor,  spec_xor);
     if (impl_nand !== spec_nand)     $display("fail nand:   impl = %b, spec = %b", impl_nand, spec_nand);
     if (impl_nor !== spec_nor)       $display("fail nor:    impl = %b, spec = %b", impl_nor,  spec_nor);
     if (impl_xnor !== spec_xnor)     $display("fail xnor:   impl = %b, spec = %b", impl_xnor, spec_xnor);
     if (impl_bufif0 !== spec_bufif0) $display("fail bufif0: impl = %b, spec = %b", impl_bufif0, spec_bufif0);
     if (impl_bufif1 !== spec_bufif1) $display("fail bufif1: impl = %b, spec = %b", impl_bufif1, spec_bufif1);
     if (impl_notif0 !== spec_notif0) $display("fail notif0: impl = %b, spec = %b", impl_notif0, spec_notif0);
     if (impl_notif1 !== spec_notif1) $display("fail notif1: impl = %b, spec = %b", impl_notif1, spec_notif1);


     if (impl_nmos !== spec_nmos)     $display("%s nmos:   impl = %b, spec = %b", ((impl_nmos === 1'bx)  ? "conservative" : "fail"), impl_nmos,  spec_nmos);
     if (impl_pmos !== spec_pmos)     $display("%s pmos:   impl = %b, spec = %b", ((impl_pmos === 1'bx)  ? "conservative" : "fail"), impl_pmos,  spec_pmos);
     if (impl_cmos !== spec_cmos)     $display("%s cmos:   impl = %b, spec = %b", ((impl_cmos === 1'bx)  ? "conservative" : "fail"), impl_cmos,  spec_cmos);
     if (impl_rnmos !== spec_rnmos)   $display("%s rnmos:  impl = %b, spec = %b", ((impl_rnmos === 1'bx) ? "conservative" : "fail"), impl_rnmos, spec_rnmos);
     if (impl_rpmos !== spec_rpmos)   $display("%s rpmos:  impl = %b, spec = %b", ((impl_rpmos === 1'bx) ? "conservative" : "fail"), impl_rpmos, spec_rpmos);
     if (impl_rcmos !== spec_rcmos)   $display("%s rcmos:  impl = %b, spec = %b", ((impl_rcmos === 1'bx) ? "conservative" : "fail"), impl_rcmos, spec_rcmos);

     $display("----------------------------------------\n");

    end

  end


endmodule

