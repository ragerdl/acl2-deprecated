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

;; mechanism for transforming AIG -> AIGNET -> CNF and showing them
;; equisatisfiable

;; To find the major theorems in this book, search for "induces" -- there are
;; four of them

(in-package "AIGNET")

(include-book "aignet-cnf")
(include-book "aignet-from-aig")
(include-book "aignet-refcounts")
(include-book "centaur/aig/accumulate-nodes-vars" :dir :system)
(local (include-book "centaur/satlink/cnf-basics" :dir :system))

(local (in-theory (e/d (aiglist-to-aignet)
                       (create-sat-lits
                        (create-sat-lits)
                        resize-aignet->sat
                        nth update-nth
                        acl2::make-list-ac-redef
                        make-list-ac
                        aignet-count-refs
                        acl2::nth-with-large-index
                        (aignet-clear)))))


(defun aignet-one-lit->cnf (lit sat-lits aignet)
  (declare (xargs :stobjs (aignet sat-lits)
                  :guard (and (aignet-well-formedp aignet)
                              (aignet-litp lit aignet))))
  (b* (((local-stobjs aignet-refcounts)
        (mv cnf sat-lits aignet-refcounts))
       (sat-lits (sat-lits-empty (num-nodes aignet) sat-lits))
       (aignet-refcounts (resize-u32 (num-nodes aignet) aignet-refcounts))
       (aignet-refcounts (aignet-count-refs 0 aignet-refcounts aignet))
       ((mv sat-lits cnf)
        (aignet-lit->cnf lit t aignet-refcounts sat-lits aignet nil))
       (sat-lit (aignet-lit->sat-lit lit sat-lits)))
    (mv (list* (list sat-lit) ;; lit is true
               cnf)
        sat-lits aignet-refcounts)))

(defthm lit-list-listp-of-aignet-one-lit->cnf
  (satlink::lit-list-listp (mv-nth 0 (aignet-one-lit->cnf lit sat-lits aignet))))

(defthm sat-lits-wfp-of-aignet-one-lit->cnf
  (implies (aignet-well-formedp aignet)
           (sat-lits-wfp (mv-nth 1 (aignet-one-lit->cnf lit sat-lits aignet))
                         aignet))
  :hints(("Goal" :in-theory (enable aignet-one-lit->cnf))))

(defthm aignet-one-lit->cnf-normalize-sat-lits
  (implies (syntaxp (not (equal sat-lits ''nil)))
           (equal (aignet-one-lit->cnf lit sat-lits aignet)
                  (aignet-one-lit->cnf lit nil aignet))))


(local (in-theory (e/d (satlink-eval-lit-of-make-lit-of-lit-var)
                       (satlink::eval-lit-of-make-lit))))

(local (in-theory (disable aignet-invals->vals
                           aignet-regvals->vals
                           aignet-lit->cnf)))

(local (in-theory (disable aignet-vals->invals
                           aignet-vals->regvals
                           aignet-eval)))

(defthm aignet-satisfying-assign-induces-cnf-satisfying-assign
  (b* (((mv cnf sat-lits) (aignet-one-lit->cnf lit sat-lits aignet))
       (aignet-vals (aignet-eval
                     (aignet-invals->vals
                      aignet-invals
                      (aignet-regvals->vals
                       aignet-regvals aignet-vals aignet)
                      aignet)
                     aignet))
       (cnf-vals (aignet->cnf-vals aignet-vals cnf-vals sat-lits aignet)))
    (implies (and (aignet-well-formedp aignet)
                  (aignet-litp lit aignet)
                  (sat-lits-wfp sat-lits aignet))
             (equal (satlink::eval-formula cnf cnf-vals)
                    (lit-eval lit aignet-invals aignet-regvals aignet))))
  :hints(("Goal" :in-theory (e/d ()
                                 (cnf-for-aignet-implies-cnf-sat-when-lit-sat))
          :use ((:instance cnf-for-aignet-implies-cnf-sat-when-lit-sat
                 (aignet-vals (aignet-invals->vals
                               aignet-invals
                               (aignet-regvals->vals
                                aignet-regvals aignet-vals aignet)
                               aignet))
                 (cnf-vals cnf-vals)
                 (cnf (cdr (mv-nth 0 (aignet-one-lit->cnf lit sat-lits aignet))))
                 (sat-lits (mv-nth 1 (aignet-one-lit->cnf lit sat-lits aignet))))))))




