; Standard Utilities Library
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

; wizard.lisp
;
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "ACL2")
(include-book "defaggregate")
(include-book "deflist")
(include-book "clause-processors/unify-subst" :dir :system)

(std::defaggregate wizadvice
  (pattern  ;; pattern to match
   restrict ;; syntactic restrictions required on resulting sigma
   msg      ;; message to print
   args     ;; some sigma variables to be bound
   )
  :tag :advice-form)

(std::deflist wizadvicelist-p (x)
  (wizadvice-p x)
  :guard t)

(mutual-recursion
 (defun collect-matches-from-term (pattern x acc)
   ;; Returns a list of sigmas
   (b* (((mv matchp sigma)
         (simple-one-way-unify pattern x nil))
        (acc (if matchp (cons sigma acc) acc))
        ((when (or (atom x)
                   (eq (car x) 'quote)))
         acc))
     (collect-matches-from-term-list pattern (cdr x) acc)))
 (defun collect-matches-from-term-list (pattern x acc)
   ;; Returns a list of sigmas
   (b* (((when (atom x))
         acc)
        (acc (collect-matches-from-term pattern (car x) acc)))
     (collect-matches-from-term-list pattern (cdr x) acc))))

(defun simpler-trans-eval (x alist state)
  (declare (xargs :stobjs state :mode :program))
  (b* (((mv er (cons ?trans eval))
        (simple-translate-and-eval-error-double
         x alist nil
         (msg "Term was ~x0" x)
         'simpler-trans-eval
         (w state)
         state
         t
         (f-get-global 'safe-mode state)
         (gc-off state))))
    (or (not er)
        (er hard? 'simpler-trans-eval
            "Evaluation somehow failed for ~x0: ~@1" x er))
    eval))

(defun simpler-trans-eval-list (x alist state)
  (declare (xargs :stobjs state :mode :program))
  (b* (((mv er (cons ?trans eval))
        (simple-translate-and-eval-error-double x alist nil
                                                (msg "Term was ~x0" x)
                                                'simpler-trans-eval
                                                (w state)
                                                state
                                                t
                                                (f-get-global 'safe-mode state)
                                                (gc-off state))))
    (or (not er)
        (er hard? 'simpler-trans-eval
            "Evaluation somehow failed for ~x0: ~@1" x er))
    eval))



;; (simpler-trans-eval '(consp x) '((x . nil)) state)
;; (simpler-trans-eval '(consp x) '((x . (1 . 2))) state)

(defun filter-sigmas-by-restriction (restrict sigmas state)
  (declare (xargs :stobjs state :mode :program))
  (b* (((when (atom sigmas))
        nil)
       (evaluation
        (simpler-trans-eval restrict (car sigmas) state))
       ((unless evaluation)
        (filter-sigmas-by-restriction restrict (cdr sigmas) state))
       (rest
        (filter-sigmas-by-restriction restrict (cdr sigmas) state)))
    (cons (car sigmas) rest)))

;; (filter-sigmas-by-restriction '(quotep x)
;;                               (collect-matches-from-term '(foo x)
;;                                                          '(if '3 (cons (foo '1) 'nil) (cons (foo (foo '2)) 't))
;;                                                          nil)
;;                               state)

(defun wizard-print-advice (sigma advice state)
  (declare (xargs :stobjs state :mode :program))
  (b* (((wizadvice advice) advice)
       (args-evaled (simpler-trans-eval advice.args sigma state))
       (msg (cons (concatenate 'string "~|~%Wizard: " advice.msg "~%")
                  (pairlis2 '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9) args-evaled))))
    (cw "~@0" msg)
    nil))

(defun wizard-print-advice-list (sigmas advice state)
  (declare (xargs :stobjs state :mode :program))
  (if (atom sigmas)
      nil
    (prog2$ (wizard-print-advice (car sigmas) advice state)
            (wizard-print-advice-list (cdr sigmas) advice state))))

(defun wizard-do-advice (clause advice state)
  (declare (xargs :stobjs state :mode :program))
  (b* (((wizadvice advice) advice)
       (sigmas (collect-matches-from-term-list advice.pattern clause nil))
       (sigmas (remove-duplicates-equal sigmas))
       (sigmas
        (if advice.restrict
            (filter-sigmas-by-restriction advice.restrict sigmas state)
          sigmas)))
    (wizard-print-advice-list sigmas advice state)))

(defun wizard-do-advice-list (clause advices state)
  (declare (xargs :stobjs state :mode :program))
  (if (atom advices)
      nil
    (prog2$ (wizard-do-advice clause (car advices) state)
            (wizard-do-advice-list clause (cdr advices) state))))

(table wizard-advice)

(defun get-wizard-advice (world)
  (cdr (assoc 'wizadvice (table-alist 'wizard-advice world))))

(defmacro add-wizard-advice (&key pattern restrict msg args)
  `(table wizard-advice 'wizadvice
          (cons (make-wizadvice :pattern ',pattern
                                :restrict ',restrict
                                :msg ,msg
                                :args ',args)
                (get-wizard-advice world))))

(defun wizard-fn (stable-under-simplificationp clause state)
  (declare (xargs :stobjs state :mode :program))
  (if (not stable-under-simplificationp)
      nil
    (let ((advices (get-wizard-advice (w state))))
      (prog2$ (wizard-do-advice-list clause advices state)
              nil))))

(defmacro wizard ()
  `(wizard-fn stable-under-simplificationp clause state))

(defmacro enable-wizard ()
  `(add-default-hints '((wizard))))


#|

;; Example:

(enable-wizard)

(add-wizard-advice :pattern (logbitp x const)
                   :restrict (and (quotep const)
                                  (< 1 (logcount (unquote const))))
                   :msg "Possibly enable OPEN-LOGBITP-OF-CONST-META to match ~x0; this may cause a ~x1-way case split."
                   :args (list `(logbitp ,x ,const)
                               (logcount (unquote const))))

(defstub foo (x) t)

(local (in-theory (disable logbitp)))

(defthm crock
  (implies (logbitp bit #b111000111000)
           (foo bit)))

|#
