; Reasoning about evaluators and falsifiers
; Copyright (C) 2010 Centaur Technology
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

(in-package "ACL2")

(include-book "misc/untranslate-patterns" :dir :system)
(include-book "join-thms")
;; This is a sadly incomplete book for reasoning about evaluators and
;; "falsifier" functions.  An evaluator ev gives a value to a term X
;; under an alist A, and a falsifier evf provides for a given X an
;; alist A under which it evaluates to NIL, if one exists.  Therefore,
;; if (ev X (evf X)) is non-nil, then (ev X A) is nonnil for all A,
;; and we say X is a theorem under evaluator ev.

;; Reasoning about this concept gets much more complicated when one
;; considers evaluations of terms under falsifiers of other terms.
;; For example, (ev (and A B) (evf (and A B))) says that (and A B) is
;; a theorem, meaning that A and B are both theorems.  But commonly,
;; rewrite rules will decompose that term into
;; (and (ev A (evf (and A B)))
;;      (ev B (evf (and A B))))
;; But separately, each of (ev A (evf (and A B))) and
;; (ev B (evf (and A B))) don't tell us much.  We'd rather rewrite the
;; original form to
;; (and (ev A (evf A))
;;      (ev B (evf B))).

(defmacro def-ev-theoremp (ev &key untranslate)
  (let* ((falsify (intern-in-package-of-symbol
                   (concatenate 'string (symbol-name ev)
                                "-FALSIFY")
                   ev))
         (theoremp (intern-in-package-of-symbol
                    (concatenate 'string (symbol-name ev)
                                 "-THEOREMP")
                    ev))
         (subst
          `((ev . ,ev)
            (falsify . ,falsify)
            (theoremp . ,theoremp)
            (conjoin-cons
             . ,(intern-in-package-of-symbol
                 (concatenate 'string (symbol-name theoremp)
                              "-CONJOIN-CONS")
                 ev))
            (conjoin-append
             . ,(intern-in-package-of-symbol
                 (concatenate 'string (symbol-name theoremp)
                              "-CONJOIN-APPEND")
                 ev))
            (conjoin-clauses-cons
             . ,(intern-in-package-of-symbol
                 (concatenate 'string (symbol-name theoremp)
                              "-CONJOIN-CLAUSES-CONS")
                 ev))
            (conjoin-clauses-append
             . ,(intern-in-package-of-symbol
                 (concatenate 'string (symbol-name theoremp)
                              "-CONJOIN-CLAUSES-APPEND")
                 ev))))
         (event
          (sublis
           subst
           '(encapsulate nil
              (local (in-theory nil))

              (def-join-thms ev)

              (defchoose falsify (a) (x)
                (not (ev x a)))

              (defmacro theoremp (x)
                `(ev ,x (falsify ,x)))

              (defthm conjoin-cons
                (iff (theoremp (conjoin (cons a b)))
                     (and (theoremp a)
                          (theoremp (conjoin b))))
                :hints (("goal" :use
                         ((:instance
                           falsify
                           (x (conjoin (cons a b)))
                           (a (falsify a)))
                          (:instance
                           falsify
                           (x a)
                           (a (falsify (conjoin (cons a b)))))
                          (:instance
                           falsify
                           (x (conjoin (cons a b)))
                           (a (falsify (conjoin b))))
                          (:instance
                           falsify
                           (x (conjoin b))
                           (a (falsify (conjoin (cons a b)))))))))

              (defthm conjoin-append
                (iff (theoremp (conjoin (append a b)))
                     (and (theoremp (conjoin a))
                          (theoremp (conjoin b))))
                :hints(("Goal" :in-theory (enable append endp car-cdr-elim))))

              (defthm conjoin-clauses-cons
                (iff (theoremp
                      (conjoin-clauses (cons cl1 clrest)))
                     (and (theoremp (disjoin cl1))
                          (theoremp (conjoin-clauses clrest))))
                :hints(("Goal" :in-theory (enable conjoin-clauses disjoin-lst
                                                  car-cons cdr-cons))))
        
              (defthm conjoin-clauses-append
                (iff (theoremp
                      (conjoin-clauses (append cls1 cls2)))
                     (and (theoremp (conjoin-clauses cls1))
                          (theoremp (conjoin-clauses cls2))))
                :hints (("goal" :in-theory (enable append endp car-cdr-elim)
                         :induct (append cls1 cls2))))))))
    (if untranslate
        `(progn ,event
                ,(sublis subst '(add-untranslate-pattern
                                 (ev ?x (falsify ?x))
                                 (theoremp ?x))))
      event)))
                

(local
 (progn
   (defevaluator test-ev test-ev-lst ((if a b c)))
   (def-ev-theoremp test-ev)))
      

#||
(defevaluator evthmp-ev evthmp-ev-lst
  ((if a b c) (not a)))


(def-join-thms evthmp-ev)

(defchoose evthmp-ev-falsify (a) (x)
  (not (evthmp-ev x a)))

(defmacro evthmp-ev-theoremp (x)
  `(evthmp-ev ,x (evthmp-ev-falsify ,x)))

(add-untranslate-pattern
 (evthmp-ev ?x (evthmp-ev-falsify ?x))
 (evthmp-ev-theoremp ?x))

(defthm evthmp-ev-theoremp-conjoin-cons
  (iff (evthmp-ev-theoremp (conjoin (cons a b)))
       (and (evthmp-ev-theoremp a)
            (evthmp-ev-theoremp (conjoin b))))
  :hints (("goal" :use
           ((:instance
             evthmp-ev-falsify
             (x (conjoin (cons a b)))
             (a (evthmp-ev-falsify a)))
            (:instance
             evthmp-ev-falsify
             (x a)
             (a (evthmp-ev-falsify (conjoin (cons a b)))))
            (:instance
             evthmp-ev-falsify
             (x (conjoin (cons a b)))
             (a (evthmp-ev-falsify (conjoin b))))
            (:instance
             evthmp-ev-falsify
             (x (conjoin b))
             (a (evthmp-ev-falsify (conjoin (cons a b)))))))))

||#


;; (defthmd evthmp-ev-theoremp-remove-first-lit-when-false
;;   (implies (evthmp-ev-theoremp (list 'not lit))
;;            (iff (evthmp-ev-theoremp (disjoin (cons lit clause)))
;;                 (evthmp-ev-theoremp (disjoin clause))))
;;   :hints (("Goal" :use
;;            ((:instance evthmp-ev-falsify
;;                        (x (disjoin clause))
;;                        (a (evthmp-ev-falsify (disjoin (cons lit clause)))))
;;             (:instance evthmp-ev-falsify
;;                        (x (list 'not lit))
;;                        (a (evthmp-ev-falsify (disjoin clause))))
;;             (:instance evthmp-ev-falsify
;;                        (x (disjoin (cons lit clause)))
;;                        (a (evthmp-ev-falsify (disjoin clause)))))))
;;   :otf-flg t)





