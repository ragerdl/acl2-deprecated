; AIGNET - And-Inverter Graph Networks
; Copyright (C) 2013 Centaur Technology
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
; Original author: Sol Swords <sswords@centtech.com>

(in-package "AIGNET")
(include-book "from-hons-aig")
(include-book "centaur/aig/aiger" :dir :system)
(include-book "tools/defmacfun" :dir :system)
(local (include-book "clause-processors/instantiate" :dir :system))
(local (include-book "arithmetic/top-with-meta" :dir :system))
(set-state-ok t)

(local (in-theory (disable acl2::nth-with-large-index
                           nth update-nth
                           state-p1-forward)))
(local (in-theory (enable* acl2::arith-equiv-forwarding)))

(defstobj-clone aigernums u32arr :suffix "-AIGER")

(local (in-theory (disable acl2::update-nth-update-nth)))


(defsection aignet-aiger-number-nodes
  ;; Assign each node its aiger ID and record it in aigernums.  Regoffset is
  ;; 1+ninputs, which is added to the IO num of each register to make its aiger
  ;; ID.  An input's ID is made by adding 1 to its IO num.  Gates are numbered
  ;; sequentially, tracked by nextgate, which starts at 1+nins+nregs.
  (defiteration aignet-aiger-number-nodes (aignet aigernums)
    (declare (xargs :stobjs (aignet aigernums)
                    :guard (<= (num-nodes aignet) (u32-length aigernums))
                    :guard-hints (("goal" :in-theory (enable aignet-idp)))))
    (b* ((type (id->type n aignet))
         (nextgate (lnfix nextgate))
         ((when (int= type (out-type)))
          (mv aigernums nextgate))
         (val (aignet-seq-case
               type (io-id->regp n aignet)
               :gate  nextgate
               :pi    (+ 1 (io-id->ionum n aignet))
               :reg   (+ 1 (num-ins aignet) (io-id->ionum n aignet))
               :const 0))
         (nextgate (if (int= type (gate-type))
                       (1+ nextgate)
                     nextgate))
         (aigernums (set-u32 n val aigernums)))
      (mv aigernums nextgate))
    :returns (mv aigernums nextgate)
    :top-returns aigernums
    :index n
    :init-vals ((nextgate (+ 1 (num-ins aignet) (num-regs aignet))))
    :iter-decls ((type (integer 0 *) nextgate))
    :first 0
    :last (num-nodes aignet))

  (in-theory (disable aignet-aiger-number-nodes))
  (local (in-theory (enable aignet-aiger-number-nodes)))

  (defthm natp-of-aignet-aiger-number-nodes-iter-nextgate
    (implies (natp nextgate)
             (natp (mv-nth 1 (aignet-aiger-number-nodes-iter n nextgate aignet aigernums))))
    :hints((acl2::just-induct-and-expand
            (aignet-aiger-number-nodes-iter n nextgate aignet aigernums)))
    :rule-classes :type-prescription)

  ;; (defun aignet-aiger-number-nodes-iter (n regoffset nextgate aignet aigernums)
  ;;   (declare (type (integer 0 *) n)
  ;;            (type (integer 0 *) regoffset)
  ;;            (type (integer 0 *) nextgate)
  ;;            (xargs :stobjs (aignet aigernums)
  ;;                   :guard (and (u32arr-sizedp aigernums aignet)
  ;;                               (aignet-iterator-p n aignet))
  ;;                   :measure (nfix (- (nfix (num-nodes aignet)) (nfix n)))))
  ;;   (b* (((when (mbe :logic (zp (- (nfix (num-nodes aignet)) (nfix n)))
  ;;                    :exec (int= (num-nodes aignet) n)))
  ;;         aigernums)
  ;;        (nextgate (lnfix nextgate))
  ;;        ((mv aigernums nextgate)
  ;;         (case (id->type (to-id n) aignet)
  ;;           (1 ;; gate
  ;;            (b* ((aigernums (set-u32 n nextgate aigernums)))
  ;;              (mv aigernums (1+ nextgate))))
  ;;           (2 ;; CI
  ;;            (b* ((aigernums (set-u32 n (+ (if (int= (io-id->regp (to-id n) aignet) 1)
  ;;                                              (lnfix regoffset)
  ;;                                            1)
  ;;                                          (io-id->ionum (to-id n) aignet))
  ;;                                     aigernums)))
  ;;              (mv aigernums nextgate)))
  ;;           (3 ;; CO -- skip
  ;;            (mv aigernums nextgate))
  ;;           (otherwise ;; 0 -- const
  ;;            (b* ((aigernums (set-u32 n 0 aigernums)))
  ;;              (mv aigernums nextgate))))))
  ;;     (aignet-aiger-number-nodes-iter (1+ (lnfix n)) regoffset nextgate aignet
  ;;                               aigernums)))

  (defthm aigernums-size-of-aignet-aiger-number-nodes-iter
    (implies (< (node-count aignet) (len aigernums))
             (< (node-count aignet) (len (mv-nth 0 (aignet-aiger-number-nodes-iter
                                                    n nextgate aignet
                                                    aigernums)))))
    :hints((acl2::just-induct-and-expand
            (aignet-aiger-number-nodes-iter
             n nextgate aignet
             aigernums)))
    :rule-classes :linear)

  ;; (defun aignet-aiger-number-nodes (aignet aigernums)
  ;;   (declare (xargs :stobjs (aignet aigernums)
  ;;                   :guard (and (aignet-well-formedp aignet)
  ;;                               (u32arr-sizedp aigernums aignet))))
  ;;   (aignet-aiger-number-nodes-iter
  ;;    0
  ;;    (+ 1 (lnfix (num-ins aignet)))
  ;;    (+ 1 (lnfix (num-ins aignet)) (lnfix (num-regs aignet)))
  ;;    aignet aigernums))


  (defthm aigernums-size-of-aignet-aiger-number-nodes
    (implies (< (node-count aignet) (len aigernums))
             (< (node-count aignet) (len (aignet-aiger-number-nodes aignet aigernums))))
    :rule-classes :linear)

  (defthm aignet-number-nodes-iter-nextgate-incr
    (implies (natp nextgate)
             (<= nextgate
                 (mv-nth 1 (aignet-aiger-number-nodes-iter
                            n nextgate aignet aigernums))))
    :hints((acl2::just-induct-and-expand
            (aignet-aiger-number-nodes-iter
                            n nextgate aignet aigernums)))
    :rule-classes :linear))


