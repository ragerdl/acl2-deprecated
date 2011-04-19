; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
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
(include-book "gen-shl")
(local (include-book "../../util/arithmetic"))
(local (include-book "../../util/osets"))
(local (in-theory (disable vl-maybe-module-p-when-vl-module-p)))

; gen-shr.lisp -- functions that generate right-shift modules
; basically identical to gen-shl.lisp, reuses some stuff from there.


(local (defthm car-of-vl-make-list-of-bitselects-under-iff
         (implies (force (vl-expr-p expr))
                  (iff (car (vl-make-list-of-bitselects expr low high))
                       t))
         :hints(("Goal" :in-theory (enable vl-make-list-of-bitselects)))))

(local (defthm vl-maybe-expr-p-of-car-when-vl-exprlist-p
         (implies (vl-exprlist-p x)
                  (vl-maybe-expr-p (car x)))))

(local (defthm len-of-cdr
         (implies (consp x)
                  (equal (len (cdr x))
                         (1- (len x))))))


; Basic idea: a >> b is the same as
;
;   temp0 =     a >> (b[0] * 2^0)          "place 0"
;   temp1 = temp0 >> (b[1] * 2^1)          "place 1"
;   temp2 = temp1 >> (b[2] * 2^2)          "place 2"
;   ...

(def-vl-modgen vl-make-n-bit-shr-place-p (n p)
  :short "Generate a module that conditionally shifts an <tt>N</tt> bit
number by <tt>2**(P-1)</tt> bits to the right."

  :long "<p>We generate a gate-based module that is semantically equivalent
to:</p>

<code>
module VL_N_BIT_SHR_PLACE_P (out, in, shiftp) ;
  output [n-1:0] out;
  input [n-1:0] in;
  input shiftp;

  assign out = shiftp ? (in &gt;&gt; 2**(p-1)) : in;

endmodule
</code>

<p>These \"place shifters\" can be combined to form a full shifter that
operates on O(log_2 n) muxes.</p>"

  :guard (and (posp n) (posp p))

  :body
  (b* ((shift-amount (expt 2 (- p 1)))
       (name  (hons-copy (str::cat "VL_" (str::natstr n) "_BIT_SHR_PLACE_" (str::natstr p))))

       ((mv out-expr out-port out-portdecl out-netdecl)             (vl-occform-mkport "out" :vl-output n))
       ((mv in-expr in-port in-portdecl in-netdecl)                 (vl-occform-mkport "in" :vl-input n))
       ((mv shiftp-expr shiftp-port shiftp-portdecl shiftp-netdecl) (vl-occform-mkport "shiftp" :vl-input 1))

       ;; we can only shift as many places as there are bits in n
       (places      (min n shift-amount))
       (|places'b0| (make-vl-atom :guts (make-vl-constint :value 0
                                                          :origwidth places
                                                          :origtype :vl-unsigned)
                                  :finalwidth places :finaltype :vl-unsigned))

       (shifted-expr
        (if (<= n shift-amount)
            |places'b0|
          ;; {places'b0, in[N-1:places]}
          (make-vl-nonatom :op :vl-concat
                           :args (list |places'b0|
                                       (vl-make-partselect in-expr (- n 1) places))
                           :finalwidth n
                           :finaltype :vl-unsigned)))

       ;; VL_N_BIT_APPROX_MUX mux(out, shiftp, shifted-expr, in);
       ((cons mux-mod mux-support) (vl-make-n-bit-mux n t))
       (mux-args (list (make-vl-plainarg :expr out-expr     :dir :vl-output :portname (hons-copy "out"))
                       (make-vl-plainarg :expr shiftp-expr  :dir :vl-input  :portname (hons-copy "sel"))
                       (make-vl-plainarg :expr shifted-expr :dir :vl-input  :portname (hons-copy "a"))
                       (make-vl-plainarg :expr in-expr      :dir :vl-input  :portname (hons-copy "b"))))
       (mux-inst (make-vl-modinst :modname   (vl-module->name mux-mod)
                                  :instname  (hons-copy "mux")
                                  :paramargs (vl-arguments nil nil)
                                  :portargs  (vl-arguments nil mux-args)
                                  :loc       *vl-fakeloc*)))

    (list* (make-vl-module :name      name
                           :origname  name
                           :ports     (list out-port in-port shiftp-port)
                           :portdecls (list out-portdecl in-portdecl shiftp-portdecl)
                           :netdecls  (list out-netdecl in-netdecl shiftp-netdecl)
                           :modinsts  (list mux-inst)
                           :minloc    *vl-fakeloc*
                           :maxloc    *vl-fakeloc*)
           mux-mod
           mux-support)))