(defthm cnf-satisfying-assign-induces-aignet-satisfying-assign
  (b* (((mv cnf sat-lits) (aignet-one-lit->cnf lit sat-lits aignet))
       (aignet-vals (resize-bits (num-nodes aignet) (acl2::create-bitarr)))
       (aignet-vals (cnf->aignet-vals aignet-vals cnf-vals sat-lits aignet)))
    (implies (and (aignet-well-formedp aignet)
                  (aignet-litp lit aignet)
                  (equal (satlink::eval-formula cnf cnf-vals) 1))
             (equal (lit-eval lit
                              (aignet-vals->invals nil aignet-vals aignet)
                              (aignet-vals->regvals nil aignet-vals aignet)
                              aignet)
                    1)))
  :hints (("goal" :use ((:instance
                         cnf-for-aignet-implies-lit-sat-when-cnf-sat
                         (cnf (cdr (mv-nth 0 (aignet-one-lit->cnf lit sat-lits aignet))))
                         (sat-lits (mv-nth 1 (aignet-one-lit->cnf lit sat-lits aignet)))
                         (aignet-vals (resize-bits (num-nodes aignet) (acl2::create-bitarr)))
                         (cnf-vals cnf-vals)
                         (aignet-invals nil) (aignet-regvals nil)))
           :in-theory (e/d ()
                           (aignet-lit->cnf
                            cnf-for-aignet-implies-lit-sat-when-cnf-sat)))))





(in-theory (disable aignet-one-lit->cnf))


(defthm good-varmap-p-of-nil
  (good-varmap-p nil x)
  :hints(("Goal" :in-theory (enable good-varmap-p))))

(defun aig->cnf (aig sat-lits aignet)
  (declare (xargs :stobjs (aignet sat-lits)))
  (b* (((local-stobjs strash)
        (mv cnf lit vars sat-lits aignet strash))
       (aiglist (list aig))
       (vars (acl2::aig-vars-unordered-list aiglist))
       (aignet (aignet-clear aignet))
       ((mv varmap aignet) (make-varmap vars nil nil aignet))
       (strash (strashtab-init 100 nil nil strash))
       ((mv lits strash aignet)
        (aiglist-to-aignet-top aiglist varmap strash
                               (mk-gatesimp 4 t) aignet))
       (aignet-lit (car lits))
       ((mv cnf sat-lits)
        (aignet-one-lit->cnf aignet-lit sat-lits aignet)))
    (mv cnf aignet-lit vars sat-lits aignet strash)))

(defthm lit-list-listp-of-aig->cnf
  (satlink::lit-list-listp (mv-nth 0 (aig->cnf aig sat-lits aignet))))


(defun env-to-in-vals (vars env)
  (declare (xargs :guard t))
  (if (atom vars)
      nil
    (cons (if (acl2::aig-env-lookup (car vars) env) 1 0)
          (env-to-in-vals (cdr vars) env))))

(defun satisfying-assign-for-env (env vars sat-lits aignet cnf-vals)
  (declare (xargs :stobjs (sat-lits aignet cnf-vals)
                  :guard (and (aignet-well-formedp aignet)
                              (sat-lits-wfp sat-lits aignet))))
  (b* ((in-vals (env-to-in-vals vars env))
       (cnf-vals (resize-bits 0 cnf-vals))
       (cnf-vals (resize-bits (sat-next-var sat-lits) cnf-vals))
       (cnf-vals (non-exec
                  (b* ((aignet-vals (aignet-invals->vals in-vals nil aignet))
                       (aignet-vals (aignet-eval aignet-vals aignet))
                       (cnf-vals (aignet->cnf-vals aignet-vals cnf-vals sat-lits aignet)))
                    cnf-vals))))
    cnf-vals))


(defthm lookup-in-make-varmap-iff
  (iff (hons-assoc-equal v (mv-nth 0 (make-varmap vars nil varmap0 aignet0)))
       (or (member v vars)
           (hons-assoc-equal v varmap0)))
  :hints(("Goal" :in-theory (enable make-varmap))))



