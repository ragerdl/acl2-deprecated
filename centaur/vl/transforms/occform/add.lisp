; VL Verilog Toolkit
; Copyright (C) 2008-2014 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "VL")
(include-book "simple")
(include-book "xdet")
(local (include-book "../../util/arithmetic"))
(local (include-book "../../util/osets"))
(local (std::add-default-post-define-hook :fix))
(local (in-theory (disable vl-maybe-module-p-when-vl-module-p)))

(defval *vl-1-bit-adder-core-support*
  :parents (*vl-1-bit-adder-core*)
  (list *vl-1-bit-xor*
        *vl-1-bit-and*
        *vl-1-bit-or*))

(defval *vl-1-bit-adder-core*
  :parents (occform)
  :short "Primitive one-bit full-adder module."

  :long "<p>A full-adder is a one-bit adder that produces a sum and carry.  We
use the following definition:</p>

@({
module VL_1_BIT_ADDER_CORE (sum, cout, a, b, cin) ;
  output sum, cout;
  input a, b, cin;
  wire t1, t2, t3;

  assign t1 = a ^ b;
  assign sum = t1 ^ cin;
  assign t2 = t1 & cin;
  assign t3 = a & b;
  assign cout = t2 | t3;

endmodule
})

<p>This is only a \"core.\" It doesn't quite correspond to an addition like
@('assign {carry, sum} = a + b + cin') in Verilog because of X handling.  See
@(see vl-make-n-bit-plusminus) for the real module generator.</p>"

  (b* ((name (hons-copy "VL_1_BIT_ADDER_CORE"))

       ((mv sum-expr sum-port sum-portdecl sum-netdecl)     (vl-primitive-mkport "sum" :vl-output))
       ((mv cout-expr cout-port cout-portdecl cout-netdecl) (vl-primitive-mkport "cout" :vl-output))
       ((mv a-expr a-port a-portdecl a-netdecl)             (vl-primitive-mkport "a" :vl-input))
       ((mv b-expr b-port b-portdecl b-netdecl)             (vl-primitive-mkport "b" :vl-input))
       ((mv cin-expr cin-port cin-portdecl cin-netdecl)     (vl-primitive-mkport "cin" :vl-input))

       ((mv t1-expr t1-netdecl) (vl-primitive-mkwire "t1"))
       ((mv t2-expr t2-netdecl) (vl-primitive-mkwire "t2"))
       ((mv t3-expr t3-netdecl) (vl-primitive-mkwire "t3"))

       (t1-inst   (vl-simple-inst *vl-1-bit-xor* "mk_t1"   t1-expr   a-expr  b-expr))
       (sum-inst  (vl-simple-inst *vl-1-bit-xor* "mk_sum"  sum-expr  t1-expr cin-expr))
       (t2-inst   (vl-simple-inst *vl-1-bit-and* "mk_t2"   t2-expr   t1-expr cin-expr))
       (t3-inst   (vl-simple-inst *vl-1-bit-and* "mk_t3"   t3-expr   a-expr  b-expr))
       (cout-inst (vl-simple-inst *vl-1-bit-or*  "mk_cout" cout-expr t2-expr t3-expr)))

    (hons-copy
     (make-vl-module :name      name
                     :origname  name
                     :ports     (list sum-port cout-port a-port b-port cin-port)
                     :portdecls (list sum-portdecl cout-portdecl a-portdecl b-portdecl cin-portdecl)
                     :netdecls  (list sum-netdecl cout-netdecl a-netdecl b-netdecl cin-netdecl t1-netdecl t2-netdecl t3-netdecl)
                     :modinsts (list t1-inst sum-inst t2-inst t3-inst cout-inst)
                     :minloc    *vl-fakeloc*
                     :maxloc    *vl-fakeloc*))))