(local (defthm equal-1-when-bitp
         (implies (and (not (equal x 0))
                       (acl2::bitp x))
                  (equal (equal x 1) t))
         :hints(("Goal" :in-theory (enable acl2::bitp)))
         :rule-classes ((:rewrite :backchain-limit-lst (0 nil)))))

(definline aignet-to-aiger-lit (lit aigernums)
  (declare (type (integer 0 *) lit)
           (xargs :stobjs aigernums
                  :guard (and (litp lit)
                              (< (lit-id lit)
                                 (u32-length aigernums)))))
  (mk-lit
   (get-u32 (lit-id lit) aigernums)
   (lit-neg lit)))


(define aiger-fanins-precede-gates (n aignet aigernums)
  (declare (type (integer 0 *) n)
           (xargs :guard (and (<= n (num-nodes aignet))
                              (<= (num-nodes aignet) (u32-length aigernums)))
                  :guard-hints (("goal" :in-theory (enable aignet-idp)))))
  (b* (((when (zp n)) t)
       (n (1- n))
       ((unless (int= (id->type n aignet) (gate-type)))
        (aiger-fanins-precede-gates n aignet aigernums))
       (idv0 (get-u32 (lit-id (gate-id->fanin0 n aignet)) aigernums))
       (idv1 (get-u32 (lit-id (gate-id->fanin1 n aignet)) aigernums))
       (idvn (get-u32 n aigernums)))
    (and (< idv0 idvn)
         (< idv1 idvn)
         (aiger-fanins-precede-gates n aignet aigernums)))
  ///
  (defcong nat-equiv equal (aiger-fanins-precede-gates n aignet aigernums) 1)


  (defthm aiger-fanins-precede-gates-of-update-later
    (implies (and (aiger-fanins-precede-gates
                   n aignet aigernums)
                  (<= (nfix n) (nfix m))
                  (aignet-idp m aignet)
                  ;;(<= (nfix n) (num-nodes aignet))
                  )
             (aiger-fanins-precede-gates
              n aignet (update-nth m v aigernums)))
    :hints(("Goal" :in-theory (e/d (aignet-idp)
                                   ((:d aiger-fanins-precede-gates)))
            :induct (aiger-fanins-precede-gates
                     n aignet (update-nth m v aigernums))
            :expand ((:free (aigernums)
                      (aiger-fanins-precede-gates
                       n aignet aigernums))
                     (:free (aigernums)
                      (aiger-fanins-precede-gates
                       0 aignet aigernums)))))))

(define aiger-max-id (n aignet aigernums)
  (declare (type (integer 0 *) n)
           (xargs :guard (and (<= n (num-nodes aignet))
                              (<= (num-nodes aignet) (u32-length aigernums)))
                  :verify-guards nil))
  :returns (max natp :rule-classes :type-prescription)
  (b* (((when (zp n)) 0)
       (n (1- n))
       ((when (int= (id->type n aignet) (out-type)))
        (aiger-max-id n aignet aigernums))
       (id (get-u32 n aigernums)))
    (max id (aiger-max-id n aignet aigernums)))
  ///
  (verify-guards aiger-max-id
    :hints (("goal" :in-theory (enable aignet-idp))))

  (defcong nat-equiv equal (aiger-max-id n aignet aigernums) 1)


  (defthm aiger-max-id-of-update-later
    (implies (and (<= (nfix n) (nfix m))
                  (aignet-idp m aignet))
             (equal (aiger-max-id
                     n aignet (update-nth m v aigernums))
                    (aiger-max-id
                     n aignet aigernums)))
    :hints(("Goal" :in-theory (enable aignet-idp))))

  (defthm aiger-max-id-thm
    (implies (and (< (nfix m) (nfix n))
                  (not (equal (id->type m aignet) (out-type))))
             (<= (nfix (nth m aigernums))
                 (aiger-max-id n aignet aigernums)))
    :hints (("goal" :induct (aiger-max-id n aignet aigernums)))
    :rule-classes nil)

  (defthm aiger-max-id-of-number-nodes-iter-special
    (b* (((mv aigernums ?nextgate)
          (aignet-aiger-number-nodes-iter
           n nextgate aignet aigernums)))
      (implies (and (natp (nth m aigernums))
                    (< (nfix m) (nfix n))
                    (not (equal (id->type m aignet) (out-type))))
               (<= (nth m aigernums)
                   (aiger-max-id n aignet aigernums))))
    :hints (("goal" :use ((:instance aiger-max-id-thm
                           (aigernums (mv-nth 0
                                              (aignet-aiger-number-nodes-iter
                                               n nextgate aignet aigernums)))))))
    :rule-classes :linear))

(defthm not-out-type-when-aignet-litp
  (implies (aignet-litp lit aignet)
           (not (equal (ctype (stype (car (lookup-id (lit-id lit) aignet))))
                       (out-ctype))))
  :hints(("Goal" :in-theory (enable aignet-litp))))



(defthm aiger-fanins-precede-gate-of-aignet-aiger-number-nodes-iter
  (implies (<= (nfix n) (num-nodes aignet))
           (b* (((mv aigernums nextgate)
                 (aignet-aiger-number-nodes-iter
                  n (+ 1 (stype-count (pi-stype) aignet)
                       (stype-count (reg-stype) aignet))
                  aignet aigernums)))
             (and (aiger-fanins-precede-gates n aignet aigernums)
                  (< (aiger-max-id n aignet aigernums) nextgate))))
  :hints (("goal" :induct (aignet-aiger-number-nodes-iter
                           n (+ 1 (stype-count (pi-stype) aignet)
                                (stype-count (reg-stype) aignet))
                           aignet aigernums)
           :in-theory (e/d (aignet-idp)
                           (aiger-fanins-precede-gates
                            (:d aignet-aiger-number-nodes-iter)
                            acl2::nfix-when-not-natp))
           :expand ((:free (nextgate)
                     (aignet-aiger-number-nodes-iter
                      n nextgate aignet aigernums))
                    (:free (aigernums)
                     (aiger-fanins-precede-gates n aignet aigernums))
                    (:free (aigernums)
                     (aiger-max-id n aignet aigernums))
                    (:free (aigernums)
                     (aiger-fanins-precede-gates 0 aignet aigernums))
                    (:free (aigernums)
                     (aiger-max-id 0 aignet aigernums))))))