(defun lst-position (x lst)
  (cond ((endp lst) nil)
        ((equal x (car lst)) 0)
        (t (let ((rst (lst-position x (cdr lst))))
             (and rst (+ 1 rst))))))

(defthm lst-position-iff-member
  (iff (lst-position x lst)
       (member x lst)))

(local (include-book "arithmetic/top-with-meta" :dir :system))

(defthm lookup-in-make-varmap
  (implies (and (no-duplicatesp vars)
                (not (intersectp-equal vars (alist-keys varmap0)))
                (aignet-well-formedp aignet0))
           (equal (cdr (hons-assoc-equal v (mv-nth 0 (make-varmap vars nil varmap0
                                                                  aignet0))))
                  (if (member v vars)
                      (mk-lit (to-id (+ (lst-position v vars)
                                        (num-nodes aignet0)))
                              0)
                    (cdr (hons-assoc-equal v varmap0)))))
  :hints(("Goal" :in-theory (enable make-varmap
                                    intersectp-equal
                                    alist-keys)
          :induct (make-varmap vars nil varmap0 aignet0))))

(in-theory (enable (:induction make-varmap)))
(def-aignet-preservation-thms make-varmap)

(defthm num-ins-of-make-varmap
  (implies (aignet-well-formedp aignet)
           (equal (nth *num-ins* (mv-nth 1 (make-varmap vars nil acc aignet)))
                  (+ (nth *num-ins* aignet)
                     (len vars))))
  :hints(("Goal" :in-theory (enable make-varmap))))

(defthm num-regs-of-make-varmap
  (implies (aignet-well-formedp aignet)
           (equal (nth *num-regs* (mv-nth 1 (make-varmap vars nil acc aignet)))
                  (nth *num-regs* aignet)))
  :hints(("Goal" :in-theory (enable* make-varmap aignet-frame-thms))))


(encapsulate nil
  (local
   (defthm aignet-idp-in-make-varmap
     (implies (and (aignet-well-formedp aignet0)
                   (idp id)
                   (force (< (id-val id) (+ (num-nodes aignet0)
                                            (len vars)))))
              (aignet-idp id (mv-nth 1 (make-varmap vars regp varmap0 aignet0))))
     :hints(("Goal" :in-theory (enable make-varmap)
             :induct (make-varmap vars regp varmap0 aignet0))
            (and stable-under-simplificationp
                 '(:in-theory (enable aignet-idp))))))

  (local
   (defthm aignet-idp-of-aignet-add-reg
     (implies (and (aignet-well-formedp aignet)
                   (idp id)
                   (<= (id-val id) (num-nodes aignet)))
              (aignet-idp id (mv-nth 1 (Aignet-add-reg aignet))))
     :hints(("Goal" :in-theory (enable aignet-add-reg
                                       aignet-idp)))))

  (local
   (defthm aignet-idp-of-aignet-add-in
     (implies (and (aignet-well-formedp aignet)
                   (idp id)
                   (<= (id-val id) (num-nodes aignet)))
              (aignet-idp id (mv-nth 1 (Aignet-add-in aignet))))
     :hints(("Goal" :in-theory (enable aignet-add-in
                                       aignet-idp)))))

  (local
   (defthm node-type-in-make-varmap
     (implies (and (aignet-well-formedp aignet0)
                   (idp id)
                   (<= (num-nodes aignet0) (id-val id))
                   (force (< (id-val id) (+ (num-nodes aignet0)
                                            (len vars)))))
              (let ((node (nth-node
                           id
                           (nth *nodesi*
                                (mv-nth 1 (make-varmap vars regp varmap0
                                                       aignet0))))))
                (and (equal (node->type node) (in-type))
                     (equal (node->regp node) (if regp 1 0)))))
     :hints(("Goal" :in-theory (enable make-varmap)
             :induct (make-varmap vars regp varmap0 aignet0))
            (and stable-under-simplificationp
                 '(:in-theory (enable aignet-add-reg
                                      aignet-add-in
                                      mk-in-node
                                      mk-reg-node))))))

  (defthm id-eval-of-make-varmap-input
    (implies (and (aignet-well-formedp aignet0)
                  (idp id)
                  (<= (num-nodes aignet0) (id-val id))
                  (< (id-val id) (+ (num-nodes aignet0)
                                    (len vars))))
             (equal (id-eval id in-vals reg-vals
                             (mv-nth 1 (make-varmap vars nil varmap0 aignet0)))
                    (bfix (nth (+ (id-val id)
                                  (- (num-nodes aignet0))
                                  (num-ins aignet0))
                               in-vals))))
    :hints(("Goal" :in-theory (enable make-varmap)
            :induct (make-varmap vars nil varmap0 aignet0))
           (and stable-under-simplificationp
                '(:expand ((:free (aignet)
                            (id-eval id in-vals reg-vals aignet)))))))

  (defthm lit-eval-of-make-varmap-input
    (implies (and (aignet-well-formedp aignet0)
                  (<= (num-nodes aignet0)
                      (id-val (lit-id lit)))
                  (< (id-val (lit-id lit))
                     (+ (num-nodes aignet0)
                        (len vars))))
             (equal (lit-eval lit in-vals reg-vals
                              (mv-nth 1 (make-varmap vars nil varmap0
                                                     aignet0)))
                    (b-xor (lit-neg lit)
                           (nth (+ (id-val (lit-id lit))
                                   (- (num-nodes aignet0))
                                   (num-ins aignet0))
                                in-vals))))
    :hints(("Goal"
            :expand ((:free (aignet)
                      (lit-eval lit in-vals reg-vals aignet)))
            :do-not-induct t))))






