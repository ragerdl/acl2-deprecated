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
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "STD")
(include-book "../defprojection")
(include-book "misc/assert" :dir :system)

(make-event
 (prog2$
  (cw "~%~%~%WARNING!  PRINTER ON FIRE!~%You are loading ~
       std/util/tests/defprojection! Don't do that!~%~%")
  '(value-triple :invisible))
 :check-expansion t)

(in-theory
 ;; This is awful and you should generally never do it.  But here, the idea is
 ;; to show that all of these deflists will succeed even in a crippled theory.
 nil)

; Dupe is nice because it has a guard of T.

(defun dupe (x)
  (declare (xargs :guard t))
  (cons x x))

(defprojection dupe-list (x)
  (dupe x)
  :optimize nil)

(defprojection dupe-list2 (x)
  (dupe x)
  :optimize t)

(defprojection dupe-list3 (x)
  (dupe x)
  :verify-guards nil)

(defprojection dupe-list4 (x)
  (dupe x)
  :mode :program)


; Square adds some tests of guard handling.  For the guards to verify the
; user's theory needs to know something about integer-listp.

(local (in-theory (enable integer-listp)))

(defund square (x)
  (declare (xargs :guard (integerp x)))
  (* x x))

(defprojection slow-square-list (x)
  (square x)
  :guard (integer-listp x)
  :optimize nil)

(defprojection square-list (x)
  (square x)
  :guard (integer-listp x))

(defprojection program-square-list (x)
  (square x)
  :guard (integer-listp x)
  :mode :program)


(assert! (let ((x '(1 2 3 4 5 6 7 8 9 10)))
           (and (equal (square-list x)
                       (slow-square-list x))
                (equal (square-list x)
                       (program-square-list x)))))


; For result-type theorems the user's theory needs to be slightly more sane.

(local (in-theory (enable car-cons
                          cdr-cons
                          car-cdr-elim)))

(defthm integerp-of-square
  (implies (integerp x)
           (integerp (square x)))
  :hints(("Goal" :in-theory (enable square))))

(defprojection square-list-r (x)
  (square x)
  :guard (integer-listp x)
  :result-type integer-listp
  :optimize nil)

(defprojection square-list-r2 (x)
  (square x)
  :guard (integer-listp x)
  :result-type integer-listp
  :optimize nil
  :parallelize t)



  ;; Some tests with constants...

(defprojection add1-list (x)
  ;; Well, this won't work if it's nil-preservingp, but if someone complains
  ;; about they can go yell at Matt to fix maybe-defthm-as-rewrite.
  (+ 1 x)
  :guard (integer-listp x)
  :parents (foo)
  :rest
  ((defthm add1-list-integer-list
     (implies (integer-listp x)
              (integer-listp (add1-list x))))))

(local (in-theory (enable symbol-listp)))

(defprojection symbol-<-foo-list (x)
  (symbol-< :foo x)
  :guard (symbol-listp x))

(defprojection symbol-<-bar-list (x)
  (symbol-< 'bar x)
  :guard (symbol-listp x))



(local (in-theory (enable alistp)))

(defprojection my-strip-cars (x)
  (car x)
  :nil-preservingp t
  :guard (alistp x))


(defund f (x)
  (declare (xargs :guard (consp x)))
  (car x))

(defprojection my-strip-cars2 (x)
  (f x)
  :nil-preservingp t
  :guard (alistp x))


#||

(include-book ;; newline to appease cert.pl
 "defprojection-tests")

:q

(defparameter *test* (loop for i from 1 to 1000 collect i))

(equal (std::square-list *test*)
       (std::slow-square-list *test*))

;; .76 seconds, 320 MB
(progn
    (gc$)
    (time (loop for i from 1 to 10000
                do
                (consp (std::slow-square-list *test*)))))

;; .43 seconds, 160 MB
(progn
    (gc$)
    (time (loop for i from 1 to 10000
                do
                (consp (std::square-list *test*)))))

;; .43 seconds, 160 MB
(progn
    (gc$)
    (time (loop for i from 1 to 10000
                do
                (consp (std::program-square-list *test*)))))


||#




(defprojection m0 (x)
  (cons 1 x))

(assert! (let ((topic (xdoc::find-topic 'm0 (xdoc::get-xdoc-table (w state)))))
           (not topic)))

(xdoc::set-default-parents foo bar)

(defprojection m1 (x)
  (cons 1 x))

(assert! (let ((topic (xdoc::find-topic 'm1 (xdoc::get-xdoc-table (w state)))))
           (and topic
                (equal (cdr (assoc :parents topic))
                       '(foo bar)))))

(defprojection m2 (x)
  (cons 1 x)
  :parents (bar))

(assert! (let ((topic (xdoc::find-topic 'm2 (xdoc::get-xdoc-table (w state)))))
           (and topic
                (equal (cdr (assoc :parents topic))
                       '(bar)))))


(defprojection m3 (x)
  (cons 1 x)
  :parents nil)

(assert! (let ((topic (xdoc::find-topic 'm3 (xdoc::get-xdoc-table (w state)))))
           (not topic)))



;; Tests of new define syntax

(defprojection new-square-list ((x integer-listp))
  (square x)
  :verbosep t)

(local (in-theory (enable nat-listp
                          (:compound-recognizer acl2::natp-compound-recognizer)
                          (:type-prescription nfix))))

(defprojection nfix-list ((x nat-listp))
  (nfix x)
  :returns (new-x nat-listp))

(defprojection nfix-list2 ((x integer-listp))
  (nfix x)
  :returns (new-x nat-listp :hyp :guard))

(local (encapsulate ()
         (set-enforce-redundancy t)
         (defthm return-type-of-nfix-list2
           (implies (and (integer-listp x))
                    (b* ((new-x (nfix-list2 x)))
                      (nat-listp new-x))))))

(defprojection ifix-list ((x integer-listp))
  (nfix x)
  :returns (new-x nat-listp :hyp (nat-listp x)))

(local (encapsulate ()
         (set-enforce-redundancy t)
         (defthm return-type-of-ifix-list
           (implies (nat-listp x)
                    (b* ((new-x (ifix-list x)))
                      (nat-listp new-x))))))