(defthm aiger-fanins-precede-gate-of-aignet-aiger-number-nodes
  (aiger-fanins-precede-gates
   (+ 1 (node-count aignet)) aignet
   (aignet-aiger-number-nodes aignet aigernums))
  :hints(("Goal" :in-theory (enable aignet-aiger-number-nodes))))


(defsection lits-ordered-when-aiger-fanins-precede-gates
  (local (include-book "centaur/bitops/ihsext-basics" :dir :system))
  (local (include-book "arithmetic/top-with-meta" :dir :system))
  (defthm mk-lit-compare
    (implies (< (nfix id1) (nfix id2))
             (< (lit-val (mk-lit id1 neg1))
                (lit-val (mk-lit id2 neg2))))
    :hints(("Goal" :in-theory (e/d* (mk-lit
                                     acl2::ihsext-redefs)))))

  (defthm ids-ordered-when-aiger-fanins-precede-gates
    (implies (and (aiger-fanins-precede-gates n aignet aigernums)
                  (< (nfix m) (nfix n))
                  (equal (id->type m aignet) (gate-type)))
             (let* ((look (lookup-id m aignet))
                    (a0 (nth (lit-id (aignet-lit-fix
                                      (gate-node->fanin0 (car look))
                                      (cdr look)))
                             aigernums))
                    (a1 (nth (lit-id (aignet-lit-fix
                                      (gate-node->fanin1 (car look))
                                      (cdr look)))
                             aigernums)))
               (and (< (nfix a0) (nfix (nth m aigernums)))
                    ;; (implies (natp a0)
                    ;;          (< a0 (nfix (nth m aigernums))))
                    (< (nfix a1) (nfix (nth m aigernums)))
                    ;; (implies (natp a1)
                    ;;          (< a1 (nfix (nth m aigernums))))
                    )))
    :hints (("goal" :induct (aiger-fanins-precede-gates n aignet aigernums)
             :in-theory (enable (:i aiger-fanins-precede-gates))
             :expand ((aiger-fanins-precede-gates n aignet aigernums)))))

  (defthm lits-ordered-when-aiger-fanins-precede-gates-1
    (implies (and (aiger-fanins-precede-gates n aignet aigernums)
                  (< (nfix m) (nfix n))
                  (equal (id->type m aignet) (gate-type)))
             (b* ((look (lookup-id m aignet))
                  (?a0 (nth (lit-id (aignet-lit-fix
                                     (gate-node->fanin0 (car look))
                                     (cdr look)))
                            aigernums))
                  (?a1 (nth (lit-id (aignet-lit-fix
                                     (gate-node->fanin1 (car look))
                                     (cdr look)))
                            aigernums))
                  (mid (nth m aigernums)))
               (and (< (lit-val (mk-lit a0 neg0))
                       (lit-val (mk-lit mid 0)))
                    (< (lit-val (mk-lit a1 neg1))
                       (lit-val (mk-lit mid 0))))))
    :rule-classes :linear))







(defsection aignet-outs-write-aiger-lits
  (local (defthm <-0-by-transitive
           (implies (and (< a b)
                         (<= 0 a))
                    (< 0 b))
           :rule-classes :forward-chaining))
  (defiteration aignet-outs-write-aiger-lits (aignet aigernums channel state)
    (declare (xargs :stobjs (aignet aigernums state)
                    :guard (and (symbolp channel)
                                (open-output-channel-p channel :byte state)
                                (<= (num-nodes aignet) (u32-length aigernums)))))
    (b* ((fanin-lit (co-id->fanin (outnum->id idx aignet) aignet))
         (aiger-id (get-u32 (lit-id fanin-lit) aigernums))
         (lit (mk-lit aiger-id (lit-neg fanin-lit)))
         (state (acl2::write-ascii-nat lit channel state)))
      (acl2::write-byte$ (char-code #\Newline) channel state))
    :returns state
    :index idx
    :first 0
    :last (num-outs aignet))

  (in-theory (disable aignet-outs-write-aiger-lits))
  (local (in-theory (enable aignet-outs-write-aiger-lits)))

  (defthm open-output-channel-p1-of-aignet-outs-write-aiger-lits-iter
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-outs-write-aiger-lits-iter idx aignet aigernums channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))
    :hints((acl2::just-induct-and-expand
            (aignet-outs-write-aiger-lits-iter idx aignet aigernums channel state))))

  (defthm open-output-channel-p1-of-aignet-outs-write-aiger-lits
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-outs-write-aiger-lits aignet aigernums channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))
    :hints(("Goal" :in-theory (enable aignet-outs-write-aiger-lits)))))

(defsection aignet-nxsts-write-aiger-lits
  (local (defthm <-0-by-transitive
           (implies (and (< a b)
                         (<= 0 a))
                    (< 0 b))
           :rule-classes :forward-chaining))

  (defiteration aignet-nxsts-write-aiger-lits (aignet aigernums channel state)
    (declare (xargs :stobjs (aignet aigernums state)
                    :guard (and (symbolp channel)
                                (open-output-channel-p channel :byte state)
                                (<= (num-nodes aignet) (u32-length aigernums)))))
    (b* ((reg-id (regnum->id idx aignet))
         (nxst (reg-id->nxst reg-id aignet))
         (fanin-lit (if (int= (id->type nxst aignet) (out-type))
                        (co-id->fanin nxst aignet)
                      (mk-lit nxst 0)))
         (aiger-id (get-u32 (lit-id fanin-lit) aigernums))
         (lit (mk-lit aiger-id (lit-neg fanin-lit)))
         (state (acl2::write-ascii-nat lit channel state)))
      (acl2::write-byte$ (char-code #\Newline) channel state))
    :returns state
    :index idx
    :first 0
    :last (num-regs aignet))

  (in-theory (disable aignet-nxsts-write-aiger-lits))
  (local (in-theory (enable aignet-nxsts-write-aiger-lits)))

  (defthm open-output-channel-p1-of-aignet-nxsts-write-aiger-lits-iter
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-nxsts-write-aiger-lits-iter idx aignet aigernums channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))
    :hints((acl2::just-induct-and-expand
            (aignet-nxsts-write-aiger-lits-iter idx aignet aigernums channel state))))

  (defthm open-output-channel-p1-of-aignet-nxsts-write-aiger-lits
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-nxsts-write-aiger-lits aignet aigernums channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))
    :hints(("Goal" :in-theory (enable aignet-nxsts-write-aiger-lits)))))

