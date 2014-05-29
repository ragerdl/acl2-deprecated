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
(include-book "../../toe/toe-wirealist")
(include-book "../../mlib/stmt-tools")
(include-book "../../mlib/print-warnings")
(include-book "../xf-delayredux")
(include-book "centaur/4v-sexpr/sexpr-building" :dir :system)
(local (include-book "../../util/arithmetic"))

(defxdoc nedgeflop
  :parents (edgecode primitives)
  :short "Generation of new @(see primitives) for edge-triggered always
blocks."

  :long "<p>See @(see edgecode) for an overview of how we handle edge-triggered
always blocks.</p>

<p>To support these blocks, VL creates primitive flip-flop modules with some
number of edges.  For instance, the primitive 3-edge flop can be described as
follows in Verilog, and could be used to implement a flip-flop with, e.g.,
asynchronous set and reset signals.</p>

@({
    module VL_1_BIT_3_EDGE_FLOP (q, d0, d1, d2, clk0, clk1, clk2);
      output reg q;
      input d0, d1, d2;
      input clk0, clk1, clk2;
      always @(posedge clk0 or posedge clk1)
        if (clk0)
           q <= d0
        else if (clk1)
           q <= d1;
        else
           q <= d2;
    endmodule
})

<p>The functions below generate these primitive modules and their corresponding
@(see esim) implementations.</p>")

(local (xdoc::set-default-parents nedgeflop))


(define vl-primitive-mkports
  ((prefix stringp "name prefix for each port")
   (i      natp    "starting index, <b>inclusive!</b>")
   (n      natp    "ending index, <b>non-inclusive!</b>")
   &key
   (dir    vl-direction-p "direction of each port")
   ((loc vl-location-p)   '*vl-fakeloc*))
  :guard   (<= i n)
  :returns (mv (exprs     vl-exprlist-p :hyp :fguard)
               (ports     vl-portlist-p :hyp :fguard)
               (portdecls vl-portdecllist-p :hyp :fguard)
               (netdecls  vl-netdecllist-p :hyp :fguard))
  :short "Helper function for creating lists of primitive port declarations."
  :measure (nfix (- (nfix n) (nfix i)))
  (b* (((when (mbe :logic (zp (- (lnfix n) (lnfix i)))
                   :exec (eql i n)))
        (mv nil nil nil nil))
       (name1 (hons-copy (cat prefix (natstr i))))
       ((mv expr1 port1 portdecl1 netdecl1)
        (vl-primitive-mkport name1 dir))
       ((mv exprs2 ports2 portdecls2 netdecls2)
        (vl-primitive-mkports prefix (+ 1 (lnfix i)) n
                              :dir dir :loc loc)))
    (mv (cons expr1 exprs2)
        (cons port1 ports2)
        (cons portdecl1 portdecls2)
        (cons netdecl1 netdecls2)))
  ///
  (defmvtypes vl-primitive-mkports-fn
    (true-listp true-listp true-listp true-listp))

  (defthm len-of-vl-primitive-mkports
    (b* (((mv exprs ports portdecls netdecls)
          (vl-primitive-mkports prefix i n
                                :dir dir
                                :loc loc))
         (len (nfix (- (nfix n) (nfix i)))))
      (and (equal (len exprs) len)
           (equal (len ports) len)
           (equal (len portdecls) len)
           (equal (len netdecls) len))))

  (defthm vl-primitive-mkports-under-iff
    (b* (((mv exprs ports portdecls netdecls)
          (vl-primitive-mkports prefix i n
                                :dir dir
                                :loc loc))
         (len (- (nfix n) (nfix i))))
      (and (iff exprs     (posp len))
           (iff ports     (posp len))
           (iff portdecls (posp len))
           (iff netdecls  (posp len))))))

(define vl-nedgeflop-posedge-clks
  :short "Build the Verilog sensitivity list for a primitive n-edge flop."
  ((clk-exprs vl-exprlist-p "e.g., @('(clk0 clk1 clk2)')"))
  :returns (evatoms vl-evatomlist-p :hyp :fguard
                    "e.g., @('posedge clk0 or posedge clk1 or posedge clk2')")
  (if (atom clk-exprs)
      nil
    (cons (make-vl-evatom :type :vl-posedge
                          :expr (car clk-exprs))
          (vl-nedgeflop-posedge-clks (cdr clk-exprs)))))

(define vl-nedgeflop-ifstmt
  :short "Build the Verilog if-statement for a primitive n-edge flop."
  ((q-expr     vl-expr-p     "e.g., @('q')")
   (clk-exprs  vl-exprlist-p "e.g., @('(clk0 clk1 clk2)')")
   (data-exprs vl-exprlist-p "e.g., @('(d0   d1   d2)')"))
  :returns (guts vl-stmt-p :hyp :fguard "e.g., @('if (clk0)
                                                     q <= d0;
                                                  else if (clk1)
                                                     q <= d1;
                                                  else
                                                     q <= d2;')")
  :guard (and (consp clk-exprs)
              (same-lengthp clk-exprs data-exprs))
  (b* (((when (atom clk-exprs))
        (impossible) ;; Guard requires consp.
        (make-vl-nullstmt))
       (assign1 (make-vl-assignstmt :type   :vl-nonblocking
                                    :lvalue q-expr
                                    :expr   (car data-exprs)
                                    :loc    *vl-fakeloc*))
       ((when (atom (cdr clk-exprs)))
        ;; Last clock.  No IF statement, just the unconditional assignment
        ;; of the last data value.
        assign1))
    (make-vl-ifstmt :condition   (car clk-exprs)
                    :truebranch  assign1
                    :falsebranch (vl-nedgeflop-ifstmt q-expr
                                                      (cdr clk-exprs)
                                                      (cdr data-exprs)))))

(define vl-nedgeflop-always
  :short "Build the Verilog @('always') statement for a primitive n-edge flop."
  ((q-expr     vl-expr-p     "e.g., @('q')")
   (clk-exprs  vl-exprlist-p "e.g., @('(clk0 clk1 clk2)')")
   (data-exprs vl-exprlist-p "e.g., @('(d0   d1   d2)')"))
  :guard (and (consp clk-exprs)
              (same-lengthp clk-exprs data-exprs))
  :returns (always vl-always-p :hyp :fguard)
  (b* ((evatoms (vl-nedgeflop-posedge-clks clk-exprs))
       (evctrl  (make-vl-eventcontrol :starp nil
                                      :atoms evatoms))
       (body    (vl-nedgeflop-ifstmt q-expr clk-exprs data-exprs))
       (stmt    (make-vl-timingstmt :ctrl evctrl
                                    :body body)))
    (make-vl-always :stmt stmt
                    :loc *vl-fakeloc*)))

(define vl-nedgeflop-some-edge-sexpr
  :short "Build a 4v-sexpr that captures when any clock has just had a posedge."
  ((clks      "E wire names for current clock values.")
   (clk-prevs "E wire names for previous clock values."))
  :guard (and (consp clks)
              (same-lengthp clks clk-prevs))
  :returns 4v-sexpr
  :long "<p>The idea here is to build an expression like:</p>
@({
       (or (and clk1 (not clk1-prev))  ;; first clk had a posedge
           (and clk2 (not clk2-prev))  ;; second clk had a posedge
           ...)
})

<p>This is the expression that will trigger an update of the flop.</p>"
  :measure (+ 1 (len clks))
  (b* (((cons clk1      rest-clks)      clks)
       ((cons clk1-prev rest-clk-prevs) clk-prevs)
       (edge1
        ;; The first clock has an edge exactly when its previous value was F
        ;; and its new value is T.  This sexpr captures that:
        (acl2::4vs-and clk1 (acl2::4vs-not clk1-prev)))
       ((when (atom rest-clks))
        edge1))
    (acl2::4vs-or edge1
                  (vl-nedgeflop-some-edge-sexpr rest-clks rest-clk-prevs))))

(define vl-nedgeflop-update-sexpr
  :short "Build a 4v-sexpr with the update function upon a posedge."
  ((clks      "E wire names for the current clock values.")
   (dat-prevs "E wires names for the previous data values."))
  :returns 4v-sexpr
  :long "<p>We're dealing here with an always block such as:</p>

@({
    always @(posedge clk0 or posedge clk1 or posedge clk2)
      if (clk0)
         q <= d0;
      else if (clk1)
         q <= d1;
      else
         q <= d2;
})

<p>We're going to build the sexpr to assign to @('q') when a posedge has
occurred.  The goal, then, is to build an expression that is, e.g., in this
example:</p>

@({
     (if clk0
         data-prev0
       (if clk1
           data-prev1
         data-prev2))
})"

  :guard (and (consp clks)
              (same-lengthp clks dat-prevs))
  :measure (+ 1 (len clks))

  (b* (((cons clk1      rest-clks)      clks)
       ((cons dat-prev1 rest-dat-prevs) dat-prevs)
       ((when (atom rest-clks))
        dat-prev1))
    (acl2::4vs-ite*-dumb clk1
                         dat-prev1
                         (vl-nedgeflop-update-sexpr rest-clks rest-dat-prevs))))

(define vl-nedgeflop-e-wires ((exprs  vl-exprlist-p)
                              (walist vl-wirealist-p))
  :returns (wires true-listp :rule-classes :type-prescription)
  (b* (((mv okp warnings wires)
        (vl-msb-exprlist-bitlist exprs walist nil))
       ((unless (and okp
                     (not warnings)
                     (same-lengthp exprs wires)))
        (raise "Expected exactly ~x0 wires for N-edge 1-bit flop."
               (len exprs))
        ;; Stupid hack for unconditional length theorem
        (replicate (len exprs) 'error)))
    wires)
  ///
  (defthm len-of-vl-nedgeflop-e-wires
    (equal (len (vl-nedgeflop-e-wires exprs walist)) (len exprs)))
  (defthm consp-of-vl-nedgeflop-e-wires
    (equal (consp (vl-nedgeflop-e-wires exprs walist)) (consp exprs)))
  (defthm vl-nedgeflop-e-wires-under-iff
    (iff (vl-nedgeflop-e-wires exprs walist) (consp exprs))))

(define vl-make-1-bit-n-edge-flop ((n posp))
  :short "Build the primitive VL module for an n-edge flop."
  :returns (flop vl-module-p :hyp :fguard)
  (b* ((name (cat "VL_1_BIT_" (natstr n) "_EDGE_FLOP"))

       ;; output q;
       ((mv q-expr q-port q-portdecl ?q-netdecl)
        (vl-primitive-mkport "q" :vl-output))

       ;; reg q;
       (q-regdecl (make-vl-regdecl :name "q" :loc *vl-fakeloc*))

       ;; input d0, d1, ..., d{n-1};
       ((mv d-exprs d-ports d-portdecls d-netdecls)
        (vl-primitive-mkports "d" 0 n :dir :vl-input))

       ;; input clk0, clk1, ..., clk{n-1};
       ((mv clk-exprs clk-ports clk-portdecls clk-netdecls)
        (vl-primitive-mkports "clk" 0 n :dir :vl-input))
       ;; always @(posedge clk0 or posedge clk1 or ...)
       ;;   if (clk0) q <= d0;
       ;;   else if (clk1) q <= d1;
       ;;   ...
       (always (vl-nedgeflop-always q-expr clk-exprs d-exprs))

       (temp-mod (make-vl-module
                  :name      name
                  :origname  name
                  :ports     (cons q-port (append d-ports clk-ports))
                  :portdecls (cons q-portdecl (append d-portdecls clk-portdecls))
                  :netdecls  (append d-netdecls clk-netdecls)
                  :regdecls  (list q-regdecl)
                  :alwayses  (list always)
                  :minloc    *vl-fakeloc*
                  :maxloc    *vl-fakeloc*
                  :atts      (list (cons (hons-copy "VL_HANDS_OFF") nil))))

       ;; Now generate the ESIM to install.

       ((mv okp warnings walist) (vl-module-wirealist temp-mod nil))
       ((unless (and okp (not warnings)))
        (raise "Error creating wire alist? ~s0" (vl-warnings-to-string warnings))
        temp-mod)

       (q-wire    (car (vl-nedgeflop-e-wires (list q-expr) walist)))
       (d-wires   (vl-nedgeflop-e-wires d-exprs walist))
       (clk-wires (vl-nedgeflop-e-wires clk-exprs walist))

       (q-prev    (car (vl-emodwires-from-msb-to-lsb "q_prev" 0 0)))
       (d-prevs   (vl-emodwires-from-msb-to-lsb "d_prev" (- n 1) 0))
       (clk-prevs (vl-emodwires-from-msb-to-lsb "clk_prev" (- n 1) 0))

       ;; Next states.  Every previous clock/data gets the new clock/data.
       (next-q-sexpr   (acl2::4vs-ite*-dumb
                        ;; if we just saw some posedge
                        (vl-nedgeflop-some-edge-sexpr clk-wires clk-prevs)
                        ;; update the register with its update expr
                        (vl-nedgeflop-update-sexpr clk-wires d-prevs)
                        ;; else just hold your value
                        q-prev))
       (nst-alist      (cons (cons q-prev next-q-sexpr)        ;; q <= next-q
                        (append (pairlis$ clk-prevs clk-wires) ;; clkprev_i <= clki
                                (pairlis$ d-prevs d-wires))))  ;; datprev_i <= dati
       (out-alist      (list (cons q-wire next-q-sexpr)))
       (esim (list :n (vl-starname name)
                   :o (list (list q-wire))
                   :i (append (pairlis$ d-wires nil)
                              (pairlis$ clk-wires nil))
                   :x (list :out out-alist
                            :nst nst-alist)
                   ;; Annotations which might be useful for STVs or similar.
                   :a (list (cons "VL_N_EDGE_FLOP"    t)
                            (cons "VL_FLOP_NUM_EDGES" n)
                            (cons "VL_FLOP_CLK_WIRES" clk-wires)
                            (cons "VL_FLOP_CLK_PREVS" clk-prevs)
                            (cons "VL_FLOP_D_WIRES"   d-wires)
                            (cons "VL_FLOP_D_PREVS"   d-prevs)
                            (cons "VL_FLOP_Q_WIRE"    q-wire)
                            (cons "VL_FLOP_Q_PREV"    q-prev)))))
    (change-vl-module temp-mod :esim esim)))



#||

(vl-make-1-bit-n-edge-flop 1)
(vl-make-1-bit-n-edge-flop 2)
(vl-make-1-bit-n-edge-flop 3)

(vl-pps-module (vl-make-1-bit-n-edge-flop 1))
(vl-pps-module (vl-make-1-bit-n-edge-flop 2))
(vl-pps-module (vl-make-1-bit-n-edge-flop 3))
(vl-pps-module (vl-make-1-bit-n-edge-flop 4))

(include-book
 "centaur/esim/esim-sexpr-support" :dir :system)

(assert!
 (and
  (acl2::good-esim-modulep (vl-module->esim (vl-make-1-bit-n-edge-flop 1)))
  (acl2::good-esim-modulep (vl-module->esim (vl-make-1-bit-n-edge-flop 2)))
  (acl2::good-esim-modulep (vl-module->esim (vl-make-1-bit-n-edge-flop 3)))))

||#

(defprojection vl-make-same-bitselect-from-each (x index)
  (vl-make-bitselect x index)
  :guard (and (vl-exprlist-p x)
              (natp index))
  ///
  (defthm vl-exprlist-p-of-vl-make-same-bitselect-from-each
    (implies (force (vl-exprlist-p x))
             (vl-exprlist-p (vl-make-same-bitselect-from-each x index))))
  (defthm vl-exprlist->finalwidths-of-vl-make-same-bitselect-from-each
    (equal (vl-exprlist->finalwidths (vl-make-same-bitselect-from-each x index))
           (replicate (len x) 1)))
  (defthm vl-exprlist->finaltypes-of-vl-make-same-bitselect-from-each
    (equal (vl-exprlist->finaltypes (vl-make-same-bitselect-from-each x index))
           (replicate (len x) :vl-unsigned))))

(define vl-make-nedgeflop-insts ((primitive vl-module-p)
                                 (q-expr    vl-expr-p)
                                 (d-exprs   vl-exprlist-p)
                                 (clk-exprs vl-exprlist-p)
                                 (n         natp "Initially width."))
  :returns (insts vl-modinstlist-p :hyp :fguard)
  :guard (same-lengthp d-exprs clk-exprs)
  (b* (((when (zp n))
        nil)
       (n (- n 1))
       (q-bit  (vl-make-bitselect q-expr n))
       (d-bits (vl-make-same-bitselect-from-each d-exprs n))
       (args   (cons q-bit (append d-bits clk-exprs))))
    (cons (vl-simple-instantiate primitive
                                 (hons-copy (cat "bit" (str::natstr n)))
                                 args)
          (vl-make-nedgeflop-insts primitive q-expr d-exprs clk-exprs n))))

(def-vl-modgen vl-make-nedgeflop (width nedges)
  :short "Generate an N-bit register with K edges."
  :guard (and (posp width)
              (posp nedges))
  :body
  (b* (((when (eql width 1))
        (list (vl-make-1-bit-n-edge-flop nedges)))

       (name (cat "VL_" (natstr width) "_BIT_" (natstr nedges) "_EDGE_FLOP"))

       ;; output [width-1:0] q;
       ((mv q-expr q-port q-portdecl ?q-netdecl)
        (vl-occform-mkport "q" :vl-output width))

       ;; Note: no reg declaration for q, because the actual regs will live in
       ;; the submodule instances.

       ;; input [width-1:0] d0, d1, ..., d{n-1};
       ((mv d-exprs d-ports d-portdecls d-netdecls)
        (vl-occform-mkports "d" 0 nedges :dir :vl-input :width width))

       ;; input clk0, clk1, ..., clk{n-1};
       ((mv clk-exprs clk-ports clk-portdecls clk-netdecls)
        (vl-occform-mkports "clk" 0 nedges :dir :vl-input :width 1))

       (primitive (vl-make-1-bit-n-edge-flop nedges))
       (modinsts  (vl-make-nedgeflop-insts primitive q-expr d-exprs clk-exprs width)))

    (list (make-vl-module
           :name      name
           :origname  name
           :ports     (cons q-port (append d-ports clk-ports))
           :portdecls (cons q-portdecl (append d-portdecls clk-portdecls))
           :netdecls  (cons q-netdecl (append d-netdecls clk-netdecls))
           :modinsts  modinsts
           :minloc    *vl-fakeloc*
           :maxloc    *vl-fakeloc*)
          primitive)))




#||

(vl-pps-modulelist (vl-make-nedgeflop 3 1))
(vl-pps-modulelist (vl-make-nedgeflop 3 2))
(vl-pps-modulelist (vl-make-nedgeflop 3 3))

(vl-pps-module (vl-make-1-bit-n-edge-flop 2))
(vl-pps-module (vl-make-1-bit-n-edge-flop 3))
(vl-pps-module (vl-make-1-bit-n-edge-flop 4))

(vl-pps-modulelist (vl-make-nedgeflop 1 1))
(vl-pps-modulelist (vl-make-nedgeflop 2 1))
(vl-pps-modulelist (vl-make-nedgeflop 3 1))

(vl-pps-modulelist (vl-make-nedgeflop 1 2))
(vl-pps-modulelist (vl-make-nedgeflop 1 3))

||#


#||

module vl_4_bit_3_edge_2_tick_flop (q, d0, d1, d2, clk0, clk1, clk2) ;

output [3:0] q;
input [3:0] d0;
input [3:0] d1;
input [3:0] d2;
input clk0;
input clk1;
input clk2;

wire clk0del;
wire clk1del;
wire clk2del;
wire clk0edge;
wire clk1edge;
wire clk2edge;
wire anyedge;
wire [3:0] d0del;
wire [3:0] d1del;
wire [3:0] d2del;
wire [3:0] qdel;
wire [3:0] qreg;
wire [3:0] dfull;

// note maybe mark these as non-propagating delays:
// everything that depends on these depends on qreg
// q only updates when one of the clocks toggles
vl_1_bit_delay1 clk0delinst (clk0del, clk0);
vl_1_bit_delay1 clk1delinst (clk1del, clk1);
vl_1_bit_delay1 clk2delinst (clk2del, clk2);
vl_4_bit_delay1 d0delinst (d0del, d0);
vl_4_bit_delay1 d1delinst (d1del, d1);
vl_4_bit_delay1 d2delinst (d2del, d2);
vl_4_bit_delay1 qdelinst (qdel, qreg);

// this one is a propagating delay
vl_4_bit_delay2 qoutinst (q, qreg);


assign clk0edge = clk0 & ~clk0del;
assign clk1edge = clk1 & ~clk1del;
assign clk2edge = clk2 & ~clk2del;
assign anyedge = clk0edge | clk1edge | clk2edge;

assign dfull = clk0 ? d0del :
               clk1 ? d1del :
                      d2del;

// note for the delays to be strictly non-propagating this
// must be a conservative mux, otherwise when clks are X
// a change in d might cause a change in q
assign qreg = anyedge ? dfull : qdel;

endmodule


||#

(define vl-modinsts-add-atts ((x vl-modinstlist-p) (atts vl-atts-p))
  :returns (xx vl-modinstlist-p :hyp :guard)
  (if (atom x)
      nil
    (cons (change-vl-modinst (car x) :atts (append atts (vl-modinst->atts (car x))))
          (vl-modinsts-add-atts (cdr x) atts))))

(define vl-nedgeflop-clkedge-assigns ((edges vl-exprlist-p)
                                      (clks vl-exprlist-p)
                                      (dels vl-exprlist-p))
  :guard (and (eql (len edges) (len clks))
              (eql (len edges) (len dels)))
  :guard-hints (("goal" :do-not-induct t))
  :returns (assigns vl-assignlist-p :hyp :guard)
  (if (atom edges)
      nil
    (cons (make-vl-assign :lvalue (car edges)
                          :expr (make-vl-nonatom
                                 :op :vl-binary-bitand
                                 :args (list (car clks)
                                             (make-vl-nonatom
                                              :op :vl-unary-bitnot
                                              :args (list (car dels))
                                              :finalwidth 1
                                              :finaltype :vl-unsigned))
                                 :finalwidth 1
                                 :finaltype :vl-unsigned)
                          :loc *vl-fakeloc*)
          (vl-nedgeflop-clkedge-assigns (cdr edges) (cdr clks) (cdr dels)))))

(define vl-nedgeflop-data-mux ((clks vl-exprlist-p)
                               (ds vl-exprlist-p)
                               (width posp))
  :guard (and (consp clks)
              (eql (len clks) (len ds)))
  :returns (x vl-expr-p :hyp :guard)
  (if (atom (cdr clks))
      (car ds)
    (make-vl-nonatom
     :op :vl-qmark
     :args (list (car clks)
                 (car ds)
                 (vl-nedgeflop-data-mux (cdr clks) (cdr ds) width))
     :finalwidth width
     :finaltype :vl-unsigned)))
                          
(define vl-nedgeflop-or-edges ((edges vl-exprlist-p))
  :Guard (consp edges)
  :returns (x vl-expr-p :hyp :guard)
  (if (atom (cdr edges))
      (car edges)
    (make-vl-nonatom
     :op :vl-binary-bitor
     :args (list (car edges)
                 (vl-nedgeflop-or-edges (cdr edges)))
     :finalwidth 1
     :finaltype :vl-unsigned)))

(local (defthm car-of-vl-modulelist-p
         (implies (and (vl-modulelist-p x)
                       (consp x))
                  (Car x))))

(def-vl-modgen vl-make-nedgeflop-vec (width nedges delay)
  :short "Generate a w-bit wide, n-edge flop with output delay d"
  :guard (and (posp width) (posp nedges) (natp delay))
  :body
  (b* ((name (if (zp delay)
                 (cat "VL_" (natstr width) "_BIT_" (natstr nedges) "_EDGE_FLOP")
               (cat "VL_" (natstr width) "_BIT_" (natstr nedges) "_EDGE_" (natstr delay) "_TICK_FLOP")))

       ((mv qexpr qport qportdecl qnetdecl) (vl-occform-mkport "q" :vl-output width))
       ((mv dexprs dports dportdecls dnetdecls) (vl-occform-mkports "d" 0 nedges :dir :vl-input :width width))
       ((mv clkexprs clkports clkportdecls clknetdecls) (vl-occform-mkports "clk" 0 nedges :dir :vl-input :width 1))
       
       
       ;; note qregdecls are netdecls not regdecls
       ((mv qregexpr qregdecls qreginsts qregmods)
        ;; this represents the final delay of q, which we don't need if
        ;; delay=0.  in that case rather than creating a new redundant wire we
        ;; just use q itself in the place of qreg above.
        (b* (((when (zp delay))
              (mv qexpr nil nil nil))
             ((mv qregexpr qregdecl)
              (vl-occform-mkwire "qreg" width))
             (ddelnds (vl-make-n-bit-delay-m width delay :vecp t))
             (ddelnd (Car ddelnds))
             (qoutinst (vl-simple-inst ddelnd "qoutinst" qexpr qregexpr)))
          (mv qregexpr (list qregdecl) (list qoutinst) ddelnds)))

       ;; non-propagating atts
       (clkconcat (make-vl-nonatom
                   :op :vl-concat
                   :args clkexprs
                   :finalwidth nedges
                   :finaltype :vl-unsigned))
       (atts (list (cons "VL_NON_PROP_TRIGGERS" clkconcat)
                   (cons "VL_NON_PROP_BOUND" qregexpr)
                   (list "VL_STATE_DELAY")))

       ((mv clkdelexprs clkdeldecls) (vl-occform-mkwires "clkdel" 0 nedges :width 1))
       (del11 *vl-1-bit-delay-1*)
       (clkdelinsts (vl-modinsts-add-atts
                     (vl-simple-inst-list del11 "clkdelinst" clkdelexprs clkexprs)
                     atts))

       ((mv ddelexprs ddeldecls) (vl-occform-mkwires "ddel" 0 nedges :width 1))
       (delw1s (vl-make-n-bit-delay-1 width :vecp t))
       (delw1 (car delw1s))
       (ddelinsts (vl-modinsts-add-atts
                   (vl-simple-inst-list delw1 "ddelinst" ddelexprs dexprs)
                   atts))

       ((mv qdelexpr qdeldecl) (vl-occform-mkwire "qdel" width))
       (qdelinst (change-vl-modinst
                  (vl-simple-inst delw1 "qdelinst" qdelexpr qregexpr)
                  :atts atts))

       ((mv clkedgeexprs clkedgedecls) (vl-occform-mkwires "clkedge" 0 nedges :width 1))
       (clkedge-assigns (vl-nedgeflop-clkedge-assigns clkedgeexprs clkexprs clkdelexprs))
       (anyedge-rhs (vl-nedgeflop-or-edges clkedgeexprs))
       ((mv anyedgeexpr anyedgedecl) (vl-occform-mkwire "anyedge" 1))
       (anyedge-assign (make-vl-assign :lvalue anyedgeexpr :expr anyedge-rhs :loc *vl-fakeloc*))
       ((mv dfullexpr dfulldecl) (vl-occform-mkwire "dfull" width))
       (dfull-rhs (vl-nedgeflop-data-mux clkexprs ddelexprs width))
       (dfull-assign (make-vl-assign :lvalue dfullexpr :expr dfull-rhs :loc *vl-fakeloc*))

       (qassign (make-vl-assign
                 :lvalue qregexpr
                 :expr (make-vl-nonatom
                        :op :vl-qmark
                        :args (list anyedgeexpr
                                    dfullexpr
                                    qdelexpr)
                        :finalwidth width
                        :finaltype :vl-unsigned
                        ;; note that this should be a conservative if-then-else
                        ;; in order for the delays to be properly non-propagating
                        :atts (list (list "VL_LATCH_MUX")))
                 :loc *vl-fakeloc*))

       (mod (make-vl-module :name name
                            :origname name
                            :ports (cons qport (append dports clkports))
                            :portdecls (cons qportdecl (append dportdecls clkportdecls))
                            :netdecls `(,qnetdecl
                                        ,@dnetdecls
                                        ,@clknetdecls
                                        ,@clkdeldecls
                                        ,@ddeldecls
                                        ,@qregdecls
                                        ,qdeldecl
                                        ,@clkedgedecls
                                        ,anyedgedecl
                                        ,dfulldecl)
                            :assigns `(,@clkedge-assigns
                                       ,anyedge-assign
                                       ,dfull-assign
                                       ,qassign)
                            :modinsts `(,@clkdelinsts
                                        ,@ddelinsts
                                        ,@qreginsts
                                        ,qdelinst)
                            :minloc *vl-fakeloc*
                            :maxloc *vl-fakeloc*)))
    (list* mod del11 (append delw1s qregmods))))
       

#||

(include-book
 "../../mlib/writer")
(vl-pps-modulelist (vl-make-nedgeflop-vec 4 3 2))

||#
