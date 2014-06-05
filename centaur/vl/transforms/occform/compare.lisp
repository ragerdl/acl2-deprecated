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
(include-book "add")
(local (include-book "../../util/arithmetic"))
(local (include-book "../../util/osets"))
(local (std::add-default-post-define-hook :fix))
(local (in-theory (disable vl-maybe-module-p-when-vl-module-p)))

(def-vl-modgen vl-make-n-bit-unsigned-gte ((n posp))
  :short "Generate an unsigned greater-than or equal comparison module."

  :long "<p>We generate a gate-based module that is semantically equivalent
to:</p>

@({
module VL_N_BIT_UNSIGNED_GTE (out, a, b) ;
  output out;
  input [n-1:0] a;
  input [n-1:0] b;
  assign out = a >= b;
endmodule
})

<p>Note that in @(see oprewrite) we canonicalize any @('<'), @('<='), and
@('>') operators into the @('>=') form, so this module actually handles all
inequality comparisons.</p>

<p>The basic idea is to compute @('a + ~b + 1') and look at the carry chain.
We do this by directly instantiating an adder.  This might be somewhat
inefficient since we really don't need to be computing the sum.  On the other
hand, there are really not very many comparison operators so we suspect we do
not need to be particularly efficient, and hopefully in any AIG or S-Expression
based representations the extra work will be automatically thrown away.</p>

<p>Note that the Verilog semantics require that if @('a') or @('b') have any
X/Z bits, then the answer should be X.  This is true even when the X occurs in
an insignificant place, e.g., @('1000 > 000x') is considered to be X even
though no matter what the X digit is, we can see that the mathematical answer
ought to be 1.  (This behavior might be intended to give synthesis tools as
much freedom as possible when implementing the operation.)</p>"

  :body
  (b* ((n    (lposfix n))
       (name (hons-copy (cat "VL_" (natstr n) "_BIT_UNSIGNED_GTE")))

       ((mv out-expr out-port out-portdecl out-netdecl) (vl-primitive-mkport "out" :vl-output))
       ((mv a-expr a-port a-portdecl a-netdecl)         (vl-occform-mkport "a" :vl-input n))
       ((mv b-expr b-port b-portdecl b-netdecl)         (vl-occform-mkport "b" :vl-input n))

       ((mv bnot-expr bnot-netdecl)  (vl-occform-mkwire "bnot" n))
       ((mv sum-expr sum-netdecl)    (vl-occform-mkwire "sum" n))
       ((mv cout-expr cout-netdecl)  (vl-primitive-mkwire "cout"))

       ;; assign bnot = ~b;
       ((cons bnot-mod bnot-support) (vl-make-n-bit-not n))
       (bnot-inst (vl-simple-inst bnot-mod "mk_bnot" bnot-expr b-expr))

       ;; VL_N_BIT_ADDER_CORE core (sum, cout, a, ~b, 1);
       ((cons core-mod core-support) (vl-make-n-bit-adder-core n))
       (core-inst (vl-simple-inst core-mod "core" sum-expr cout-expr a-expr bnot-expr |*sized-1'b1*|))

       ;; cout is almost right, but we also need to detect xes
       ((cons xprop-mod xprop-support) (vl-make-n-bit-x-propagator n 1))
       (xprop-inst (vl-simple-inst xprop-mod "xprop" out-expr cout-expr a-expr b-expr)))

    (list* (make-vl-module :name      name
                           :origname  name
                           :ports     (list out-port a-port b-port)
                           :portdecls (list out-portdecl a-portdecl b-portdecl)
                           :netdecls  (list out-netdecl a-netdecl b-netdecl sum-netdecl cout-netdecl bnot-netdecl)
                           :modinsts  (list bnot-inst core-inst xprop-inst)
                           :minloc    *vl-fakeloc*
                           :maxloc    *vl-fakeloc*)
           bnot-mod core-mod xprop-mod
           (append bnot-support core-support xprop-support))))

#||
(vl-pps-modulelist (vl-make-n-bit-unsigned-gte 10))
||#



(defval *vl-1-bit-signed-gte*
  :parents (occform)
  :short "Degenerate, single-bit signed greater-than-or-equal module."

  :long "<p>This is a gate-based module that is semantically equivalent to:</p>

@({
module VL_1_BIT_SIGNED_GTE (out, a, b);
  output out;
  input signed a;
  input signed b;

  assign out = a >= b;
endmodule
})

<p>Since Verilog uses 2's complement as its representation of signed numbers,
in the degenerate world of sign-bits we should have \"<em>0 means 0 and 1 means
-1</em>\".  So, counterintuitively, @('a >= b') holds except when @('a = 1')
and @('b = 0').</p>

<p><b>Warning:</b> The above is indeed the behavior implemented by NCVerilog.
But Verilog-XL appears to be buggy and instead produces results that are
consistent with an unsigned interpretation; see tests/test-scomp.v.</p>

<p>Our actual module is:</p>

@({
module VL_1_BIT_SIGNED_GTE (out, a, b);
  output out;
  input a, b;
  wire bbar, mainbar, main, xa, xb, xab;

  not(bbar, b);                    // assign main = ~(a & ~b)
  and(mainbar, a, bbar);
  not(main, mainbar);

  xor(xb, b, b);                   // Propagate Xes
  xor(xa, a, a);
  xor(xab, xa, xb);
  xor(out, xab, main);
endmodule
})"

  (b* ((name (hons-copy "VL_1_BIT_SIGNED_GTE"))

       ((mv out-expr out-port out-portdecl out-netdecl) (vl-primitive-mkport "out" :vl-output))
       ((mv a-expr a-port a-portdecl a-netdecl)         (vl-primitive-mkport "a" :vl-input))
       ((mv b-expr b-port b-portdecl b-netdecl)         (vl-primitive-mkport "b" :vl-input))

       ((mv bbar-expr bbar-netdecl)       (vl-primitive-mkwire "bbar"))
       ((mv mainbar-expr mainbar-netdecl) (vl-primitive-mkwire "mainbar"))
       ((mv main-expr main-netdecl)       (vl-primitive-mkwire "main"))
       ((mv xa-expr xa-netdecl)           (vl-primitive-mkwire "xa"))
       ((mv xb-expr xb-netdecl)           (vl-primitive-mkwire "xb"))
       ((mv xab-expr xab-netdecl)         (vl-primitive-mkwire "xab"))

       (bbar-inst    (vl-simple-inst *vl-1-bit-not* "mk_bbar"    bbar-expr    b-expr))
       (mainbar-inst (vl-simple-inst *vl-1-bit-and* "mk_mainbar" mainbar-expr a-expr       bbar-expr))
       (main-inst    (vl-simple-inst *vl-1-bit-not* "mk_main"    main-expr    mainbar-expr))
       (xb-inst      (vl-simple-inst *vl-1-bit-xor* "mk_xb"      xb-expr      b-expr       b-expr))
       (xa-inst      (vl-simple-inst *vl-1-bit-xor* "mk_xa"      xa-expr      a-expr       a-expr))
       (xab-inst     (vl-simple-inst *vl-1-bit-xor* "mk_xab"     xab-expr     xa-expr      xb-expr))
       (out-inst     (vl-simple-inst *vl-1-bit-xor* "mk_out"     out-expr     xab-expr     main-expr)))

    (hons-copy
     (make-vl-module :name      name
                     :origname  name
                     :ports     (list out-port a-port b-port)
                     :portdecls (list out-portdecl a-portdecl b-portdecl)
                     :netdecls  (list out-netdecl a-netdecl b-netdecl
                                      bbar-netdecl mainbar-netdecl main-netdecl
                                      xa-netdecl xb-netdecl xab-netdecl)
                     :modinsts (list bbar-inst mainbar-inst main-inst
                                     xa-inst xb-inst xab-inst out-inst)
                     :minloc    *vl-fakeloc*
                     :maxloc    *vl-fakeloc*))))

#||
(vl-pps-module *vl-1-bit-signed-gte*)
||#

(def-vl-modgen vl-make-n-bit-signed-gte ((n posp))
  :short "Generate a signed greater-than or equal comparison module."

  :long "<p>We generate a gate-based module that is semantically equivalent
to:</p>

@({
module VL_N_BIT_SIGNED_GTE (out, a, b) ;
  output out;
  input signed [n-1:0] a;
  input signed [n-1:0] b;
  assign out = a >= b;
endmodule
})

<p>We just do the stupidest thing possible and do cases on the sign bit:</p>

<ul>

<li>A positive, B positive: unsigned comparison of @('a >= b')</li>

<li>A positive, B negative: 1 since positives @('>') negatives</li>

<li>A negative, B positive: 0 since negatives @('<') positives</li>

<li>A negative, B negative: unsigned comparison of @('a >= b')</li>

</ul>

<p>The middle two cases would ordinarily fool an unsigned comparison, e.g., if
A is positive and B is negative, then their leading bits are 0 and 1,
respectively, so B \"looks bigger\" even though A is actually bigger.  But
ordinary unsigned comparisons work in the other cases.</p>"

  :body
  (b* ((n (lposfix n))
       ((when (eql n 1))
        (list *vl-1-bit-signed-gte*))

       (name (hons-copy (cat "VL_" (natstr n) "_BIT_SIGNED_GTE")))

       ((mv out-expr out-port out-portdecl out-netdecl) (vl-primitive-mkport "out" :vl-output))
       ((mv a-expr a-port a-portdecl a-netdecl)         (vl-occform-mkport "a" :vl-input n))
       ((mv b-expr b-port b-portdecl b-netdecl)         (vl-occform-mkport "b" :vl-input n))

       ((mv sdiff-expr sdiff-netdecl) (vl-primitive-mkwire "signs_differ"))  ;; do signs differ?
       ((mv adiff-expr adiff-netdecl) (vl-primitive-mkwire "ans_differ"))    ;; answer when signs differ
       ((mv asame-expr asame-netdecl) (vl-primitive-mkwire "ans_same"))      ;; answer when signs are the same
       ((mv main-expr main-netdecl)   (vl-primitive-mkwire "main"))          ;; final answer except for x detection

       (a-msb  (vl-make-bitselect a-expr (- n 1)))
       (b-msb  (vl-make-bitselect b-expr (- n 1)))
       (a-tail (vl-make-partselect a-expr (- n 2) 0))
       (b-tail (vl-make-partselect b-expr (- n 2) 0))

       ;; xor(signs_differ, a[n-1], b[n-1]);
       (sdiff-inst (vl-simple-inst *vl-1-bit-xor* "mk_sdiff" sdiff-expr a-msb b-msb))

       ;; not(ans_differ, a[n-1]);    --- explanation:
       ;;
       ;;      a_msb     b_msb    answer
       ;;        0         1        a positive, b negative, answer is 1
       ;;        1         0        a negative, b positive, answer is 0
       (adiff-inst (vl-simple-inst *vl-1-bit-not* "mk_adiff" adiff-expr a-msb))

       ;; BOZO would be nice to have a GTE_CORE that doesn't do X detection.  Currently
       ;; this core will do its own X-detection unnecessarily.

       ;; VL_{N-1}_BIT_UNSIGNED_GTE core (ans_same, a[n-2:0], b[n-2:0]);
       ((cons ucmp-mod ucmp-support) (vl-make-n-bit-unsigned-gte (- n 1)))
       (ucmp-inst (vl-simple-inst ucmp-mod "core" asame-expr a-tail b-tail))

       ;; VL_1_BIT_MUX mux (main, signs_differ, ans_differ, ans_same);
       ((cons mux-mod mux-support) (vl-make-n-bit-mux 1 t))
       (mux-inst (vl-simple-inst mux-mod "mux" main-expr sdiff-expr adiff-expr asame-expr))

       ;; VL_N_BY_1_XPROP xprop (out, main, a, b);
       ((cons xprop-mod xprop-support) (vl-make-n-bit-x-propagator n 1))
       (xprop-inst (vl-simple-inst xprop-mod "xprop" out-expr main-expr a-expr b-expr)))

    (list* (make-vl-module :name      name
                           :origname  name
                           :ports     (list out-port a-port b-port)
                           :portdecls (list out-portdecl a-portdecl b-portdecl)
                           :netdecls  (list out-netdecl a-netdecl b-netdecl
                                            sdiff-netdecl adiff-netdecl asame-netdecl main-netdecl)
                           :modinsts  (list sdiff-inst adiff-inst ucmp-inst mux-inst xprop-inst)
                           :minloc    *vl-fakeloc*
                           :maxloc    *vl-fakeloc*)
           ucmp-mod
           mux-mod
           xprop-mod
           (append mux-support xprop-support ucmp-support))))

#||
(vl-pps-modulelist (vl-make-n-bit-signed-gte 10))
||#

