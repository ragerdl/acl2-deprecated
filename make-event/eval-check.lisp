; Copyright (C) 2013, Regents of the University of Texas
; Written by Matt Kaufmann (sometime before that)
; License: A 3-clause BSD license.  See the LICENSE file distributed with ACL2.

; This is a modification of community book misc/eval.lisp that uses
; :check-expansion t.

(in-package "ACL2")

(defmacro must-eval-to (&whole must-eval-to-form
                               form expr)

; Warning: Keep this in sync with the definition of must-eval-to in community
; book misc/eval.lisp.

; Form should evaluate to an error triple (mv erp form-val state).  If erp is
; nil and expr-val is the value of expr then (must-eval-to form expr) expands
; to (value-triple 'expr-val); otherwise expansion causes an appropriate soft
; error.  Note that both form and expr are evaluated.

  `(make-event
    (er-let* ((form-val-use-nowhere-else ,form))
      (let ((expr-val (check-vars-not-free
                       (form-val-use-nowhere-else)
                       ,expr)))
        (cond ((eq form-val-use-nowhere-else expr-val)
               (value (list 'value-triple (list 'quote expr-val))))
              (t (er soft
                     (msg "( MUST-EVAL-TO ~@0 ~@1)"
                          (tilde-@-abbreviate-object-phrase ',form)
                          (tilde-@-abbreviate-object-phrase ',expr))
                     "Evaluation returned ~X01, not the value ~x2 of the ~
                      expression ~x3."
                     form-val-use-nowhere-else
                     (evisc-tuple 4 3 nil nil)
                     expr-val
                     ',expr)))))
    :on-behalf-of ,must-eval-to-form
    :check-expansion t))

(defmacro must-eval-to-t (form)

; Form should evaluate to an error triple (mv erp val state).  If erp is nil
; and val is t then (must-eval-to-t form) expands to (value-triple t);
; otherwise expansion causes an appropriate soft error.

  `(must-eval-to ,form t))

(defmacro must-succeed (&whole must-succeed-form
                               form)

; (Must-succeed form) expands to (value-triple t) if evaluation of form is an
; error triple (mv nil val state), and causes a soft error otherwise.

  `(make-event
    '(must-eval-to-t
      (mv-let (erp val state)
              ,form
              (declare (ignore val))
              (value (eq erp nil))))
    :check-expansion t
    :on-behalf-of ,must-succeed-form))

(defmacro must-fail (&whole must-fail-form
                            form)

; Form should evaluate to an error triple (mv erp val state).  (Must-succeed
; form) expands to (value-triple t) if erp is non-nil, and expansion causes a
; soft error otherwise.

  `(make-event
    '(must-eval-to-t
      (mv-let (erp val state)
              ,form
              (declare (ignore val))
              (value (not (eq erp nil)))))
    :check-expansion t
    :on-behalf-of ,must-fail-form))