(defsection aignet-write-aiger-gates
  (local (in-theory (disable gate-fanin0-aignet-litp-when-aignet-nodes-ok
                             gate-fanin1-aignet-litp-when-aignet-nodes-ok)))
  (defiteration aignet-write-aiger-gates (aignet aigernums channel state)
    (declare (xargs :stobjs (aignet aigernums state)
                    :guard (and (symbolp channel)
                                (open-output-channel-p channel :byte state)
                                (<= (num-nodes aignet) (u32-length aigernums))
                                (aiger-fanins-precede-gates
                                 (num-nodes aignet) aignet aigernums))
                    :guard-hints ('(:in-theory (enable aignet-idp)))))
    (b* ((slot0 (id->slot id 0 aignet))
         (type (snode->type slot0))
         ((unless (int= type (gate-type)))
          state)
         (lit1 (gate-id->fanin0 id aignet))
         (lit2 (gate-id->fanin1 id aignet))
         (lit1 (aignet-to-aiger-lit lit1 aigernums))
         (lit2 (aignet-to-aiger-lit lit2 aigernums))
         ((mv lit1 lit2)
          (if (< (lit-val lit1) (lit-val lit2))
              (mv lit2 lit1)
            (mv lit1 lit2)))
         (lhslit (aignet-to-aiger-lit (mk-lit id 0) aigernums))
         (delta1 (- (lit-val lhslit) (lit-val lit1)))
         (delta2 (- (lit-val lit1) (lit-val lit2)))
         (state (acl2::aiger-write-delta delta1 channel state)))
      (acl2::aiger-write-delta delta2 channel state))
    :returns state
    :index id
    :first 0
    :last (num-nodes aignet))

  (in-theory (disable aignet-write-aiger-gates))
  (local (in-theory (enable aignet-write-aiger-gates)))

  (defthm open-output-channel-p1-of-aignet-gates-write-aiger-gates-iter
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-write-aiger-gates-iter id aignet aigernums channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))
    :hints((acl2::just-induct-and-expand
            (aignet-write-aiger-gates-iter id aignet aigernums channel state))
           '(:in-theory (disable acl2::aiger-write-delta))))

  (defthm open-output-channel-p1-of-aignet-gates-write-aiger-gates
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-write-aiger-gates aignet aigernums channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))))


(define aignet-write-aiger-chan (aignet (channel symbolp) state)
  :guard (open-output-channel-p channel :byte state)
  (b* (((local-stobjs aigernums)
        (mv aigernums state))
       (aigernums (resize-u32 (num-nodes aignet) aigernums))
       (nlatches (num-regs aignet))
       (nouts    (num-outs aignet))
       (nins     (num-ins aignet))
       (ngates   (num-gates aignet))
       (aigernums (aignet-aiger-number-nodes aignet aigernums))
       (state (acl2::aiger-write-header
               (+ (num-ins aignet) (num-regs aignet) (num-gates aignet))
               nins nlatches nouts ngates 0 0 channel state))
       (state (aignet-nxsts-write-aiger-lits aignet aigernums channel state))
       (state (aignet-outs-write-aiger-lits aignet aigernums channel state))
       (state (aignet-write-aiger-gates aignet aigernums channel state)))
    (mv aigernums state))
  ///

  (defthm open-output-channel-p1-of-aignet-write-aiger-chan
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-output-channel-p1 channel :byte state))
             (let ((state (aignet-write-aiger-chan aignet channel state)))
               (and (state-p1 state)
                    (open-output-channel-p1 channel :byte state))))))

(defttag aignet-write-aiger)

(define aignet-write-aiger ((fname stringp) aignet state)
  (b* (((mv channel state)
        (open-output-channel! fname :byte state))
       ((unless channel)
        (er hard? 'aignet-write-aiger
            "Failed to open aiger output file ~x0~%" fname)
        state)
       (state (aignet-write-aiger-chan aignet channel state)))
    (close-output-channel channel state)))

(acl2::defmacfun
 aiger-write (fname &optional latch-aigs out-aigs acl2::&auto state)
 (declare (xargs :stobjs state
                 :guard (and (stringp fname)
                             (true-listp latch-aigs)
                             (true-listp out-aigs)
                             (non-bool-atom-listp (alist-keys latch-aigs)))
                 :guard-debug t))
 ; (declare (xargs :mode :program))
 (b* (((local-stobjs aignet) (mv pis state aignet))
      (len (+ (len latch-aigs) (len out-aigs)))
      ((mv aignet ?varmap invars ?regvars)
       (aig-fsm-to-aignet latch-aigs out-aigs (+ 1 (* 5 len)) 2 aignet))
      (state (aignet-write-aiger fname aignet state)))
   (mv invars state aignet)))


;; (defun aignet-no-outsp (n aignet)
;;   (declare (type (integer 0 *) n)
;;            (xargs :stobjs aignet
;;                   :guard (and (aignet-well-formedp aignet)
;;                               (aignet-iterator-p n aignet))))
;;   (if (zp n)
;;       t
;;     (and (not (equal (id->type (to-id (1- n)) aignet) (out-type)))
;;          (aignet-no-outsp (1- n) aignet))))

;; (defcong nat-equiv equal (aignet-no-outsp n aignet) 1)

;; (defun aignet-ris-unconnected (n aignet)
;;   (declare (type (integer 0 *) n)
;;            (xargs :stobjs aignet
;;                   :guard (and (aignet-well-formedp aignet)
;;                               (<= n (num-regs aignet)))
;;                   :measure (nfix (- (nfix (num-regs aignet)) (nfix n)))))
;;   (if (mbe :logic (zp (- (nfix (num-regs aignet)) (nfix n)))
;;            :exec (= n (num-regs aignet)))
;;       t
;;     (and (int= (id->type (regnum->id n aignet) aignet) (in-type))
;;          (aignet-ris-unconnected (+ 1 (lnfix n)) aignet))))


(define aignet-make-n-inputs (n aignet)
  (declare (type (integer 0 *) n))
  (b* (((when (zp n)) aignet)
       (aignet (aignet-add-in aignet)))
    (aignet-make-n-inputs (1- n) aignet))
  ///
  (def-aignet-preservation-thms aignet-make-n-inputs)

  (defthm num-inputs-of-aignet-make-n-inputs
    (equal (stype-count (pi-stype)
                        (aignet-make-n-inputs n aignet))
           (+ (nfix n) (stype-count (pi-stype) aignet))))
  
  (defthm stype-counts-preserved-of-aignet-make-n-inputs
    (implies (not (equal (stype-fix stype) (pi-stype)))
             (equal (stype-count stype (aignet-make-n-inputs n aignet))
                    (stype-count stype aignet)))))