(def-vl-modgen vl-make-n-bit-adder-core ((n posp))
  :short "Generate an N-bit basic ripple-carry adder module."

  :long "<p>We generate a gate-based module with the following interface:</p>

@({
module VL_N_BIT_ADDER_CORE (sum, cout, a, b, cin);
  output [n-1:0] sum;
  output cout;
  input [n-1:0] a;
  input [n-1:0] b;
  input cin;
  ...
endmodule
})

<p>This is a basic ripple-carry adder formed by chaining together several
full-adders; see @(see *vl-1-bit-adder-core*).</p>

<p>This module does NOT correspond to a full addition in Verilog.  It computes
something akin to @('assign {cout, sum} = a + b + cin'), but it does not handle
X's like Verilog does.  See @(see vl-make-n-bit-plusminus) for the full
addition and subtraction modules.</p>

<p>We could probably make a leaner module by using a half-adder for the first
bit (which does not have a carry-in) and by dropping the wires on the carry for
the last bit, but we think it's best to keep things simple.</p>"

  :body
  (b* ((n (lposfix n))
       ((when (eql n 1))
        (cons *vl-1-bit-adder-core* *vl-1-bit-adder-core-support*))

       (name (hons-copy (cat "VL_" (natstr n) "_BIT_ADDER_CORE")))

       ((mv sum-expr sum-port sum-portdecl sum-netdecl)     (vl-occform-mkport "sum" :vl-output n))
       ((mv cout-expr cout-port cout-portdecl cout-netdecl) (vl-primitive-mkport "cout" :vl-output))
       ((mv a-expr a-port a-portdecl a-netdecl)             (vl-occform-mkport "a" :vl-input n))
       ((mv b-expr b-port b-portdecl b-netdecl)             (vl-occform-mkport "b" :vl-input n))
       ((mv cin-expr cin-port cin-portdecl cin-netdecl)     (vl-primitive-mkport "cin" :vl-input))

       ;; wire [n-2:0] carry;
       ((mv carry-expr carry-netdecl) (vl-occform-mkwire "carry" (- n 1)))

       ;; Now we build a big array of full-adders, basically:

       ;; VL_BASIC_FULL_ADDER fa_0     (sum[0],   carry[0],   a[0],   b[0],   cin);
       ;; VL_BASIC_FULL_ADDER fa_1     (sum[1],   carry[1],   a[1],   b[1],   carry[0]);
       ;; VL_BASIC_FULL_ADDER fa_2     (sum[2],   carry[2],   a[2],   b[2],   carry[1]);
       ;;    ...
       ;; VL_BASIC_FULL_ADDER fa_{n-2} (sum[n-2], carry[n-2], a[n-2], b[n-2], carry[n-3]);
       ;; VL_BASIC_FULL_ADDER fa_{n-1} (sum[n-1], cout,       a[n-1], b[n-2], carry[n-2]);

       (sum-wires   (vl-make-list-of-bitselects sum-expr   0 (- n 1)))
       (carry-wires (vl-make-list-of-bitselects carry-expr 0 (- n 2)))
       (a-wires     (vl-make-list-of-bitselects a-expr     0 (- n 1)))
       (b-wires     (vl-make-list-of-bitselects b-expr     0 (- n 1)))

       (fa-insts    (vl-simple-inst-list *vl-1-bit-adder-core* "fa_"
                                         sum-wires
                                         (append carry-wires (list cout-expr))
                                         a-wires
                                         b-wires
                                         (cons cin-expr carry-wires))))

    (list* (make-vl-module :name      name
                           :origname  name
                           :ports     (list sum-port cout-port a-port b-port cin-port)
                           :portdecls (list sum-portdecl cout-portdecl a-portdecl b-portdecl cin-portdecl)
                           :netdecls  (list sum-netdecl cout-netdecl a-netdecl b-netdecl cin-netdecl carry-netdecl)
                           :modinsts  fa-insts
                           :minloc    *vl-fakeloc*
                           :maxloc    *vl-fakeloc*)
           *vl-1-bit-adder-core*
           *vl-1-bit-adder-core-support*)))

#||
(vl-pps-modulelist (vl-make-n-bit-adder-core 10))
||#



