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
(include-book "symbolic-arithmetic")
(include-book "eval-g-base")

(local (include-book "eval-g-base-help"))
(local (include-book "hyp-fix"))

(local (defthm nth-open-when-constant-idx
         (implies (syntaxp (quotep n))
                  (equal (nth n x)
                         (if (zp n) (car x)
                           (nth (1- n) (cdr x)))))))


(local (defthm eval-g-base-atom
         (implies (not (consp x))
                  (equal (eval-g-base x env) x))
         :hints (("goal" :expand ((:with eval-g-base (eval-g-base x env)))))
         :rule-classes ((:rewrite :backchain-limit-lst 0))))


(program)

(defun strip-correct-lemmas (alist)
  (if (atom alist)
      nil
    (append (strip-cars (cddr (car alist)))
            (strip-correct-lemmas (cdr alist)))))




(defun def-g-predicate-fn (fn cases
                              corr-hints guard-hints
                              encap guard-encap corr-encap formals)
  (declare (xargs :mode :program))
  (let* ((gfn (gl-fnsym fn))
         (booleanp-thmname
          (incat 'gl-thm::foo (symbol-package-name fn) "::"
                 (symbol-name fn) "-IS-BOOLEANP"))
         (x (car formals)))
    `(encapsulate nil
       (logic)
       (local (def-ruleset! g-correct-lemmas
                (strip-correct-lemmas (table-alist 'gl-function-info world))))
       (def-g-fn ,fn
         `(if (atom ,',x)
              (gret (,',fn ,',x))
            (pattern-match ,',x
              ((g-concrete obj) (gret (,',fn obj)))
              ((g-ite test then else)
               (if (zp clk)
                   (gret (g-apply ',',fn (list ,',x)))
                 (g-if (gret test)
                       (,gfn then . ,params)
                       (,gfn else . ,params))))
              ((g-apply & &) (gret (g-apply ',',fn (list ,',x))))
              ((g-var &) (gret (g-apply ',',fn (list ,',x))))
              . ,',cases)))
       (local (in-theory (disable ,gfn)))
       (local (defthm ,booleanp-thmname
                (booleanp (,fn ,x))))
       (local (defthm tag-of-cons
                (equal (tag (cons a b)) a)
                :hints(("Goal" :in-theory (enable tag)))))
;;        (encapsulate nil
;;          (local (in-theory
;;                  (e/d** (minimal-theory
;;                          (:executable-counterpart-theory :here)
;;                          (:induction ,gfn)
;;                          ; (:ruleset g-gobjectp-lemmas)
;;                          (:ruleset gl-tag-rewrites)
;;                          (:ruleset gl-wrong-tag-rewrites)
;;                          gobjectp-tag-rw-to-types
;;                          gobjectp-ite-case
;;                          bfr-p-bfr-binary-and
;;                          bfr-p-bfr-binary-or
;;                          bfr-p-bfr-not
;;                          bfr-p-bfr-fix
;; ;;                          bfr-p-of-bfr-and
;; ;;                          bfr-p-of-bfr-or
;;                          gobjectp-boolean-case
;;                          gobjectp-g-if-marker
;;                          g-if-gobjectp-meta-correct
;;                          gobjectp-g-or-marker
;;                          g-or-gobjectp-meta-correct
;;                          hyp-fix-bfr-p
;; ;                         bfr-and-is-bfr-and
;; ;                         bfr-not-is-bfr-not
;; ;                         bfr-or
;;                          gtests-wfp
;;                          gtests-g-test-marker
;;                          ; gobjectp-g-ite-branches
;;                          booleanp-gobjectp
;;                          gobjectp-mk-g-boolean
;;                          gobjectp-gobj-fix
;;                          gobjectp-cons
;;                          gobjectp-g-apply
;;                          ,booleanp-thmname)
;;                         ((immediate-force-modep)
;;                          (gobjectp)
;;                          (general-concretep)
;;                          (gobject-hierarchy)))))
;;          ,@encap
;;          ,@gobj-encap
;;          (def-gobjectp-thm ,fn
;;            :hints `(("goal"
;;                      :induct (,gfn ,',x . ,params)
;;                      :expand ((,gfn ,',x . ,params)))
;;                     . ,',gobj-hints)))
       (encapsulate nil
         (local (in-theory
                 (e/d* (minimal-theory
                         (:executable-counterpart-theory :here)
                         ;; (:ruleset g-gobjectp-lemmas)
                         ;; gobjectp-tag-rw-to-types
                         ;; gobjectp-ite-case
;                         bfr-and-is-bfr-and
;                         bfr-not-is-bfr-not
;                         bfr-and-macro-exec-part
                         bfr-and-of-nil
                         bfr-or-of-t
                         ;; bfr-p-bfr-binary-and
                         ;; bfr-p-bfr-not
                         ;; bfr-p-bfr-binary-or
                         ;; bfr-p-bfr-fix
                         ;; bfr-fix-when-bfr-p
                         ;; gobjectp-gobj-ite-merge
                         ;; gobjectp-mk-g-ite
                         ;; gobjectp-boolean-case
                         ;; gobj-fix-when-gobjectp
                         ; gobjectp-g-ite-branches
;                         bfr-or
                         ;; gobjectp-g-test-marker
                         ;; gtests-g-test-marker
                         natp
                         ;; gtestsp-gtests
                         ;; gtests-wfp
                         ;; hyp-fix-bfr-p
                         ;; gobjectp-g-branch-marker
                         ;; booleanp-gobjectp
                         ,booleanp-thmname
                         ;; (:ruleset g-guard-lemmas)
                         ;; bfr-p-g-hyp-marker
                         )
                        ((immediate-force-modep)
                         (force)
                         ;; (gobjectp)
                         ;; (gobject-hierarchy)
                         (general-concretep)
                         logcons
                         eval-g-base-alt-def
;;                          (assume-true-under-hyp)
;;                          (assume-false-under-hyp)
                         ))))
         ,@encap
         ,@guard-encap
         (verify-g-guards ,fn
                          :hints ',guard-hints))
       (def-gobj-dependency-thm ,fn
         :hints `(("goal" :induct ,gcall
                   :expand (,gcall)
                   :in-theory (e/d ((:i ,gfn)) ((:d ,gfn))))))
       (encapsulate nil
         (local (in-theory (e/d* (;; gobjectp-tag-rw-to-types
                                  ;; gobjectp-gobj-fix
                                  ; g-eval-non-consp
                                  booleanp-compound-recognizer
                                  eval-g-base-g-apply
                                  (:type-prescription bfr-eval)
                                  (:type-prescription
                                   components-to-number-fn)
                                  ;; gobjectp-cons gobjectp-gobj-fix
                                  eval-g-base-apply
                                  nth-open-when-constant-idx
                                  eval-g-base-of-gl-cons
                                  ;; geval-g-if-marker-eval-g-base
                                  ;; geval-g-or-marker-eval-g-base
                                  ;; g-if-geval-meta-correct-eval-g-base
                                  ;; g-or-geval-meta-correct-eval-g-base
                                  eval-g-base-atom
                                  eval-g-base-list
                                  ;; booleanp-gobjectp
                                  )
                                 (;; bfr-p-of-boolean
                                  general-number-components-ev
                                  (:type-prescription booleanp)

                                  bfr-eval-booleanp
                                  general-boolean-value-correct
                                  bool-cond-itep-eval
                                  eval-g-base-alt-def
                                  ; eval-g-non-keyword-cons
                                  eval-concrete-gobjectp)
                                 ())))
         ,@encap
         ,@corr-encap
         (def-g-correct-thm ,fn eval-g-base
           :hints `(("goal" :in-theory (enable (:induction ,gfn))
                     :induct (,gfn ,',x . ,params)
                     :expand ((,gfn ,',x . ,params)))
                    (and stable-under-simplificationp
                         '(:expand ((:with eval-g-base (eval-g-base ,',x env))
                                    (:with eval-g-base (eval-g-base nil env))
                                    (:with eval-g-base (eval-g-base t env)))))
                    . ,',corr-hints))))))


(defmacro def-g-predicate
  (fn cases &key
      corr-hints guard-hints gobj-hints encap
      gobj-encap guard-encap corr-encap (formals '(x)))
  (declare (ignorable gobj-hints gobj-encap))
  (def-g-predicate-fn
    fn cases corr-hints guard-hints
    encap guard-encap corr-encap formals))

(logic)



(def-g-predicate booleanp
  (((g-boolean &) (gret t))
   (& (gret nil))))

(def-g-predicate not
  (((g-boolean bdd) (gret (mk-g-boolean (bfr-not bdd))))
   (& (gret nil)))
  :formals (p))

(def-g-predicate symbolp
  (((g-boolean &) (gret t))
   (& (gret nil))))

(def-g-predicate acl2-numberp
  (((g-number &) (gret t))
   (& (gret nil))))

(def-g-predicate stringp ((& (gret nil))))

(def-g-predicate characterp ((& (gret nil))))

(def-g-predicate consp
  (((g-boolean &) (gret nil))
   ((g-number &) (gret nil))
   (& (gret t))))



(encapsulate nil

  (def-g-predicate integerp
    (((g-number num)
      (mv-let (arn ard ain aid)
        (break-g-number num)
        (declare (ignore arn))
        (if (equal ard '(t))
            (gret (mk-g-boolean
                   (bfr-or (bfr-=-ss ain nil)
                           (bfr-=-uu aid nil))))
          (gret (g-apply 'integerp (list x))))))
     (& (gret nil)))
    :encap ((local (in-theory (enable bfr-eval-bfr-binary-or
                                      bfr-or-of-t
                                      bfr-=-uu-correct
                                      bfr-=-ss-correct
                                      (:type-prescription break-g-number)))))
    :guard-encap ((local (bfr-reasoning-mode t))
                  (local (add-bfr-pats (bfr-=-uu . &) (bfr-=-ss . &))))
    :corr-hints ((and stable-under-simplificationp
                      (append '(:in-theory (enable components-to-number-alt-def))
                              (flag::expand-calls-computed-hint
                               clause '(eval-g-base)))))))


(encapsulate nil
  (def-g-predicate rationalp
    (((g-number num)
      (mv-let (arn ard ain aid)
        (break-g-number num)
        (declare (ignore arn ard))
        (gret (mk-g-boolean
               (bfr-or (bfr-=-ss ain nil)
                       (bfr-=-uu aid nil))))))
     (& (gret nil)))
    :encap ((local (in-theory (enable bfr-eval-bfr-binary-or
                                      bfr-=-uu-correct
                                      bfr-=-ss-correct
                                      bfr-or-of-t
                                      (:type-prescription break-g-number)))))
    :guard-encap ((local (bfr-reasoning-mode t)))
    :corr-hints ((and stable-under-simplificationp
                      (append '(:in-theory (enable components-to-number-alt-def))
                              (flag::expand-calls-computed-hint
                               clause '(eval-g-base)))))))