;; (defthm aignet-no-outsp-add-in-preserved
;;   (implies (and (aignet-no-outsp n aignet)
;;                 (<= (nfix n) (nfix (num-nodes aignet))))
;;            (aignet-no-outsp n (mv-nth 1 (aignet-add-in aignet)))))

;; (defthm aignet-no-outsp-of-make-n-inputs
;;   (implies (aignet-no-outsp (nth *num-nodes* aignet) aignet)
;;            (let ((aignet (aignet-make-n-inputs n aignet)))
;;              (implies (equal (nfix k) (nfix (num-nodes aignet)))
;;                       (aignet-no-outsp k aignet)))))

;; (defthm aignet-ris-unconnected-add-in-preserved
;;   (implies (and (aignet-well-formedp aignet)
;;                 (aignet-ris-unconnected n aignet))
;;            (aignet-ris-unconnected n (mv-nth 1 (aignet-add-in aignet))))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms))))

;; (defthm aignet-ris-unconnected-of-make-n-inputs
;;   (implies (and (aignet-ris-unconnected k aignet)
;;                 (aignet-well-formedp aignet))
;;            (let ((aignet (aignet-make-n-inputs n aignet)))
;;              (aignet-ris-unconnected k aignet)))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms))))

(define aignet-make-n-regs (n aignet)
  (declare (type (integer 0 *) n))
  (b* (((when (zp n)) aignet)
       (aignet (aignet-add-reg aignet)))
    (aignet-make-n-regs (1- n) aignet))
  ///
  (def-aignet-preservation-thms aignet-make-n-regs)

  (defthm num-regs-of-aignet-make-n-regs
    (equal (stype-count (reg-stype)
                        (aignet-make-n-regs n aignet))
           (+ (nfix n) (stype-count (reg-stype) aignet))))
  
  (defthm stype-counts-preserved-of-aignet-make-n-regs
    (implies (not (equal (stype-fix stype) (reg-stype)))
             (equal (stype-count stype (aignet-make-n-regs n aignet))
                    (stype-count stype aignet)))))


;; (defthm aignet-no-outsp-add-reg-preserved
;;   (implies (and (aignet-no-outsp n aignet)
;;                 (<= (nfix n) (nfix (num-nodes aignet))))
;;            (aignet-no-outsp n (mv-nth 1 (aignet-add-reg aignet)))))

;; (defthm aignet-no-outsp-of-make-n-regs
;;   (implies (aignet-no-outsp (nth *num-nodes* aignet) aignet)
;;            (let ((aignet (aignet-make-n-regs n aignet)))
;;              (implies (equal (nfix k) (nfix (num-nodes aignet)))
;;                       (aignet-no-outsp k aignet)))))

;; (defthm aignet-ris-unconnected-add-reg-preserved
;;   (implies (and (aignet-well-formedp aignet)
;;                 (aignet-ris-unconnected n aignet))
;;            (aignet-ris-unconnected n (mv-nth 1 (aignet-add-reg aignet))))
;;   :hints(("Goal" :in-theory (enable* aignet-add-reg
;;                                      aignet-frame-thms
;;                                      nth-node-of-update-nth-node-split))))

;; (defthm aignet-regnum->id-of-aignet-add-reg-prev
;;   (implies (and (aignet-well-formedp aignet)
;;                 (< (nfix k) (nfix (num-regs aignet))))
;;            (equal (nth-id k (nth *regsi* (mv-nth 1 (aignet-add-reg aignet))))
;;                   (nth-id k (nth *regsi* aignet))))
;;   :hints(("Goal" :in-theory (enable* aignet-add-reg
;;                                      aignet-frame-thms
;;                                      maybe-grow-regs
;;                                      nth-id update-nth-id))))

;; (defthm num-regs-of-aignet-add-reg
;;   (equal (nth *num-regs* (mv-nth 1 (aignet-add-reg aignet)))
;;          (+ 1 (nfix (nth *num-regs* aignet))))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms
;;                                      aignet-add-reg))))

;; (defthm new-reg-of-aignet-add-reg
;;   (implies (equal (nfix k) (nfix (num-regs aignet)))
;;            (equal (nth-id k (nth *regsi* (mv-nth 1 (aignet-add-reg aignet))))
;;                   (to-id (nth *num-nodes* aignet))))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms
;;                                      aignet-add-reg))))

;; (defthm aignet-regnum->id-of-make-n-regs-prev
;;   (implies (and (aignet-well-formedp aignet)
;;                 (< (nfix k) (nfix (num-regs aignet))))
;;            (equal (nth-id k (nth *regsi* (aignet-make-n-regs n aignet)))
;;                   (nth-id k (nth *regsi* aignet))))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms))))

;; (defthm reg-node->ri-of-new-reg-aignet-make-n-regs
;;   (implies (and (aignet-well-formedp aignet)
;;                 (<= (nfix (num-regs aignet)) (nfix k))
;;                 (< (nfix k) (nfix (num-regs (aignet-make-n-regs n aignet)))))
;;            (equal (node->type (nth-node (nth-id k (nth *regsi* (aignet-make-n-regs n aignet)))
;;                                       (nth *nodesi* (aignet-make-n-regs n aignet))))
;;                   (in-type))))