(local (defthm intersectp-equal-of-switch
         (implies (and (no-duplicatesp a)
                       (not (intersectp-equal a b)))
                  (not (intersectp-equal (cdr a)
                                          (cons (car a) b))))
         :hints(("Goal" :in-theory (enable intersectp-equal)))))


(defthm id-eval-of-aignet-add-in
  (equal (id-eval (to-id (nth *num-nodes* aignet))
                  in-vals reg-vals
                  (mv-nth 1 (aignet-add-in aignet)))
         (bfix (nth (num-ins aignet) in-vals)))
  :hints(("Goal" :in-theory (enable id-eval))))

(defthm id-eval-of-aignet-add-reg
  (equal (id-eval (to-id (nth *num-nodes* aignet))
                  in-vals reg-vals
                  (mv-nth 1 (aignet-add-reg aignet)))
         (bfix (nth (num-regs aignet) reg-vals)))
  :hints(("Goal" :in-theory (enable id-eval))))

(defthm lit-eval-of-aignet-add-in
  (implies (equal (id-val (lit-id lit))
                  (nfix (num-nodes aignet)))
           (equal (lit-eval lit in-vals reg-vals
                            (mv-nth 1 (aignet-add-in aignet)))
                  (b-xor (lit-neg lit)
                         (nth (num-ins aignet) in-vals))))
  :hints(("Goal" :in-theory (e/d (lit-eval)
                                 (id-eval-of-aignet-add-in))
          :use ((:instance id-eval-of-aignet-add-in)))))

(defthm lit-eval-of-aignet-add-reg
  (implies (equal (id-val (lit-id lit))
                  (nfix (num-nodes aignet)))
           (equal (lit-eval lit in-vals reg-vals
                            (mv-nth 1 (aignet-add-reg aignet)))
                  (b-xor (lit-neg lit)
                         (nth (num-regs aignet) reg-vals))))
  :hints(("Goal" :in-theory (e/d (lit-eval)
                                 (id-eval-of-aignet-add-reg))
          :use ((:instance id-eval-of-aignet-add-reg)))))



(defthm aig-env-lookup-of-aignet-eval-to-env-of-make-varmap
  (implies (and (aignet-well-formedp aignet0)
                (member v vars)
                (equal (len (alist-keys varmap0))
                       (num-ins aignet0))
                (no-duplicatesp-equal vars)
                (not (intersectp-equal vars (alist-keys varmap0))))
           (mv-let (varmap aignet)
             (make-varmap vars nil varmap0 aignet0)
             (equal (acl2::aig-env-lookup
                     v (aignet-eval-to-env
                        varmap
                        in-vals reg-vals aignet))
                    (equal (nth (+ (num-ins aignet0)
                                   (lst-position v vars))
                                in-vals)
                           1))))
  :hints (("goal" :induct (make-varmap vars nil varmap0 aignet0)
           :in-theory (e/d (make-varmap
                            aignet-eval-to-env
                            alist-keys)
                           (acl2::aig-env-lookup)))
          (and stable-under-simplificationp
               '(:in-theory (e/d (make-varmap
                                  aignet-eval-to-env
                                  alist-keys))))))



