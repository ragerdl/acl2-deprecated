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
(include-book "../../primitives")
(include-book "../occform/util")
(include-book "../xf-delayredux")

(define vl-make-1-bit-latch-instances
  ((q-wires  vl-exprlist-p)
   (clk-wire vl-expr-p)
   (d-wires  vl-exprlist-p)
   &optional
   ((n "current index, for name generation, counts up" natp) '0))
  :guard (same-lengthp q-wires d-wires)
  :returns (insts vl-modinstlist-p)
  :parents (vl-make-n-bit-flop)
  :short "Build a list of @('VL_1_BIT_LATCH') instances."
  :long "<p>We produce a list of latch instances like:</p>

@({
   VL_1_BIT_LATCH bit_0 (q[0], clk, d[0]) ;
   VL_1_BIT_LATCH bit_1 (q[1], clk, d[1]) ;
   ...
   VL_1_BIT_LATCH bit_{n-1} (q[{n-1}], clk, d[{n-1}]) ;
})"
  (if (atom q-wires)
      nil
    (cons (vl-simple-inst *vl-1-bit-latch*
                          (hons-copy (cat "bit_" (natstr n)))
                          (car q-wires) clk-wire (car d-wires))
          (vl-make-1-bit-latch-instances (cdr q-wires) clk-wire (cdr d-wires)
                                         (+ n 1)))))


(def-vl-modgen vl-make-n-bit-latch (n)
  :parents (latchcode)
  :short "Generate an N-bit latch module."

  :long "<p>We generate a module that is written in terms of @(see primitives)
and is semantically equivalent to:</p>

@({
module VL_N_BIT_LATCH (q, clk, d);
  output q;
  input clk;
  input d;
  reg q;
  always @(d or clk)
    q <= clk ? d : q;
endmodule
})

<p>The actual definition uses a list of @(see *vl-1-bit-latch*) primitives,
e.g., for the four-bit case we would have:</p>

@({
module VL_4_BIT_LATCH (q, clk, d);
  output [3:0] q;
  input clk;
  input [3:0] d;

  VL_1_BIT_LATCH bit_0 (q[0], clk, d[0]);
  VL_1_BIT_LATCH bit_1 (q[1], clk, d[1]);
  VL_1_BIT_LATCH bit_2 (q[2], clk, d[2]);
  VL_1_BIT_LATCH bit_3 (q[3], clk, d[3]);
endmodule
})"

  :guard (posp n)

  :body
  (b* (((when (eql n 1))
        (list *vl-1-bit-latch*))

       (name        (hons-copy (cat "VL_" (natstr n) "_BIT_LATCH")))

       ((mv q-expr q-port q-portdecl q-netdecl)         (vl-occform-mkport "q" :vl-output n))
       ((mv clk-expr clk-port clk-portdecl clk-netdecl) (vl-occform-mkport "clk" :vl-input 1))
       ((mv d-expr d-port d-portdecl d-netdecl)         (vl-occform-mkport "d" :vl-input n))

       (q-wires     (vl-make-list-of-bitselects q-expr 0 (- n 1)))
       (d-wires     (vl-make-list-of-bitselects d-expr 0 (- n 1)))
       (modinsts    (vl-make-1-bit-latch-instances q-wires clk-expr d-wires 0)))
    (list (make-vl-module :name      name
                          :origname  name
                          :ports     (list q-port clk-port d-port)
                          :portdecls (list q-portdecl clk-portdecl d-portdecl)
                          :netdecls  (list q-netdecl clk-netdecl d-netdecl)
                          :modinsts  modinsts
                          :atts      (acons "VL_HANDS_OFF" nil nil) ; <-- may not be needed with the new sizing code
                          :minloc    *vl-fakeloc*
                          :maxloc    *vl-fakeloc*)
          *vl-1-bit-latch*)))

#||
(include-book ;; fool dependency scanner
 "../../mlib/writer")

(vl-pps-modulelist (vl-make-n-bit-latch 4))
||#



(def-vl-modgen vl-make-n-bit-latch-vec (n del)
  :parents (latchcode)
  :short "Generate an N-bit latch module for vector-oriented synthesis."

  :long "<p>We generate basically the following module:</p>

@({
module VL_n_BIT_d_TICK_LATCH (q, clk, d);
  output [n-1:0] q;
  input clk;
  input [n-1:0] d;
  wire [n-1:0] qdel;
  wire [n-1:0] qreg;

  // note: this should be a non-propagating delay,
  // since any change in qdel is only seen as a change in qreg
  // and is caused by a change in d or clk that has already propagated.
  VL_n_BIT_DELAY_1 qdelinst (qdel, qreg);
  VL_n_BIT_DELAY_d qoutinst (q, qreg);

  // should be a conservative mux
  assign qreg = clk ? d : qdel;

endmodule
})"

  :guard (and (posp n)
              (natp del))

  :body
  (b* ((n   (lposfix n))
       (del (lnfix del))

       (name (hons-copy (if (zp del)
                            (cat "VL_" (natstr n) "_BIT_LATCH")
                          (cat "VL_" (natstr n) "_BIT_" (natstr del) "_TICK_LATCH"))))

       ((mv q-expr q-port q-portdecl q-netdecl)         (vl-occform-mkport "q" :vl-output n))
       ((mv clk-expr clk-port clk-portdecl clk-netdecl) (vl-occform-mkport "clk" :vl-input 1))
       ((mv d-expr d-port d-portdecl d-netdecl)         (vl-occform-mkport "d" :vl-input n))

       ((mv qreg-expr qreg-decls qreg-insts qreg-addmods)
        (b* (((when (zp del))
              ;; no need to use an extra wire for qreg
              (mv q-expr nil nil nil))
             ((mv qreg-expr qreg-decl) (vl-occform-mkwire "qreg" n))
             (addmods (vl-make-n-bit-delay-m n del :vecp t))
             (delnd (car addmods))
             (qreg-inst (vl-simple-inst delnd "qoutinst" q-expr qreg-expr)))
          (mv qreg-expr (list qreg-decl) (list qreg-inst) addmods)))


       ;; non-propagating atts
       (triggers (make-vl-nonatom :op :vl-concat
                                  :args (list clk-expr d-expr)
                                  :finalwidth (+ 1 n)
                                  :finaltype :vl-unsigned))
       (atts (list (cons "VL_NON_PROP_TRIGGERS" triggers)
                   (cons "VL_NON_PROP_BOUND" qreg-expr)
                   (list "VL_STATE_DELAY")))
       ((mv qdel-expr qdel-decl)      (vl-occform-mkwire "qdel" n))
       (addmods (vl-make-n-bit-delay-1 n :vecp t))
       (deln1 (car addmods))
       (qdel-inst (change-vl-modinst
                   (vl-simple-inst deln1 "qdelinst" qdel-expr qreg-expr)
                   :atts atts))

       (qreg-assign (make-vl-assign
                     :lvalue qreg-expr
                     :expr (make-vl-nonatom
                            :op :vl-qmark
                            :args (list clk-expr
                                        d-expr
                                        qdel-expr)
                            :finalwidth n
                            :finaltype :vl-unsigned
                            ;; note that this should be a conservative
                            ;; if-then-else in order for the delay on q to be
                            ;; properly non-propagating
                            :atts (list (list "VL_LATCH_MUX")))
                     :loc *vl-fakeloc*)))
    (cons (make-vl-module :name      name
                          :origname  name
                          :ports     (list q-port clk-port d-port)
                          :portdecls (list q-portdecl clk-portdecl d-portdecl)
                          :netdecls  (list* q-netdecl clk-netdecl d-netdecl
                                            qdel-decl qreg-decls)
                          :assigns (list qreg-assign)
                          :modinsts  (cons qdel-inst qreg-insts)
                          :minloc    *vl-fakeloc*
                          :maxloc    *vl-fakeloc*)
          (append addmods qreg-addmods))))