(defsection vl-make-n-bit-shr-place-ps
  :parents (occform)
  :short "Generate a list of place-shifters, counting down from P to 1."

  (defund vl-make-n-bit-shr-place-ps (n p)
    "Returns (MV SHIFT-MODS SUPPORT-MODS)"
    (declare (xargs :guard (and (posp n)
                                (natp p))))
    (b* (((when (zp p))
          (mv nil nil))
         ((cons car-shifter car-support) (vl-make-n-bit-shr-place-p n p))
         ((mv cdr-shifters cdr-support) (vl-make-n-bit-shr-place-ps n (- p 1))))
      (mv (cons car-shifter cdr-shifters)
          (append car-support cdr-support))))

  (local (in-theory (enable vl-make-n-bit-shr-place-ps)))

  (defthm vl-modulelist-p-of-vl-make-n-bit-shr-place-ps
    (implies (and (force (posp n))
                  (force (natp p)))
             (let ((ret (vl-make-n-bit-shr-place-ps n p)))
               (and (vl-modulelist-p (mv-nth 0 ret))
                    (vl-modulelist-p (mv-nth 1 ret))))))

  (defthm len-of-vl-make-n-bit-shr-place-ps-0
    (equal (len (mv-nth 0 (vl-make-n-bit-shr-place-ps n p)))
           (nfix p)))

  (defthm type-of-vl-make-n-bit-shr-place-ps-0
    (true-listp (mv-nth 0 (vl-make-n-bit-shr-place-ps n p)))
    :rule-classes :type-prescription)

  (defthm type-of-vl-make-n-bit-shr-place-ps-1
    (true-listp (mv-nth 1 (vl-make-n-bit-shr-place-ps n p)))
    :rule-classes :type-prescription))