(defthm nth-in-env-to-in-vals
  (implies (< (nfix n) (len vars))
           (equal (nth n (env-to-in-vals vars env))
                  (if (acl2::aig-env-lookup (nth n vars) env) 1 0)))
  :hints(("Goal" :in-theory (enable nth env-to-in-vals))))

(defthm lst-position-less-when-member
  (implies (member v vars)
           (< (lst-position v vars) (len vars))))

(defthm nth-lst-position
  (implies (member v vars)
           (equal (nth (lst-position v vars) vars) v))
  :hints(("Goal" :in-theory (enable nth))))

(defthm lst-position-type-when-member
  (implies (member v vars)
           (natp (lst-position v vars)))
  :rule-classes :type-prescription)


(defthm aig-eval-of-aignet-eval-to-env-of-make-varmap
  (implies (and (aignet-well-formedp aignet0)
                (subsetp-equal (aig-vars aig) vars)
                (equal (len (alist-keys varmap0))
                       (num-ins aignet0))
                (no-duplicatesp-equal vars)
                (not (intersectp-equal vars (alist-keys varmap0))))
           (mv-let (varmap aignet)
             (make-varmap vars nil varmap0 aignet0)
             (equal (aig-eval aig
                              (aignet-eval-to-env
                               varmap
                               (env-to-in-vals
                                (revappend (alist-keys varmap0) vars)
                                env)
                               nil
                               aignet))
                    (aig-eval aig env))))
  :hints(("Goal" :in-theory (e/d (aig-eval)
                                 (lookup-in-aignet-eval-to-env
                                  acl2::aig-env-lookup
                                  acl2::revappend-removal))
          :induct (aig-eval aig env))))

(defthm aig-eval-of-aignet-eval-to-env-of-make-varmap-init
  (implies (and (aignet-well-formedp aignet0)
                (double-rewrite
                 (subsetp-equal (aig-vars aig) vars))
                (no-duplicatesp-equal vars)
                (equal (num-ins aignet0) 0))
           (mv-let (varmap aignet)
             (make-varmap vars nil nil aignet0)
             (equal (aig-eval aig
                              (aignet-eval-to-env
                               varmap
                               (env-to-in-vals vars env)
                               nil
                               aignet))
                    (aig-eval aig env))))
  :hints(("Goal" :in-theory (e/d (aig-eval)
                                 (lookup-in-aignet-eval-to-env
                                  acl2::aig-env-lookup
                                  acl2::revappend-removal
                                  aig-eval-of-aignet-eval-to-env-of-make-varmap))
          :use ((:instance aig-eval-of-aignet-eval-to-env-of-make-varmap
                 (varmap0 nil))))))



(defthm aig-satisfying-assign-induces-aig->cnf-satisfying-assign
  (b* (((mv cnf ?lit vars sat-lits aignet) (aig->cnf aig sat-lits aignet))
       (cnf-vals (satisfying-assign-for-env env vars sat-lits aignet cnf-vals)))
    (equal (satlink::eval-formula cnf cnf-vals)
           (if (aig-eval aig env) 1 0)))
  :hints (("goal" :use ((:instance
                         aignet-satisfying-assign-induces-cnf-satisfying-assign
                         (aignet (mv-nth 4 (aig->cnf aig sat-lits aignet)))
                         (lit (mv-nth 1 (aig->cnf aig sat-lits aignet)))
                         (aignet-invals
                          (env-to-in-vals
                           (mv-nth 2 (aig->cnf aig sat-lits aignet))
                           env))
                         (aignet-regvals nil)
                         (aignet-vals nil)
                         (cnf-vals (resize-bits (sat-next-var
                                                 (mv-nth 3 (aig->cnf aig sat-lits aignet)))
                                                nil))))
           :in-theory (e/d* (aignet-regvals->vals
                             aignet-regvals->vals-iter
                             aignet-frame-thms)
                            (aignet-satisfying-assign-induces-cnf-satisfying-assign)))))

