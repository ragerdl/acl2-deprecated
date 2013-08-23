; GL - A Symbolic Simulation Framework for ACL2
; Copyright (C) 2008-2013 Centaur Technology
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

(in-package "GL")
(include-book "g-if")
(include-book "g-primitives-help")
(include-book "symbolic-arithmetic-fns")
(include-book "eval-g-base")
;(include-book "tools/with-arith5-help" :dir :system)
(local (include-book "symbolic-arithmetic"))
(local (include-book "eval-g-base-help"))
(local (include-book "hyp-fix-logic"))
(local (include-book "clause-processors/just-expand" :dir :system))
(set-inhibit-warnings "theory")

(defun g-ash-of-numbers (i c)
  (declare (xargs :guard (and (general-numberp i)
                              (general-numberp c))))
  (b* (((mv irn ird iin iid)
        (general-number-components i))
       ((mv crn crd cin cid)
        (general-number-components c))
       ((mv iintp iintp-known)
        (if (equal ird '(t))
            (mv (bfr-or (bfr-=-ss iin nil) (bfr-=-uu iid nil)) t)
          (mv nil nil)))
       ((mv cintp cintp-known)
        (if (equal crd '(t))
            (mv (bfr-or (bfr-=-ss cin nil) (bfr-=-uu cid nil)) t)
          (mv nil nil))))
    (if (and cintp-known iintp-known)
        (mk-g-number
         (rlist-fix
          (bfr-ash-ss 1 (bfr-ite-bss-fn iintp irn nil)
                  (bfr-ite-bss-fn cintp crn nil))))
      (g-apply 'ash (gl-list i c)))))

(in-theory (disable (g-ash-of-numbers)))

(defthm deps-of-g-ash-of-numbers
  (implies (and (not (gobj-depends-on k p i))
                (not (gobj-depends-on k p c))
                (general-numberp i)
                (general-numberp c))
           (not (gobj-depends-on k p (g-ash-of-numbers i c)))))

(local
 (progn
   ;; (defthmd not-integerp-bfr-listp
   ;;   (implies (bfr-listp x)
   ;;            (not (integerp x)))
   ;;   :hints(("Goal" :in-theory (enable bfr-listp))))


   ;; (defthm not-integerp-bfr-ash-ss
   ;;   (not (integerp (bfr-ash-ss place n shamt)))
   ;;   :hints(("Goal" :in-theory (enable bfr-ash-ss))))


   (defthm ash-complex-1
     (implies (not (equal (imagpart n) 0))
              (equal (ash n shamt) (ash 0 shamt)))
     :hints(("Goal" :in-theory (enable ash))))

   (defthm ash-complex-2
     (implies (not (equal (imagpart shamt) 0))
              (equal (ash n shamt) (ash n 0)))
     :hints(("Goal" :in-theory (enable ash))))

   ;; (defthm gobjectp-g-ash-of-numbers
   ;;   (implies (and (gobjectp x)
   ;;                 (general-numberp x)
   ;;                 (gobjectp y)
   ;;                 (general-numberp y))
   ;;            (gobjectp (g-ash-of-numbers x y)))
   ;;   :hints(("Goal" :in-theory (disable general-numberp
   ;;                                      general-number-components))))

   (include-book "arithmetic/top-with-meta" :dir :system)

   (defthm g-ash-of-numbers-correct
     (implies (and (general-numberp x)
                   (general-numberp y))
              (equal (eval-g-base (g-ash-of-numbers x y) env)
                     (ash (eval-g-base x env)
                          (eval-g-base y env))))
     :hints (("goal" :in-theory (e/d* ((:ruleset general-object-possibilities))
                                      (general-numberp
                                       general-number-components))
              :do-not-induct t)))))

(in-theory (disable g-ash-of-numbers))


(def-g-binary-op ash
  (b* ((i-num (if (general-numberp i) i 0))
       (c-num (if (general-numberp c) c 0)))
    (g-ash-of-numbers i-num c-num)))


;; (def-gobjectp-thm ash
;;   :hints `(("goal" :in-theory (e/d* (general-concretep-atom)
;;                                     ((:definition ,gfn)
;;                                      (force)
;;                                      general-concretep-def
;;                                      hyp-fix
;;                                      gobj-fix-when-not-gobjectp
;;                                      gobj-fix-when-gobjectp
;;                                      (:rules-of-class :type-prescription :here)
;;                                      (:ruleset gl-wrong-tag-rewrites)))
;;             :induct (,gfn i c hyp clk)
;;             :do-not-induct t
;;             :expand ((,gfn i c hyp clk)))))

(verify-g-guards
 ash
 :hints `(("Goal" :in-theory (disable ,gfn))))




(local (defthm ash-when-not-numberp
         (and (implies (not (acl2-numberp x))
                       (equal (ash x y) (ash 0 y)))
              (implies (not (acl2-numberp y))
                       (equal (ash x y) (ash x 0))))
         :hints(("Goal" :in-theory (enable ash)))))

(def-gobj-dependency-thm ash
  :hints `(("goal" :in-theory (e/d ((:i ,gfn))
                                   ((:d ,gfn)
                                    gobj-depends-on)))
           (acl2::just-induct-and-expand ,gcall)))

(def-g-correct-thm ash eval-g-base
  :hints
  `(("goal" :in-theory (e/d* (general-concretep-atom
                              (:ruleset general-object-possibilities))
                             ((:definition ,gfn)
                              general-numberp-eval-to-numberp
                              general-boolean-value-correct
                              bool-cond-itep-eval
                              general-consp-car-correct-for-eval-g-base
                              general-consp-cdr-correct-for-eval-g-base
                              boolean-listp
                              components-to-number-alt-def
                              member-equal
                              general-number-components-ev
                              general-concretep-def
                              general-concretep-def
                              rationalp-implies-acl2-numberp
                              ash
                              (:rules-of-class :type-prescription :here))
                             ((:type-prescription bfr-eval)))
     :do-not-induct t)
    (acl2::just-induct-and-expand ,gcall)
    (and stable-under-simplificationp
         (flag::expand-calls-computed-hint
          clause '(eval-g-base)))))
