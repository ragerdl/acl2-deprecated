; Copyright (C) 2013, Regents of the University of Texas
; Written by Matt Kaufmann
; License: A 3-clause BSD license.  See the LICENSE file distributed with ACL2.

; This macro, defconst-fast, is based on a conversation with Warren Hunt.  A
; defconst in a book has the unfortunate property that its form is evaluated
; not only when that book is certified, but also (again) when that book is
; included.  Defconst-fast is more efficient because it generates a defconst
; that uses the result of the evaluation.  Moreover, defconst does its
; evaluation in a "safe mode" that avoids soundness issues but can cause a
; slowdown of (we have seen) 4X.

; See also defconst-fast-examples.lisp.

; For a more general utility, see ../tools/defconsts.lisp.

(in-package "ACL2")

(defmacro defconst-fast (name form &optional (doc '"" doc-p))
  `(make-event
    (let ((val ,form))
      (list* 'defconst ',name (list 'quote val)
             ,(and doc-p (list 'list doc))))))
