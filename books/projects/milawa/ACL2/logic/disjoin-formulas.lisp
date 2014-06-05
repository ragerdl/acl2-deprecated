;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           __    __        __    __                                        ;;
;;          /  \  /  \      (__)  |  |    ____   ___      __    ____         ;;
;;         /    \/    \      __   |  |   / _  |  \  \ __ /  /  / _  |        ;;
;;        /  /\    /\  \    |  |  |  |  / / | |   \  '  '  /  / / | |        ;;
;;       /  /  \__/  \  \   |  |  |  |  \ \_| |    \  /\  /   \ \_| |        ;;
;;      /__/          \__\  |__|  |__|   \____|     \/  \/     \____|        ;;
;; ~ ~~ \  ~ ~  ~_~~ ~/~ /~ | ~|~ | ~| ~ /~_ ~|~ ~  ~\  ~\~ ~  ~ ~  |~~    ~ ;;
;;  ~ ~  \~ \~ / ~\~ / ~/ ~ |~ | ~|  ~ ~/~/ | |~ ~~/ ~\/ ~~ ~ / / | |~   ~   ;;
;; ~ ~  ~ \ ~\/ ~  \~ ~/ ~~ ~__|  |~ ~  ~ \_~  ~  ~  .__~ ~\ ~\ ~_| ~  ~ ~~  ;;
;;  ~~ ~  ~\  ~ /~ ~  ~ ~  ~ __~  |  ~ ~ \~__~| ~/__~   ~\__~ ~~___~| ~ ~    ;;
;; ~  ~~ ~  \~_/  ~_~/ ~ ~ ~(__~ ~|~_| ~  ~  ~~  ~  ~ ~~    ~  ~   ~~  ~  ~  ;;
;;                                                                           ;;
;;            A   R e f l e c t i v e   P r o o f   C h e c k e r            ;;
;;                                                                           ;;
;;       Copyright (C) 2005-2009 by Jared Davis <jared@cs.utexas.edu>        ;;
;;                                                                           ;;
;; This program is free software; you can redistribute it and/or modify it   ;;
;; under the terms of the GNU General Public License as published by the     ;;
;; Free Software Foundation; either version 2 of the License, or (at your    ;;
;; option) any later version.                                                ;;
;;                                                                           ;;
;; This program is distributed in the hope that it will be useful, but       ;;
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABIL-  ;;
;; ITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public      ;;
;; License for more details.                                                 ;;
;;                                                                           ;;
;; You should have received a copy of the GNU General Public License along   ;;
;; with this program (see the file COPYING); if not, write to the Free       ;;
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA    ;;
;; 02110-1301, USA.                                                          ;;
;;                                                                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MILAWA")
(include-book "formulas")
(set-verify-guards-eagerness 2)
(set-case-split-limitations nil)
(set-well-founded-relation ord<)
(set-measure-function rank)


;; (logic.disjoin-formulas x) takes a non-empty list of formulas, [A1,...,An],
;; and produces their disjunction A1 v A2 v ... v An.

(defund logic.disjoin-formulas (x)
  (declare (xargs :guard (and (logic.formula-listp x)
                              (consp x))))
  (if (consp x)
      (if (consp (cdr x))
          (logic.por (car x)
               (logic.disjoin-formulas (cdr x)))
        (car x))
    nil))

(defthm logic.disjoin-formulas-when-singleton-list
  (implies (and (consp x)
                (not (consp (cdr x))))
           (equal (logic.disjoin-formulas x)
                  (car x)))
  :hints(("Goal" :in-theory (enable logic.disjoin-formulas))))

(defthm logic.disjoin-formulas-of-cons-onto-consp
  (implies (consp x)
           (equal (logic.disjoin-formulas (cons a x))
                  (logic.por a (logic.disjoin-formulas x))))
  :hints(("Goal" :in-theory (enable logic.disjoin-formulas))))

(defthm logic.disjoin-formulas-of-list-fix
  (equal (logic.disjoin-formulas (list-fix x))
         (logic.disjoin-formulas x))
  :hints(("Goal" :in-theory (e/d (logic.disjoin-formulas)
                                 ;; wow yucky!
                                 (forcing-equal-of-logic.por-rewrite
                                  forcing-equal-of-logic.por-rewrite-two)))))

(defthm forcing-logic.formulap-of-logic.disjoin-formulas
  (implies (force (consp x))
           (equal (logic.formulap (logic.disjoin-formulas x))
                  (logic.formula-listp x)))
  :hints(("Goal"
          :in-theory (enable logic.disjoin-formulas
                             logic.formulap-of-logic.por-expensive)
          :induct (logic.disjoin-formulas x))))

(defthm forcing-logic.formula-atblp-of-logic.disjoin-formulas
  (implies (force (consp x))
           (equal (logic.formula-atblp (logic.disjoin-formulas x) atbl)
                  (logic.formula-list-atblp x atbl)))
  :hints(("Goal"
          :in-theory (enable logic.disjoin-formulas
                             logic.formula-atblp-of-logic.por-expensive)
          :induct (logic.disjoin-formulas x))))

(defthm logic.formula-listp-when-logic.formulap-of-logic.disjoin-formulas-free
  (implies (and (equal (logic.disjoin-formulas as) x)
                (logic.formulap x))
           (equal (logic.formula-listp as)
                  t)))

(defthm logic.formula-list-atblp-when-logic.formula-atblp-of-logic.disjoin-formulas-free
  (implies (and (equal (logic.disjoin-formulas as) x)
                (logic.formula-atblp x atbl))
           (equal (logic.formula-list-atblp as atbl)
                  t)))

(defthm forcing-logic.fmtype-of-logic.disjoin-formulas
  (implies (force (logic.formula-listp x))
           (equal (logic.fmtype (logic.disjoin-formulas x))
                  (if (consp (cdr x))
                      'por*
                    (logic.fmtype (car x)))))
  :hints(("Goal" :in-theory (enable logic.disjoin-formulas))))

(defthm forcing-logic.vlhs-of-logic.disjoin-formulas
  (implies (force (logic.formula-listp x))
           (equal (logic.vlhs (logic.disjoin-formulas x))
                  (if (consp (cdr x))
                      (car x)
                    (logic.vlhs (car x)))))
  :hints(("Goal" :in-theory (enable logic.disjoin-formulas))))

(defthm forcing-logic.vrhs-of-logic.disjoin-formulas
  (implies (force (logic.formula-listp x))
           (equal (logic.vrhs (logic.disjoin-formulas x))
                  (if (consp (cdr x))
                      (logic.disjoin-formulas (cdr x))
                    (logic.vrhs (car x)))))
  :hints(("Goal" :in-theory (enable logic.disjoin-formulas))))


(defthm forcing-logic.fmtype-of-logic.disjoin-formulas-free
  ;; The odd syntaxp restriction prevents obscure rewriting loops that can be
  ;; formed if free is ever instantiated with (car x).  Before adding this
  ;; restriction, we actually found such a loop in Milawa's proof of
  ;; equal-of-logic.disjoin-formulas-and-logic.disjoin-formulas-when-same-len.
  (implies (and (equal free (logic.disjoin-formulas x))
                (force (logic.formula-listp x))
                (ACL2::syntaxp (not (equal free '(car x)))))
           (equal (logic.fmtype free)
                  (if (consp (cdr x))
                      'por*
                    (logic.fmtype (car x))))))

(defthm forcing-logic.vlhs-of-logic.disjoin-formulas-free
  (implies (and (equal free (logic.disjoin-formulas x))
                (force (logic.formula-listp x)))
           (equal (logic.vlhs free)
                  (if (consp (cdr x))
                      (car x)
                    (logic.vlhs (car x))))))

(defthm forcing-logic.vrhs-of-logic.disjoin-formulas-free
  (implies (and (equal free (logic.disjoin-formulas x))
                (force (logic.formula-listp x)))
           (equal (logic.vrhs free)
                  (if (consp (cdr x))
                      (logic.disjoin-formulas (cdr x))
                    (logic.vrhs (car x))))))



(defthm forcing-logic.disjoin-formulas-of-two-element-list
  (implies (and (force (logic.formulap x))
                (force (logic.formulap y))
                (not (consp z)))
           (equal (logic.disjoin-formulas (list* x y z))
                  (logic.por x y))))

(defthm equal-of-logic.disjoin-formulas-and-logic.disjoin-formulas-when-same-len
  (implies (and (equal (len x) (len y))
                (force (logic.formula-listp x))
                (force (logic.formula-listp y)))
           (equal (equal (logic.disjoin-formulas x)
                         (logic.disjoin-formulas y))
                  (equal (list-fix x)
                         (list-fix y))))
  :hints(("Goal"
          :induct (cdr-cdr-induction x y)
          :in-theory (enable logic.disjoin-formulas))))




(defprojection
  :list (logic.disjoin-each-formula-list x)
  :element (logic.disjoin-formulas x)
  :guard (and (logic.formula-list-listp x)
              (cons-listp x))
  :nil-preservingp t)

(defthm forcing-logic.formula-listp-of-logic.disjoin-each-formula-list
  (implies (force (cons-listp x))
           (equal (logic.formula-listp (logic.disjoin-each-formula-list x))
                  (logic.formula-list-listp x)))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm forcing-logic.formula-list-atblp-of-logic.disjoin-each-formula-list
  (implies (force (cons-listp x))
           (equal (logic.formula-list-atblp (logic.disjoin-each-formula-list x) atbl)
                  (logic.formula-list-list-atblp x atbl)))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm logic.disjoin-each-formula-list-of-listify-each
  (equal (logic.disjoin-each-formula-list (listify-each x))
         (list-fix x))
  :hints(("Goal" :induct (cdr-induction x))))



;; (encapsulate
;;  ()
;;  (local (in-theory (disable (:executable-counterpart ACL2::force))))

;;  (defthmd logic.formula-atblp-of-logic.por-left-refution-dangerous
;;    (implies (and (logic.formulap x)
;;                  (logic.formulap y)
;;                  (not (logic.formula-atblp y atbl)))
;;             (equal (logic.formula-atblp (logic.por x y) atbl)
;;                    nil))
;;    :hints(("Goal" :in-theory (enable logic.formula-atblp))))

;;  (defthmd logic.formula-atblp-of-logic.por-right-refution-dangerous
;;    (implies (and (logic.formulap x)
;;                  (logic.formulap y)
;;                  (not (logic.formula-atblp x atbl)))
;;             (equal (logic.formula-atblp (logic.por x y) atbl)
;;                    nil))
;;    :hints(("Goal" :in-theory (enable logic.formula-atblp))))

;;  (defthmd logic.formula-atblp-of-disjoin-formulas-refutation-dangerous
;;    (implies (and (logic.formula-listp x)
;;                  (not (logic.formula-list-atblp x atbl)))
;;             (equal (logic.formula-atblp (logic.disjoin-formulas x) atbl)
;;                    nil))
;;    :hints(("Goal" :in-theory (enable logic.disjoin-formulas
;;                                      logic.formula-atblp-of-logic.por-left-refution-dangerous
;;                                      logic.formula-atblp-of-logic.por-right-refution-dangerous))))

;;  (defthmd logic.formula-list-atblp-backwards-through-disjoin-formulas-dangerous
;;    (implies (and (logic.formula-listp x)
;;                  (logic.formula-atblp (logic.disjoin-formulas x) atbl))
;;             (logic.formula-list-atblp x atbl))
;;    :hints(("Goal"
;;            :in-theory (enable logic.formula-atblp-of-disjoin-formulas-refutation-dangerous)))))