(def-vl-modgen vl-make-n-bit-shr-by-m-bits (n m)
  :short "Generate a module that shifts an <tt>N</tt> bit number right by an
<tt>M</tt> bit number."

  :long "<p>We generate a gate-based module that is semantically equivalent
to:</p>

<code>
module VL_N_BIT_SHR_BY_M_BITS (out, a, b) ;
  output [n-1:0] out;
  input [n-1:0] a;
  input [m-1:0] b;
  assign out = a &gt;&gt; b;
endmodule
</code>"

  :guard (and (posp n)
              (posp m))

  :body
  (b* ((name (hons-copy (str::cat "VL_" (str::natstr n) "_BIT_SHR_BY_" (str::natstr m) "_BITS")))

       ((mv out-expr out-port out-portdecl out-netdecl) (vl-occform-mkport "out" :vl-output n))
       ((mv a-expr a-port a-portdecl a-netdecl)         (vl-occform-mkport "a" :vl-input n))
       ((mv b-expr b-port b-portdecl b-netdecl)         (vl-occform-mkport "b" :vl-input m))

       ;; We'll have K place-shifters, one that shifts by 2**0, one by 2**1, etc.
       ;; The actual number of shifters is constrained in two ways.
       ;;
       ;;  - We don't need more than 1+log2(n) shifters because A only has N
       ;;    bits so shifting by more than 2**{1+log2(n)} just zeroes out A.
       ;;
       ;;  - We don't need more than M shifters because there are only M bits
       ;;    of B, so there are only M places to consider shifting.
       ;;
       ;; The basic idea is to set:
       ;;
       ;;  wire [n-1:0] temp1 =          a >> (b[0] * 2^0);
       ;;  wire [n-1:0] temp2 =     temp_1 >> (b[1] * 2^1)
       ;;    ...
       ;;  wire [n-1:0] tempK = temp_{k-1} >> (b[k-1] * 2^{k-1})

       (k (min (+ (integer-length n) 1) m))

       ((mv pshift-mods pshift-support) (vl-make-n-bit-shr-place-ps n k))
       (pshift-mods (reverse pshift-mods)) ;; for place_1 ... place_k order

       (temp-netdecls (reverse (vl-make-list-of-netdecls k "temp" (vl-make-n-bit-range n))))      ;; temp_1 ... temp_k
       (temp-exprs    (vl-make-idexpr-list (vl-netdecllist->names temp-netdecls) n :vl-unsigned))
       (last-temp     (car (last temp-exprs)))

       ;; We'll drive the temp wires in a moment.  But first, we'll put in our X
       ;; detection stuff.

       ((cons xdet-mod xdet-support)   (vl-make-n-bit-xdetect m))
       ((cons xeach-mod xeach-support) (vl-make-n-bit-xor-each n))
       (supporting-mods (list* xdet-mod xeach-mod (append xdet-support xeach-support pshift-mods pshift-support)))

       ((mv bx-expr bx-netdecl) (vl-occform-mkwire "bx" 1))
       (bx-args (list (make-vl-plainarg :expr bx-expr :dir :vl-output :portname (hons-copy "out"))
                      (make-vl-plainarg :expr b-expr  :dir :vl-input  :portname (hons-copy "in"))))
       (bx-modinst (make-vl-modinst :modname   (vl-module->name xdet-mod)
                                    :instname  (hons-copy "mk_bx")
                                    :paramargs (vl-arguments nil nil)
                                    :portargs  (vl-arguments nil bx-args)
                                    :loc       *vl-fakeloc*))

       (out-args (list (make-vl-plainarg :expr out-expr  :dir :vl-output :portname (hons-copy "out"))
                       (make-vl-plainarg :expr bx-expr   :dir :vl-input  :portname (hons-copy "a"))
                       (make-vl-plainarg :expr last-temp :dir :vl-input  :portname (hons-copy "b"))))
       (out-modinst (make-vl-modinst :modname   (vl-module->name xeach-mod)
                                     :instname  (hons-copy "mk_out")
                                     :paramargs (vl-arguments nil nil)
                                     :portargs  (vl-arguments nil out-args)
                                     :loc       *vl-fakeloc*))

       ;; The right-hand sides depend on how many bits we have in B.  But
       ;; in either case, much is the same:

       (lhs-exprs (cons a-expr (butlast temp-exprs 1)))
       (b-wires (vl-make-list-of-bitselects b-expr 0 (- m 1)))

       ((when (= m k))
        ;; We have exactly the right number of bits in B, so we can give one
        ;; bit to each shifter.
        (b* ((pshift-insts (vl-make-modinsts-for-shl 1 pshift-mods temp-exprs lhs-exprs b-wires)))
          (cons (make-vl-module :name      name
                                :origname  name
                                :ports     (list out-port a-port b-port)
                                :portdecls (list out-portdecl a-portdecl b-portdecl)
                                :netdecls  (list* out-netdecl a-netdecl b-netdecl bx-netdecl temp-netdecls)
                                :modinsts  (append pshift-insts (list bx-modinst out-modinst))
                                :minloc    *vl-fakeloc*
                                :maxloc    *vl-fakeloc*)
                supporting-mods)))

       ;; Otherwise, m > k.  We want to take the upper bits of B and xor them
       ;; all together for use in the final shift.  If any of them is high, we
       ;; get a zero.

       ;; wire merged_high = |(b[m-1:k-1]);
       (diff (+ 1 (- m k)))
       ((cons merged-mod merged-support) (vl-make-n-bit-reduction-op :vl-unary-bitor diff))
       ((mv merged-expr merged-netdecl)  (vl-occform-mkwire "merged_high" 1))

       (high-bits (make-vl-nonatom :op :vl-partselect-colon
                                   :args (list b-expr
                                               (vl-make-index (- m 1))
                                               (vl-make-index (- k 1)))
                                   :finalwidth diff
                                   :finaltype :vl-unsigned))
       (merged-args (list (make-vl-plainarg :expr merged-expr :dir :vl-output :portname (hons-copy "out"))
                          (make-vl-plainarg :expr high-bits   :dir :vl-input  :portname (hons-copy "in"))))
       (merged-inst (make-vl-modinst :modname   (vl-module->name merged-mod)
                                     :instname  (hons-copy "merge_high")
                                     :paramargs (vl-arguments nil nil)
                                     :portargs  (vl-arguments nil merged-args)
                                     :loc       *vl-fakeloc*))


       ;; Okay, now we're ready to build the rhses.  We just use merged-expr
       ;; as the arg to the final shifter.

       (lower-wires  (take (- k 1) b-wires)) ;; b[0], b[1], ..., b[k-2]
       (rhs-exprs    (append lower-wires (list merged-expr)))
       (pshift-insts (vl-make-modinsts-for-shl 1 pshift-mods temp-exprs lhs-exprs rhs-exprs)))

    (list* (make-vl-module :name      name
                           :origname  name
                           :ports     (list out-port a-port b-port)
                           :portdecls (list out-portdecl a-portdecl b-portdecl)
                           :netdecls  (list* out-netdecl a-netdecl b-netdecl bx-netdecl merged-netdecl temp-netdecls)
                           :modinsts  (cons merged-inst (append pshift-insts (list bx-modinst out-modinst)))
                           :minloc    *vl-fakeloc*
                           :maxloc    *vl-fakeloc*)
           merged-mod
           (append merged-support supporting-mods))))