(def-vl-modgen vl-make-n-bit-plusminus ((type (member type (list :vl-binary-plus :vl-binary-minus)))
                                        (n    posp))

  :short "Generate an addition or subtraction module."

  :long "<p>Depending on the @('type'), which should be either
@(':vl-binary-plus') or @(':vl-binary-minus'), we generate a gate-based
addition or subtraction module that is semantically equivalent to:</p>

@({
module VL_N_BIT_{PLUS,MINUS} (out, a, b) ;
  output [n-1:0] out;
  input [n-1:0] a;
  input [n-1:0] b;

// One of:

  assign out = a + b;  // For PLUS
  assign out = a - b;  // For MINUS

endmodule
})

<p>These modules capture the behavior specified by Verilog for addition and
subtraction, including the requirement that if any bit of @('a') or @('b') is
X/Z then the entire output is entirely X.</p>

<p>We basically combine a simple ripple-carry adder with some additional
X-detection and propagation circuitry.  This makes our adder rather bulky and
unlike the actual hardware that would probably be synthesized or
implemented.</p>"

  :body
  (b* ((n     (lposfix n))
       (name  (hons-copy (cat "VL_" (natstr n) "_BIT_"
                              (case type
                                (:vl-binary-plus "PLUS")
                                (:vl-binary-minus "MINUS")))))

       ((mv out-expr out-port out-portdecl out-netdecl) (vl-occform-mkport "out" :vl-output n))
       ((mv a-expr a-port a-portdecl a-netdecl)         (vl-occform-mkport "a" :vl-input n))
       ((mv b-expr b-port b-portdecl b-netdecl)         (vl-occform-mkport "b" :vl-input n))

       ((mv sum-expr sum-netdecl)     (vl-occform-mkwire "sum" n))
       ((mv carry-expr carry-netdecl) (vl-primitive-mkwire "carry"))

       ;; For addition, we use a carry-in of zero and do not negate b.  But
       ;; if we are subtracting, we need to use a carry-in of 1 and negate
       ;; the B input.
       ((mv cin bin sub-netdecls sub-modinsts sub-support)
        (if (eq type :vl-binary-plus)
            ;; addition: carry in = 0, b-input = b
            (mv |*sized-1'b0*| b-expr nil nil nil)
          ;; subtraction: carry in = 1, b-input = ~b
          (b* (;; wire [n-1:0] bnot = ~b;
               ((mv bnot-expr bnot-netdecl)  (vl-occform-mkwire "bnot" n))
               ((cons bnot-mod bnot-support) (vl-make-n-bit-not n))
               (bnot-inst (vl-simple-inst bnot-mod "mk_bnot" bnot-expr b-expr)))
            (mv |*sized-1'b1*|
                bnot-expr
                (list bnot-netdecl)
                (list bnot-inst)
                (cons bnot-mod bnot-support)))))

       ;; Instantiate a ripple-carry adder to do all the work
       ((cons core-mod core-support) (vl-make-n-bit-adder-core n))
       (core-inst (vl-simple-inst core-mod "core" sum-expr carry-expr a-expr bin cin))

       ;; Now slap x-detection onto the "sum" to compute the answer
       ((cons xprop-mod xprop-support) (vl-make-n-bit-x-propagator n n))
       (xprop-inst (vl-simple-inst xprop-mod "xprop" out-expr sum-expr a-expr b-expr)))

    (list* (make-vl-module :name      name
                           :origname  name
                           :ports     (list out-port a-port b-port)
                           :portdecls (list out-portdecl a-portdecl b-portdecl)
                           :netdecls  (list* out-netdecl a-netdecl b-netdecl sum-netdecl carry-netdecl sub-netdecls)
                           :modinsts  (append sub-modinsts (list core-inst xprop-inst))
                           :minloc    *vl-fakeloc*
                           :maxloc    *vl-fakeloc*)
           core-mod
           xprop-mod
           (append sub-support core-support xprop-support))))

#||
(vl-pps-modulelist (vl-make-n-bit-plusminus :vl-binary-plus 10))
(vl-pps-modulelist (vl-make-n-bit-plusminus :vl-binary-minus 10))
||#