;; (defthm aignet-ris-unconnected-of-make-n-regs
;;   (implies (and (aignet-ris-unconnected k aignet)
;;                 (aignet-well-formedp aignet))
;;            (let ((aignet (aignet-make-n-regs n aignet)))
;;              (aignet-ris-unconnected k aignet)))
;;   :hints (("goal" :induct t)
;;           (and stable-under-simplificationp
;;                '(:cases ((<= (nfix (num-regs aignet)) (nfix k)))))))

;; (defthm num-regs-of-aignet-make-n-regs
;;   (implies (natp (nth *num-regs* aignet))
;;            (equal (nth *num-regs* (aignet-make-n-regs n aignet))
;;                   (+ (nth *num-regs* aignet) (nfix n)))))

(defstobj-clone regarr litarr :suffix "-REGS")
(defstobj-clone outarr litarr :suffix "-OUTS")

(define aignet-read-aiger-latches/outs (idx litarr ncount nxtbyte channel state)
  (declare (type (integer 0 *) idx)
           (type (integer 0 *) ncount)
           (Xargs :stobjs (litarr state)
                  :guard (and (symbolp channel)
                              (open-input-channel-p channel :byte state)
                              (acl2::maybe-byte-p nxtbyte)
                              (<= ncount (lits-length litarr))
                              (<= idx ncount))
                  :measure (nfix (- (nfix ncount)
                                    (nfix idx)))))
  (b* (((when (mbe :logic (zp (- (nfix ncount)
                                 (nfix idx)))
                   :exec (= idx ncount)))
        (mv nil litarr nxtbyte state))
       ((mv num nxtbyte state)
        (acl2::read-ascii-nat channel nxtbyte state))
       ((when (not num))
        (cw "Failed to parse number~%")
        (break$)
        (mv "Failed to parse number" litarr nxtbyte state))
       (litarr (set-lit idx (to-lit num) litarr))
       ((mv nxt nxtbyte state)
        (acl2::read-byte-buf channel nxtbyte state))
       ((when (not (eql nxt (char-code #\Newline))))
        (cw "No newline~%")
        (break$)
        (mv "No newline" litarr nxtbyte state)))
    (aignet-read-aiger-latches/outs (1+ (lnfix idx)) litarr ncount nxtbyte
                                    channel state))
  ///
  (defthm lits-length-of-aignet-read-aiger-latches/outs
    (<= (len litarr)
        (len (mv-nth 1 (aignet-read-aiger-latches/outs
                        idx litarr ncount nxtbyte channel
                        state))))
    :rule-classes :linear)

  (defthm open-input-channel-p1-of-aignet-read-aiger-latches/outs
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-input-channel-p1 channel :byte state))
             (let ((state (mv-nth 3 (aignet-read-aiger-latches/outs
                                     idx litarr ncount nxtbyte channel state))))
               (and (state-p1 state)
                    (open-input-channel-p1 channel :byte state)))))

  (defthm maybe-byte-p-of-aignet-read-aiger-latches/outs
    (implies (acl2::maybe-byte-p nxtbyte)
             (acl2::maybe-byte-p (mv-nth 2 (aignet-read-aiger-latches/outs
                                            idx litarr ncount nxtbyte channel state))))))



(local
 (encapsulate nil
   (local
    (progn
      (include-book "arithmetic/top-with-meta" :dir :system)

      (defthm floor-1
        (implies (natp x)
                 (equal (floor x 1) x)))

      (defthm niq-lte-quotient
        (implies (and (natp a) (posp b))
                 (<= (nonnegative-integer-quotient a b) (/ a b)))
        :rule-classes nil)

      (defthm floor-1-less
        (implies (and (natp a)
                      (rationalp b)
                      (< b a))
                 (< (floor b 1) a))
        :hints ((and stable-under-simplificationp
                     '(:use ((:instance niq-lte-quotient
                              (a (numerator b)) (b (denominator b))))))))))

   (defthm id-in-bounds-of-diff
     (implies (and (posp num-nodes)
                   (posp delta1))
              (<
               (LIT-ID
                (TO-LIT
                 (+ (LIT-VAL (MK-LIT num-nodes 0))
                    (- delta1))))
               num-nodes))
     :hints(("Goal" :in-theory (e/d (lit-id mk-lit
                                            nfix)
                                    (floor))))
     :rule-classes :linear)

   (defthm id-in-bounds-of-diff2
     (implies (and (posp num-nodes)
                   (posp delta1)
                   (natp delta2))
              (<
               (LIT-ID
                (TO-LIT
                 (+
                  (LIT-VAL (MK-LIT num-nodes 0))
                  (- delta1)
                  (- delta2))))
               num-nodes))
     :hints (("goal" :use ((:instance id-in-bounds-of-diff
                            (delta1 (+ delta1 delta2))))))
     :rule-classes :linear)))

(defthm aignet-not-output-when-no-outs
  (implies (and (equal (stype-count (po-stype) aignet) 0)
                (equal (stype-count (nxst-stype) aignet) 0))
           (not (equal (ctype (stype (car (lookup-id id aignet))))
                       (out-ctype))))
  :hints(("Goal" :in-theory (enable lookup-id stype-count)
          :induct t)
         (and stable-under-simplificationp
              '(:cases ((equal 1 (regp (stype (car aignet)))))))))


;; (defthm aignet-no-outsp-of-aignet-add-gate
;;   (implies (and (aignet-no-outsp n aignet)
;;                 (<= (nfix n) (nfix (num-nodes aignet))))
;;            (aignet-no-outsp n (mv-nth 1 (aignet-add-gate f0 f1 aignet)))))

(define aignet-read-aiger-gates (idx numgates aignet nxtbyte channel state)
  (declare (Xargs :stobjs (aignet state)
                  :guard (and (symbolp channel)
                              (open-input-channel-p channel :byte state)
                              (acl2::maybe-byte-p nxtbyte)
                              (natp idx) (natp numgates)
                              (<= idx numgates)
                              (eql (num-outs aignet) 0)
                              (eql (num-nxsts aignet) 0))
                  :measure (nfix (- (nfix numgates)
                                    (nfix idx)))
                  :guard-hints (("goal" :do-not-induct t
                                 :in-theory (enable aignet-litp aignet-idp)))))
  :returns (mv msg aignet nxtbyte state)
  (b* (((when (mbe :logic (zp (- (nfix numgates)
                                 (nfix idx)))
                   :exec (= idx numgates)))
        (mv nil aignet nxtbyte state))
       (aiger-idx (lit-val (mk-lit (num-nodes aignet) 0)))
       ((mv err delta1 nxtbyte state)
        (acl2::read-bytecoded-nat channel nxtbyte state))
       ((when err) (mv err aignet nxtbyte state))
       ((when (< aiger-idx delta1))
        (mv "Bad delta1: greater than current index"
            aignet nxtbyte state))
       ((when (>= 0 delta1))
        (mv "Bad delta1: zero" aignet nxtbyte state))
       ((mv err delta2 nxtbyte state)
        (acl2::read-bytecoded-nat channel nxtbyte state))
       ((when (< aiger-idx (+ delta1 delta2)))
        (mv "Bad delta2: greater than current index - delta1"
            aignet nxtbyte state))
       ((when err) (mv err aignet nxtbyte state))
       (aiger-rhs1 (- aiger-idx delta1))
       (aiger-rhs2 (- aiger-rhs1 delta2))
       (rhs1 (to-lit aiger-rhs1))
       (rhs2 (to-lit aiger-rhs2))
       (aignet (aignet-add-gate rhs1 rhs2 aignet)))
    (aignet-read-aiger-gates
     (1+ (nfix idx)) numgates aignet nxtbyte channel state))

  ///

  (defthm open-input-channel-p1-of-aignet-read-aiger-gates
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-input-channel-p1 channel :byte state))
             (let ((state (mv-nth 3 (aignet-read-aiger-gates
                                     idx numgates aignet nxtbyte channel state))))
               (and (state-p1 state)
                    (open-input-channel-p1 channel :byte state)))))

  (defthm maybe-byte-p-of-aignet-read-aiger-gates
    (implies (acl2::maybe-byte-p nxtbyte)
             (acl2::maybe-byte-p (mv-nth 2 (aignet-read-aiger-gates
                                            idx numgates aignet nxtbyte channel
                                            state)))))

  (def-aignet-preservation-thms aignet-read-aiger-gates)

  (defthm stype-counts-preserved-of-aignet-read-aiger-gates
    (implies (not (equal (stype-fix stype) (gate-stype)))
             (equal (stype-count stype (mv-nth 1 (aignet-read-aiger-gates
                                                  idx numgates aignet nxtbyte
                                                  channel state)))
                    (stype-count stype aignet)))))


;; (def-aignet-frame aignet-read-aiger-gates
;;   :hints (("goal" :induct (aignet-read-aiger-gates
;;                            idx numgates aignet nxtbyte channel state)
;;            :in-theory (disable (:definition aignet-read-aiger-gates))
;;            :expand ((aignet-read-aiger-gates idx numgates aignet nxtbyte channel
;;                                              state))
;;            :do-not-induct t)))

;; (def-aignet-preservation-thms aignet-read-aiger-gates)

;; (defthm num-nodes-of-aignet-read-aiger-gates
;;   (implies (natp (nth *num-nodes* aignet))
;;            (<= (nth *num-nodes* aignet)
;;                (nth *num-nodes* (mv-nth 1 (aignet-read-aiger-gates
;;                                           idx numgates aignet nxtbyte channel
;;                                           state)))))
;;   :rule-classes (:rewrite :linear))

;; (defthm aignet-ris-unconnected-of-aignet-read-aiger-gates
;;   (implies (and (aignet-ris-unconnected k aignet)
;;                 (aignet-well-formedp aignet))
;;            (let ((aignet (mv-nth 1 (aignet-read-aiger-gates idx numgates aignet
;;                                                          nxtbyte channel state))))
;;              (aignet-ris-unconnected k aignet)))
;;   :hints (("goal" :induct t
;;            :in-theory (enable* aignet-frame-thms))))

;; (defthm aignet-ris-unconnected-of-aignet-add-regin
;;   (implies (and (aignet-ris-unconnected k aignet)
;;                 (aignet-idp (id-fix ro) aignet)
;;                 (< (io-id->ionum ro aignet) (nfix k))
;;                 (aignet-well-formedp aignet))
;;            (aignet-ris-unconnected k (aignet-add-regin f ro aignet)))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms
;;                                      aignet-idp)
;;           :induct t)
;;          (and stable-under-simplificationp
;;               '(:use ((:instance aignet-well-formedp-regnum
;;                        (n k)))
;;                 :in-theory (e/d* (aignet-add-regin
;;                                   aignet-add-regin1
;;                                   aignet-idp
;;                                   aignet-unconnected-reg-fixup
;;                                   aignet-frame-thms)
;;                                  (aignet-well-formedp-regnum))))))