(defthm aignet-well-formedp-of-aig->cnf
  (aignet-well-formedp (mv-nth 4 (aig->cnf aig sat-lits aignet))))

(defthm sat-lits-wfp-of-aig->cnf
  (sat-lits-wfp (mv-nth 3 (aig->cnf aig sat-lits aignet))
                (mv-nth 4 (aig->cnf aig sat-lits aignet))))


(local (defthm len-equal-0
         (equal (equal (len x) 0)
                (atom x))))

(defun aignet-vals-make-env (vars innum aignet-vals aignet)
  (Declare (xargs :stobjs (aignet-vals aignet)
                  :guard (and (aignet-well-formedp aignet)
                              (bitarr-sizedp aignet-vals aignet)
                              (natp innum)
                              (<= (+ (len vars) innum) (num-ins aignet)))
                  :guard-hints (("goal" :use ((:instance
                                               id-in-bounds-when-memo-tablep
                                               (arr aignet-vals)
                                               (n (innum->id innum aignet))))
                                 :in-theory (disable id-in-bounds-when-memo-tablep)))))
  (if (atom vars)
      nil
    (cons (cons (car vars)
                (equal 1 (get-id->bit (innum->id innum aignet) aignet-vals)))
          (aignet-vals-make-env (cdr vars) (1+ (lnfix innum)) aignet-vals aignet))))





(defthm memo-tablep-cnf->aignet-vals-iter
  (implies (memo-tablep aignet-vals aignet)
           (memo-tablep
            (cnf->aignet-vals-iter n aignet-vals cnf-vals sat-lits aignet1)
            aignet))
  :hints(("Goal" :in-theory (enable cnf->aignet-vals-iter))))

(defthm memo-tablep-cnf->aignet-vals
  (implies (memo-tablep aignet-vals aignet)
           (memo-tablep
            (cnf->aignet-vals aignet-vals cnf-vals sat-lits aignet1)
            aignet))
  :hints(("Goal" :in-theory (enable cnf->aignet-vals))))


(defun aig-cnf-vals->env (cnf-vals vars sat-lits aignet)
  (declare (xargs :stobjs (cnf-vals sat-lits aignet)
                  :guard (and (aignet-well-formedp aignet)
                              (sat-lits-wfp sat-lits aignet)
                              (<= (len vars) (num-ins aignet)))))
  (b* (((local-stobjs aignet-vals)
        (mv env aignet-vals))
       (aignet-vals (resize-bits (num-nodes aignet) aignet-vals))
       (aignet-vals (cnf->aignet-vals aignet-vals cnf-vals sat-lits
                                      aignet))
       (env (aignet-vals-make-env vars 0 aignet-vals aignet)))
    (mv env aignet-vals)))


(defthm lookup-in-aignet-vals-make-env
  (equal (acl2::aig-env-lookup v (aignet-vals-make-env vars innum aignet-vals
                                                       aignet))
         (or (not (member v vars))
             (equal 1 (get-id->bit (innum->id (+ (nfix innum)
                                                 (lst-position v vars))
                                              aignet)
                                   aignet-vals))))
  :hints(("Goal" :in-theory (enable acl2::aig-env-lookup))))

(defthm aignet-vals-make-env-of-extension
  (implies (and (aignet-extension-binding)
                (aignet-extension-p new-aignet orig-aignet)
                (<= (+ (nfix innum) (len vars)) (num-ins orig-aignet))
                (aignet-well-formedp orig-aignet)
                (aignet-well-formedp new-aignet))
           (equal (aignet-vals-make-env vars innum aignet-vals new-aignet)
                  (aignet-vals-make-env vars innum aignet-vals orig-aignet))))

(defthm aignet-vals-in-vals-iter-of-extension
  (implies (and (aignet-extension-binding)
                (aignet-extension-p new-aignet orig-aignet)
                (equal (num-ins new-aignet) (num-ins orig-aignet))
                (aignet-well-formedp orig-aignet)
                (aignet-well-formedp new-aignet))
           (bits-equiv (aignet-vals->invals in-vals aignet-vals new-aignet)
                       (aignet-vals->invals in-vals aignet-vals orig-aignet)))
  :hints ((and stable-under-simplificationp
               `(:expand (,(car (last clause)))))))

(defthm aignet-vals-reg-vals-iter-of-extension
  (implies (and (aignet-extension-binding)
                (aignet-extension-p new-aignet orig-aignet)
                (equal (num-regs new-aignet) (num-regs orig-aignet))
                (aignet-well-formedp orig-aignet)
                (aignet-well-formedp new-aignet))
           (bits-equiv (aignet-vals->regvals reg-vals aignet-vals new-aignet)
                       (aignet-vals->regvals reg-vals aignet-vals orig-aignet)))
  :hints ((and stable-under-simplificationp
               `(:expand (,(car (last clause)))))))

