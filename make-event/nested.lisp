; Copyright (C) 2013, Regents of the University of Texas
; Written by Matt Kaufmann
; License: A 3-clause BSD license.  See the LICENSE file distributed with ACL2.

; Here are some tests for nesting of make-event forms: macros, local,
; skip-proofs, with-output, and recursive make-event.

(in-package "ACL2")

(defmacro my-make-event (&rest args)
  `(make-event ,@args))

(my-make-event
 '(my-make-event
   '(defun nest1 (x)
      (cons x x))))

(defthm nest1-prop
  (equal (nest1 x)
         (cons x x)))

; redundant
(make-event
 '(my-make-event
   (value '(defun nest1 (x)
             (cons x x)))))

; redundant
(my-make-event
 '(make-event
   (value '(defun nest1 (x)
             (cons x x)))))

(with-output
 :off warning
 (my-make-event
  '(make-event
    (value '(with-output
             :on warning
             (defun nest2 (x)
               (list x x)))))))
; redundant
(with-output
 :off warning
 (make-event
  '(my-make-event
    (value '(with-output
             :on event
             (defun nest2 (x)
               (list x x)))))))

; nested redundant event

(encapsulate
 ()
 (my-make-event
  '(defun nest1 (x)
     (cons x x)))
 (defun bar (x) x))

; encapsulate and make-event

(make-event
 '(encapsulate
   ()
   (make-event
    '(defun test2 (x)
       (cons x x)))))
