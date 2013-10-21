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
(include-book "patmatch-term")
(include-book "substitute-formula")
(set-verify-guards-eagerness 2)
(set-case-split-limitations nil)
(set-well-founded-relation ord<)
(set-measure-function rank)


;; (logic.formula-vars x) retrieves a list which contains all of the variables
;; mentioned everywhere throughout a formula

(defund logic.formula-vars (x)
  (declare (xargs :guard (logic.formulap x)))
  (cond ((equal (logic.fmtype x) 'por*)
         (app (logic.formula-vars (logic.vlhs x))
              (logic.formula-vars (logic.vrhs x))))
        ((equal (logic.fmtype x) 'pnot*)
         (logic.formula-vars (logic.~arg x)))
        ((equal (logic.fmtype x) 'pequal*)
         (app (logic.term-vars (logic.=lhs x))
              (logic.term-vars (logic.=rhs x))))
        (t nil)))

(defthm true-listp-of-logic.formula-vars
  (equal (true-listp (logic.formula-vars x))
         t)
  :hints(("Goal" :in-theory (e/d (logic.formula-vars)
                                 (logic.fmtype-normalizer-cheap)))))

(defthm logic.formula-vars-when-logic.por
  (implies (equal (logic.fmtype x) 'por*)
           (equal (logic.formula-vars x)
                  (app (logic.formula-vars (logic.vlhs x))
                       (logic.formula-vars (logic.vrhs x)))))
  :hints(("Goal" :in-theory (enable logic.formula-vars))))

(defthm logic.formula-vars-when-logic.pnot
  (implies (equal (logic.fmtype x) 'pnot*)
           (equal (logic.formula-vars x)
                  (logic.formula-vars (logic.~arg x))))
  :hints(("Goal" :in-theory (enable logic.formula-vars))))

(defthm logic.formula-vars-when-pequal
  (implies (equal (logic.fmtype x) 'pequal*)
           (equal (logic.formula-vars x)
                  (app (logic.term-vars (logic.=lhs x))
                       (logic.term-vars (logic.=rhs x)))))
  :hints(("Goal" :in-theory (enable logic.formula-vars))))

(defthm logic.formula-vars-when-degenerate
  (implies (and (not (equal (logic.fmtype x) 'pequal*))
                (not (equal (logic.fmtype x) 'pnot*))
                (not (equal (logic.fmtype x) 'por*)))
           (equal (logic.formula-vars x)
                  nil))
  :hints(("Goal" :in-theory (e/d (logic.formula-vars)
                                 (logic.fmtype-normalizer-cheap)))))

(defthm logic.formula-vars-of-pequal
  (equal (logic.formula-vars (logic.pequal x y))
         (app (logic.term-vars x)
              (logic.term-vars y))))

(defthm logic.formula-vars-of-logic.pnot
  (equal (logic.formula-vars (logic.pnot x))
         (logic.formula-vars x)))

(defthm logic.formula-vars-of-logic.por
  (equal (logic.formula-vars (logic.por x y))
         (app (logic.formula-vars x)
              (logic.formula-vars y))))

(defthm logic.variable-listp-of-logic.formula-vars
  (implies (force (logic.formulap x))
           (equal (logic.variable-listp (logic.formula-vars x))
                  t))
  :hints(("Goal" :in-theory (enable logic.formula-vars))))

(defthm equal-of-logic.substitute-formulas-of-expansion
  (implies (and (subsetp (logic.formula-vars x) (domain sigma1))
                (submapp sigma1 sigma2))
           (equal (equal (logic.substitute-formula x sigma1)
                         (logic.substitute-formula x sigma2))
                   t))
  :hints(("Goal" :in-theory (e/d (logic.substitute-formula)
                                 (logic.fmtype-normalizer-cheap)))))






;; (logic.patmatch-formula pattern target sigma)
;;
;; We extends our simple term-based pattern matching function to formulas.

(defund logic.patmatch-formula (pattern target sigma)
  (declare (xargs :guard (and (logic.formulap pattern)
                              (logic.formulap target)
                              (logic.sigmap sigma))
                  :verify-guards nil))
  (cond
   ((equal (logic.fmtype pattern) 'pequal*)
    (if (equal (logic.fmtype target) 'pequal*)
        (let ((match-lhs (logic.patmatch (logic.=lhs pattern) (logic.=lhs target) sigma)))
          (if (equal match-lhs 'fail)
              'fail
            (logic.patmatch (logic.=rhs pattern) (logic.=rhs target) match-lhs)))
      'fail))
   ((equal (logic.fmtype pattern) 'pnot*)
    (if (equal (logic.fmtype target) 'pnot*)
        (logic.patmatch-formula (logic.~arg pattern) (logic.~arg target) sigma)
      'fail))
   ((equal (logic.fmtype pattern) 'por*)
    (if (equal (logic.fmtype target) 'por*)
        (let ((match-lhs (logic.patmatch-formula (logic.vlhs pattern) (logic.vlhs target) sigma)))
          (if (equal match-lhs 'fail)
              'fail
            (logic.patmatch-formula (logic.vrhs pattern) (logic.vrhs target) match-lhs)))
      'fail))
   (t
    'fail)))

(defthm forcing-logic.sigmap-of-cdr-of-logic.patmatch-formula
  (implies (and (force (logic.formulap pattern))
                (force (logic.formulap target))
                (force (logic.sigmap sigma)))
           (equal (logic.sigmap (logic.patmatch-formula pattern target sigma))
                  t))
  :hints(("Goal" :in-theory (enable logic.patmatch-formula))))

(defthm forcing-logic.sigma-atblp-of-cdr-of-logic.patmatch-formula
  (implies (and (force (logic.formula-atblp pattern atbl))
                (force (logic.formula-atblp target atbl))
                (force (logic.sigma-atblp sigma atbl)))
           (equal (logic.sigma-atblp (logic.patmatch-formula pattern target sigma) atbl)
                  t))
  :hints(("Goal" :in-theory (e/d (logic.patmatch-formula)
                                 (logic.fmtype-normalizer-cheap)))))

(verify-guards logic.patmatch-formula)

(defthm submapp-of-logic.patmatch-formula
  (implies (not (equal 'fail (logic.patmatch-formula x y sigma)))
           (equal (submapp sigma (logic.patmatch-formula x y sigma))
                  t))
  :hints(("Goal" :in-theory (e/d (logic.patmatch-formula)
                                 (logic.fmtype-normalizer-cheap)))))

(defthm memberp-of-domain-of-logic.patmatch-formula
  (implies (and (memberp a (logic.formula-vars x))
                (not (equal 'fail (logic.patmatch-formula x y sigma))))
           (equal (memberp a (domain (logic.patmatch-formula x y sigma)))
                  t))
  :hints(("Goal" :in-theory (e/d (logic.patmatch-formula)
                                 (memberp-of-domain-under-iff
                                  logic.fmtype-normalizer-cheap)))))

(defthm lookup-of-logic.patmatch-formula
  (implies (and (memberp a (logic.formula-vars x))
                (not (equal 'fail (logic.patmatch-formula x y sigma))))
           (iff (lookup a (logic.patmatch-formula x y sigma))
                t))
  :hints(("Goal"
          :in-theory (disable memberp-of-domain-of-logic.patmatch-formula)
          :use ((:instance memberp-of-domain-of-logic.patmatch-formula)))))

(defthm subsetp-of-logic.formula-vars-with-domain-of-logic.patmatch-formula
  (implies (not (equal 'fail (logic.patmatch-formula x y sigma)))
           (equal (subsetp (logic.formula-vars x)
                           (domain (logic.patmatch-formula x y sigma)))
                  t))
  :hints(("Goal" :use ((:instance subsetp-badguy-membership-property
                                  (x (logic.formula-vars x))
                                  (y (domain (logic.patmatch-formula x y sigma))))))))


(encapsulate
 ()
 (defthmd lemma1-for-forcing-logic.substitute-formula-of-logic.patmatch-formula
   (implies (and (logic.formulap y)
                 (equal (logic.fmtype x) 'por*)
                 (equal (logic.fmtype y) 'por*)
                 (not (equal 'fail (logic.patmatch-formula (logic.vlhs x) (logic.vlhs y) sigma)))
                 (equal (logic.substitute-formula (logic.vlhs x) (logic.patmatch-formula (logic.vlhs x) (logic.vlhs y) sigma))
                        (logic.vlhs y))
                 (equal (logic.substitute-formula (logic.vrhs x)
                                                  (logic.patmatch-formula
                                                   (logic.vrhs x)
                                                   (logic.vrhs y)
                                                   (logic.patmatch-formula (logic.vlhs x) (logic.vlhs y) sigma)))
                        (logic.vrhs y))
                 (logic.sigmap sigma)
                 (not (equal 'fail (logic.patmatch-formula (logic.vrhs x)
                                                           (logic.vrhs y)
                                                           (logic.patmatch-formula (logic.vlhs x) (logic.vlhs y) sigma)))))
            (equal (logic.substitute-formula
                    x
                    (logic.patmatch-formula (logic.vrhs x)
                                            (logic.vrhs y)
                                            (logic.patmatch-formula (logic.vlhs x) (logic.vlhs y) sigma)))
                   y))
   :hints(("Goal"
           :in-theory (e/d (logic.substitute-formula)
                           (equal-of-logic.substitute-formulas-of-expansion))
           :use ((:instance equal-of-logic.substitute-formulas-of-expansion
                            (x (logic.vlhs x))
                            (sigma1 (logic.patmatch-formula (logic.vlhs x) (logic.vlhs y) sigma))
                            (sigma2 (logic.patmatch-formula (logic.vrhs x)
                                                            (logic.vrhs y)
                                                            (logic.patmatch-formula (logic.vlhs x)
                                                                                    (logic.vlhs y)
                                                                                    sigma))))))))

 (defthmd lemma2-for-forcing-logic.substitute-formula-of-logic.patmatch-formula
   (implies (and (logic.formulap y)
                 (equal (logic.fmtype x) 'pnot*)
                 (equal (logic.fmtype y) 'pnot*)
                 (equal (logic.substitute-formula (logic.~arg x)
                                                  (logic.patmatch-formula (logic.~arg x) (logic.~arg y) sigma))
                        (logic.~arg y))
                 (logic.sigmap sigma)
                 (not (equal 'fail (logic.patmatch-formula (logic.~arg x) (logic.~arg y) sigma))))
            (equal (logic.substitute-formula x (logic.patmatch-formula (logic.~arg x) (logic.~arg y) sigma))
                   y))
   :hints(("Goal"
           :in-theory (enable logic.substitute-formula))))

 (defthmd lemma3-for-forcing-logic.substitute-formula-of-logic.patmatch-formula
   (implies (and (logic.formulap y)
                 (equal (logic.fmtype x) 'pequal*)
                 (equal (logic.fmtype y) 'pequal*)
                 (not (equal 'fail (logic.patmatch (logic.=lhs x) (logic.=lhs y) sigma)))
                 (logic.sigmap sigma)
                 (not (equal 'fail (logic.patmatch (logic.=rhs x)
                                                   (logic.=rhs y)
                                                   (logic.patmatch (logic.=lhs x) (logic.=lhs y) sigma)))))
            (equal (logic.substitute-formula x (logic.patmatch (logic.=rhs x)
                                                               (logic.=rhs y)
                                                               (logic.patmatch (logic.=lhs x) (logic.=lhs y) sigma)))
                   y))
   :hints(("Goal"
           :in-theory (e/d (logic.substitute-formula)
                           (forcing-logic.substitute-of-logic.patmatch-expansion))
           :use ((:instance forcing-logic.substitute-of-logic.patmatch-expansion
                            (x (logic.=lhs x))
                            (y (logic.=lhs y))
                            (sigma sigma)
                            (sigma2 (logic.patmatch (logic.=rhs x) (logic.=rhs y) (logic.patmatch (logic.=lhs x)
                                                                                                  (logic.=lhs y)
                                                                                                  sigma))))))))

 (defthm forcing-logic.substitute-formula-of-logic.patmatch-formula
   (implies (and (not (equal 'fail (logic.patmatch-formula x y sigma)))
                 (force (logic.formulap x))
                 (force (logic.formulap y))
                 (force (logic.sigmap sigma)))
            (equal (logic.substitute-formula x (logic.patmatch-formula x y sigma))
                   y))
   :hints(("Goal" :in-theory (enable logic.patmatch-formula
                                     lemma1-for-forcing-logic.substitute-formula-of-logic.patmatch-formula
                                     lemma2-for-forcing-logic.substitute-formula-of-logic.patmatch-formula
                                     lemma3-for-forcing-logic.substitute-formula-of-logic.patmatch-formula)))))