;; (defthm aignet-no-outsp-of-aignet-read-aiger-gates
;;   (implies (aignet-no-outsp (nth *num-nodes* aignet) aignet)
;;            (let ((aignet (mv-nth 1 (aignet-read-aiger-gates idx numgates aignet nxtbyte channel
;;                                                          state))))
;;              (implies (equal (nfix k) (nfix (num-nodes aignet)))
;;                       (aignet-no-outsp k aignet))))
;;   :hints(("goal" :induct t
;;           :expand ((aignet-no-outsp k aignet)))))

;; (defthm aignet-no-outsp-of-aignet-add-regin
;;   (implies (and (aignet-no-outsp k aignet)
;;                 (<= (nfix k) (nfix (num-nodes aignet))))
;;            (aignet-no-outsp k (aignet-add-regin f ro aignet)))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms))))


(local
 (defthm aignet-not-output-when-no-outs2
   (implies (and (equal (stype-count (po-stype) aignet2) 0)
                 (equal (stype-count (nxst-stype) aignet2) 0)
                 (<= (nfix id) (node-count aignet2))
                 (aignet-extension-p aignet aignet2))
            (not (equal (ctype (stype (car (lookup-id id aignet))))
                        (out-ctype))))
   :hints(("Goal" :in-theory (enable lookup-id stype-count aignet-extension-p)
           :induct t)
          (and stable-under-simplificationp
               '(:cases ((equal 1 (regp (stype (car aignet))))))))))

(define aignet-aiger-copy-nxsts (idx maxid regarr aignet)
  (declare (type (integer 0 *) idx)
           (type (integer 1 *) maxid)
           (xargs :stobjs (regarr aignet)
                  :guard (and (<= (num-regs aignet) (lits-length regarr))
                              (<= idx (num-regs aignet))
                              (<= maxid (num-nodes aignet))
                              (non-exec
                               (and (equal (num-outs (lookup-id (1- maxid) aignet))
                                           0)
                                    (equal (num-nxsts (lookup-id (1- maxid) aignet))
                                           0))))
                  :measure (nfix (- (nfix (num-regs aignet))
                                    (nfix idx)))
                  :guard-hints(("goal" 
                                :in-theory (enable* aignet-litp aignet-idp)
                                :do-not-induct t))))
  :guard-debug t
  (b* (((when (mbe :logic (zp (- (nfix (num-regs aignet))
                                    (nfix idx)))
                   :exec (int= idx (num-regs aignet))))
        (mv nil aignet))
       (fanin (get-lit idx regarr))
       ((when (<= (lnfix maxid) (lit-id fanin)))
        (mv "PO fanin out of bounds" aignet))
       (ro (regnum->id idx aignet))
       (aignet (aignet-set-nxst fanin ro aignet)))
    (aignet-aiger-copy-nxsts (1+ (lnfix idx)) maxid regarr aignet))

  ///
  (def-aignet-preservation-thms aignet-aiger-copy-nxsts)

  (defthm stype-counts-preserved-of-aignet-aiger-copy-nxsts
    (implies (not (equal (stype-fix stype) (nxst-stype)))
             (equal (stype-count stype (mv-nth 1 (aignet-aiger-copy-nxsts
                                                  idx maxid regarr aignet)))
                    (stype-count stype aignet)))))

  

;; (local (defthm linear-help1
;;          (implies (and (< (id-val (lit-id bla-bla)) maxid)
;;                        (<= maxid (nth *num-nodes* aignet)))
;;                   (< (id-val (lit-id bla-bla)) (nth *num-nodes* aignet)))))


;; (local (in-theory (disable linear-help1)))

;; (defthm aignet-no-outsp-of-aignet-add-out
;;   (implies (and (aignet-no-outsp k aignet)
;;                 (<= (nfix k) (nfix (num-nodes aignet))))
;;            (aignet-no-outsp k (aignet-add-out f aignet)))
;;   :hints(("Goal" :in-theory (enable* aignet-frame-thms))))

(define aignet-aiger-copy-outs (idx maxid outarr outnum aignet)
  (declare (type (integer 0 *) idx)
           (type (integer 1 *) maxid)
           (type (integer 0 *) outnum)
           (xargs :stobjs (outarr aignet)
                  :guard (and (<= outnum (lits-length outarr))
                              (<= maxid (num-nodes aignet))
                              (<= idx outnum)
                              (non-exec
                               (and (equal (num-outs (lookup-id (1- maxid) aignet))
                                           0)
                                    (equal (num-nxsts (lookup-id (1- maxid) aignet))
                                           0))))
                  :measure (nfix (- (nfix outnum)
                                    (nfix idx)))
                  :guard-hints(("goal" 
                                :in-theory (enable* aignet-idp aignet-litp)
                                :do-not-induct t))))
  (b* (((when (mbe :logic (zp (- (nfix outnum)
                                 (nfix idx)))
                   :exec (int= idx outnum)))
        (mv nil aignet))
       (fanin (to-lit (get-lit idx outarr)))
       ((when (<= (lnfix maxid) (lit-id fanin)))
        (mv "Register fanin out of bounds" aignet))
       (aignet (aignet-add-out fanin aignet)))
    (aignet-aiger-copy-outs (1+ (lnfix idx)) maxid outarr outnum aignet))
  ///

  (def-aignet-preservation-thms aignet-aiger-copy-outs)

  (defthm stype-counts-preserved-of-aignet-aiger-copy-outs
    (implies (not (equal (stype-fix stype) (po-stype)))
             (equal (stype-count stype (mv-nth 1 (aignet-aiger-copy-outs
                                                  idx maxid outarr outnum aignet)))
                    (stype-count stype aignet)))))

(local
 (defthm natp-nth-in-nat-list
   (implies (and (nat-listp x)
                 (natp n)
                 (< n (len x)))
            (natp (nth n x)))
   :hints(("Goal" :in-theory (enable nth)))
   :rule-classes (:rewrite :type-prescription)))


(local (in-theory (disable acl2::aiger-parse-header
                           acl2::make-list-ac-redef
                           make-list-ac)))

;; The functions we're using from aiger.lisp take a "buf", which is really just
;; either the next byte of the file or else NIL, so that they can do lookahead.
(define aignet-read-aiger-chan (aignet channel state)
  (declare (xargs :guard (and (symbolp channel)
                              (open-input-channel-p channel :byte state))
                  :guard-debug t
                  :guard-hints (("goal"
                                 :do-not-induct t))))
  (b* (((mv err i l a o b c nxtbyte state)
        (acl2::aiger-parse-header channel nil state))
       ((when err) (mv err aignet state))
       (aignet (aignet-init (+ 1 o b c) (+ 1 l) (+ 1 i) (+ 1 a l o b c) aignet))
       ((local-stobjs outarr regarr)
        (mv err aignet state outarr regarr))
       (outarr (resize-lits (+ o b c) outarr))
       (regarr (resize-lits l regarr))
       (aignet (aignet-make-n-inputs i aignet))
       (aignet (aignet-make-n-regs l aignet))
       ((mv err regarr nxtbyte state)
        (aignet-read-aiger-latches/outs 0 regarr l nxtbyte channel state))
       ((when err) (mv err aignet state outarr regarr))
       ((mv err outarr nxtbyte state)
        (aignet-read-aiger-latches/outs 0 outarr (+ o b c) nxtbyte channel state))
       ((when err) (mv err aignet state outarr regarr))
       ((mv err aignet ?nxtbyte state)
        (aignet-read-aiger-gates 0 a aignet nxtbyte channel state))
       ((when err) (mv err aignet state outarr regarr))
       (- (and (not (= (nfix (num-gates aignet)) a))
               (er hard? 'aignet-read-aiger
                   "Wrong number of gates read: ~x0, should be ~x1~%"
                   (num-gates aignet) a)))
       (maxid (num-nodes aignet))
       ((mv err aignet) (aignet-aiger-copy-nxsts 0 maxid regarr aignet))
       ((when err) (mv err aignet state outarr regarr))
       ((mv err aignet) (aignet-aiger-copy-outs 0 maxid outarr (+ o b c) aignet)))
    (mv err aignet state outarr regarr))

  ///

  (defthm open-input-channel-p1-of-aignet-read-aiger-chan
    (implies (and (state-p1 state)
                  (symbolp channel)
                  (open-input-channel-p1 channel :byte state))
             (let ((state (mv-nth 2 (aignet-read-aiger-chan
                                     aignet channel state))))
               (and (state-p1 state)
                    (open-input-channel-p1 channel :byte state))))))

(define aignet-read-aiger (fname aignet state)
  (declare (xargs :guard (stringp fname)))
  (b* (((mv channel state) (open-input-channel fname :byte state))
       ((when (not channel))
        (mv "Could not open input file" aignet state))
       ((mv err aignet state)
        (aignet-read-aiger-chan aignet channel state))
       (state (close-input-channel channel state)))
    (mv err aignet state)))



 
