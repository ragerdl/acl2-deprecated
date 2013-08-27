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
(include-book "colors")
(include-book "skeletonp")
(set-verify-guards-eagerness 2)
(set-case-split-limitations nil)
(set-well-founded-relation ord<)
(set-measure-function rank)


(defund tactic.generalize-first-okp (x)
  (declare (xargs :guard (tactic.skeletonp x)))
  (let ((goals   (tactic.skeleton->goals x))
        (tacname (tactic.skeleton->tacname x))
        (extras  (tactic.skeleton->extras x))
        (history (tactic.skeleton->history x)))
    (and (equal tacname 'generalize-first)
         (consp extras)
         (let ((expr       (car extras)) ;; the term to generalize
               (var        (cdr extras)) ;; the new variable to generalize to
               (prev-goals (tactic.skeleton->goals history)))
           (and (consp prev-goals)
                (logic.termp expr)
                (logic.variablep var)
                (let ((clause1 (car prev-goals)))
                  (and (not (memberp var (logic.term-list-vars clause1)))
                       (let ((replacement (logic.replace-subterm-list clause1 expr var)))
                         (and (not (equal replacement clause1))
                              (equal (car goals) replacement)
                              (equal (cdr goals) (cdr prev-goals)))))))))))

(defund tactic.generalize-first-env-okp (x atbl)
  (declare (xargs :guard (and (tactic.skeletonp x)
                              (tactic.generalize-first-okp x)
                              (logic.arity-tablep atbl))
                  :guard-hints (("Goal" :in-theory (enable tactic.generalize-first-okp)))))
  (let* ((extras (tactic.skeleton->extras x))
         (expr   (car extras)))
    (logic.term-atblp expr atbl)))

(defthm booleanp-of-tactic.generalize-first-okp
  (equal (booleanp (tactic.generalize-first-okp x))
         t)
  :hints(("Goal" :in-theory (e/d (tactic.generalize-first-okp)
                                 ((:executable-counterpart acl2::force))))))

(defthm booleanp-of-tactic.generalize-first-env-okp
  (equal (booleanp (tactic.generalize-first-env-okp x atbl))
         t)
  :hints(("Goal" :in-theory (e/d (tactic.generalize-first-env-okp)
                                 ((:executable-counterpart acl2::force))))))




(defund tactic.generalize-first-tac (x expr var)
  ;; Replace occurrences of expr with var, a new variable
  (declare (xargs :guard (and (tactic.skeletonp x)
                              (logic.termp expr)
                              (logic.variablep var))))
  (let ((goals (tactic.skeleton->goals x)))
    (if (not (consp goals))
        (ACL2::cw "~s0Generalize-first-tac failure~s1: all clauses have already been proven.~%" *red* *black*)
      (let* ((clause1      (car goals))
             (clause1-vars (logic.term-list-vars clause1))
             (replacement  (logic.replace-subterm-list clause1 expr var)))
        (cond ((memberp var clause1-vars)
               (ACL2::cw "~s0Generalize-first-tac failure~s1: we need to use a fresh variable, but ~x2 ~
                          is already mentioned in the clause.~%" *red* *black* var))
              ((equal replacement clause1)
               (ACL2::cw "~s0Generalize-first-tac failure~s1: the clause did not change due to this ~
                          replacement.~%" *red* *black*))
              (t
               (tactic.extend-skeleton (cons replacement (cdr goals))
                                       'generalize-first
                                       (cons expr var)
                                       x)))))))

(defthm forcing-tactic.skeletonp-of-tactic.generalize-first-tac
  (implies (and (tactic.generalize-first-tac x expr var)
                (force (logic.variablep var))
                (force (tactic.skeletonp x)))
           (equal (tactic.skeletonp (tactic.generalize-first-tac x expr var))
                  t))
  :hints(("Goal" :in-theory (enable tactic.generalize-first-tac))))

(defthm forcing-tactic.generalize-first-okp-of-tactic.generalize-first-tac
  (implies (and (tactic.generalize-first-tac x expr var)
                (force (logic.termp expr))
                (force (logic.variablep var))
                (force (tactic.skeletonp x)))
           (equal (tactic.generalize-first-okp (tactic.generalize-first-tac x expr var))
                  t))
  :hints(("Goal" :in-theory (enable tactic.generalize-first-tac
                                    tactic.generalize-first-okp))))

(defthm forcing-tactic.generalize-first-env-okp-of-tactic.generalize-first-tac
  (implies (and (tactic.generalize-first-tac x expr var)
                (force (logic.termp expr))
                (force (logic.term-atblp expr atbl))
                (force (logic.variablep var))
                (force (tactic.skeletonp x)))
           (equal (tactic.generalize-first-env-okp (tactic.generalize-first-tac x expr var) atbl)
                  t))
  :hints(("Goal" :in-theory (enable tactic.generalize-first-tac
                                    tactic.generalize-first-env-okp))))




(defund tactic.generalize-first-compile (x proofs)
  (declare (xargs :guard (and (tactic.skeletonp x)
                              (tactic.generalize-first-okp x)
                              (logic.appeal-listp proofs)
                              (equal (clause.clause-list-formulas (tactic.skeleton->goals x))
                                     (logic.strip-conclusions proofs)))
                  :verify-guards nil))
  (let* ((extras        (tactic.skeleton->extras x))
         (expr          (car extras))
         (var           (cdr extras)))
    (cons (build.instantiation (car proofs) (list (cons var expr)))
          (cdr proofs))))

(defobligations tactic.generalize-first-compile
  (build.instantiation))

(encapsulate
 ()
 (local (in-theory (enable tactic.generalize-first-okp
                           tactic.generalize-first-env-okp
                           tactic.generalize-first-compile)))

 (local (defthm logic.substitute-formula-of-logic.disjoin-formulas-free
          (implies (equal x (logic.disjoin-formulas y))
                   (equal (logic.substitute-formula x sigma)
                          (logic.disjoin-formulas (logic.substitute-formula-list y sigma))))))

 (local (defthm forcing-logic.substitute-of-logic.replace-subterm-list-with-fresh-variable-free
          (implies (and (equal terms (logic.replace-subterm-list x old new) )
                        (not (memberp new (logic.term-list-vars x)))
                        (logic.variablep new)
                        (force (logic.term-listp x)))
                   (equal (logic.substitute-list terms (list (cons new old)))
                          (list-fix x)))))

 (verify-guards tactic.generalize-first-compile)

 (defthm forcing-logic.appeal-listp-of-tactic.generalize-first-compile
   (implies (force (and (tactic.skeletonp x)
                        (tactic.generalize-first-okp x)
                        (logic.appeal-listp proofs)
                        (equal (clause.clause-list-formulas (tactic.skeleton->goals x))
                               (logic.strip-conclusions proofs))))
            (equal (logic.appeal-listp (tactic.generalize-first-compile x proofs))
                   t)))

 (defthm forcing-logic.strip-conclusions-of-tactic.generalize-first-compile
   (implies (force (and (tactic.skeletonp x)
                        (tactic.generalize-first-okp x)
                        (logic.appeal-listp proofs)
                        (equal (clause.clause-list-formulas (tactic.skeleton->goals x))
                               (logic.strip-conclusions proofs))))
            (equal (logic.strip-conclusions (tactic.generalize-first-compile x proofs))
                   (clause.clause-list-formulas (tactic.skeleton->goals (tactic.skeleton->history x))))))

 (defthm@ forcing-logic.proof-listp-of-tactic.generalize-first-compile
   (implies (force (and (tactic.skeletonp x)
                        (tactic.generalize-first-okp x)
                        (logic.appeal-listp proofs)
                        (equal (clause.clause-list-formulas (tactic.skeleton->goals x))
                               (logic.strip-conclusions proofs))
                        ;; ---
                        (tactic.skeleton-atblp x atbl)
                        (tactic.generalize-first-env-okp x atbl)
                        (logic.proof-listp proofs axioms thms atbl)
                        (@obligations tactic.generalize-first-compile)))
            (equal (logic.proof-listp (tactic.generalize-first-compile x proofs) axioms thms atbl)
                   t))))