(local (defthmd equal-1-rewrite-under-congruence
         (implies (and (equal y (double-rewrite (bfix x)))
                       (syntaxp ;(prog2$ (cw "x: ~x0~%y: ~x1~%" x y)
                        (and (not (equal x y))
                             (not (equal y `(acl2::bfix$inline ,x))))))
                  (equal (equal x 1)
                         (equal y 1)))))

(defthm aignet-eval-to-env-of-extension
  (implies (and (aignet-extension-binding)
                (aignet-extension-p new-aignet orig-aignet)
                (good-varmap-p varmap orig-aignet))
           (equal (aignet-eval-to-env varmap in-vals reg-vals new-aignet)
                  (aignet-eval-to-env varmap in-vals reg-vals orig-aignet)))
  :hints(("Goal" :in-theory (enable good-varmap-p))))


(encapsulate nil
  (local (in-theory (disable aignet-vals-make-env
                             no-duplicatesp-equal
                             subsetp-equal
                             make-varmap acl2::aig-env-lookup
                             aignet-eval-to-env)))
  (defthm aig-eval-of-aignet-vals-make-env
    (implies (and (aignet-well-formedp aignet)
                  (equal (num-ins aignet) 0)
                  (no-duplicatesp-equal vars)
                  (double-rewrite (subsetp-equal (aig-vars aig) vars)))
             (mv-let (varmap new-aignet)
               (make-varmap vars nil nil aignet)
               (equal (aig-eval aig
                                (aignet-vals-make-env
                                 vars 0 aignet-vals new-aignet))
                      (aig-eval aig
                                (aignet-eval-to-env
                                 varmap
                                 (aignet-vals->invals nil aignet-vals new-aignet)
                                 (aignet-vals->regvals nil aignet-vals new-aignet)
                                 new-aignet)))))
    :hints(("Goal" :in-theory (e/d (aig-eval
                                    equal-1-rewrite-under-congruence))
            :induct t))))

(local (in-theory (enable (:induction aig-to-aignet))))


(defcong bits-equiv equal (aignet-eval-to-env varmap in-vals reg-vals aignet) 2
  :hints(("Goal" :in-theory (enable aignet-eval-to-env))))

(defcong bits-equiv equal (aignet-eval-to-env varmap in-vals reg-vals aignet) 3
  :hints(("Goal" :in-theory (enable aignet-eval-to-env))))

(defthm cnf-satisfying-assign-induces-aig-satisfying-assign
    (b* (((mv cnf ?lit vars sat-lits aignet)
          (aig->cnf aig sat-lits aignet))
         (env (aig-cnf-vals->env cnf-vals vars sat-lits aignet)))
      (implies (equal (satlink::eval-formula cnf cnf-vals) 1)
               (aig-eval aig env)))
    :hints(("Goal" :in-theory (e/d (nth-aignet-of-aig-to-aignet)
                                   (cnf-satisfying-assign-induces-aignet-satisfying-assign
                                    b-and b-ior b-xor b-not))
            :use ((:instance
                   cnf-satisfying-assign-induces-aignet-satisfying-assign
                   (lit (mv-nth 1 (aig->cnf aig sat-lits aignet)))
                   (aignet (mv-nth 4 (aig->cnf aig sat-lits aignet)))))
            :do-not-induct t)))

(defthm len-vars-of-aig->cnf
  (equal (len (mv-nth 2 (aig->cnf aig sat-lits aignet)))
         (nth *num-ins* (mv-nth 4 (aig->cnf aig sat-lits aignet))))
  :hints(("Goal" :in-theory (enable* aig->cnf
                                     aignet-frame-thms))))

(in-theory (disable aig->cnf
                    aig-cnf-vals->env
                    satisfying-assign-for-env))
