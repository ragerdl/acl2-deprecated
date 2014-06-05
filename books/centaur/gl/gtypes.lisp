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

(include-book "gobjectp")

(include-book "generic-geval")

;; (defun gobj-count (x)
;;   (declare (xargs :hints (("goal" :in-theory (enable gobj-fix)))))
;;   (let ((x (gobj-fix x)))
;;     (if (atom x)
;;         0
;;       (pattern-match x
;;         ((g-ite & then else)
;;          (+ 1 (gobj-count then) (gobj-count else)))
;;         (& 0)))))

;; (defthm gobj-count-gobj-fix
;;   (<= (gobj-count (gobj-fix x)) (gobj-count x))
;;   :rule-classes (:rewrite :linear))

;; (defthm gobj-count-g-ite->then
;;   (implies (and (gobjectp x) (g-ite-p x))
;;            (< (gobj-count (g-ite->then x))
;;               (gobj-count x)))
;;   :rule-classes (:rewrite :linear))

;; (defthm gobj-count-g-ite->else
;;   (implies (and (gobjectp x) (g-ite-p x))
;;            (< (gobj-count (g-ite->else x))
;;               (gobj-count x)))
;;   :rule-classes (:rewrite :linear))





;; -------------------------
;; Concrete
;; -------------------------


(defund gobject-hierarchy-lite (x)

; [Jared]: I found that calling gobject-hierarchy-bdd was taking around 50% of
; the time in the BDD-parameterized MPSADB proof.  To try to improve this, Sol
; (1) adjusted the interpreter so that it has a guard and doesn't need to try
; to gobj-fix the values for variables when it looks them up, which avoids a
; lot of gobject-hierarchy calls.  I then came up with this alternative to
; gobject-hierarchy that returns either 'general or 'concrete in the same
; cases, but never returns 'gobject.  This avoids having to recursively look at
; the object's guts for most of the general cases.  However, it still has to
; recursively process large cons trees, which can be expensive.

  (declare (xargs :guard t))
  (if (atom x)
      'concrete
    (mbe :logic
         (cond
          ((g-concrete-p x) 'general)
          ((g-boolean-p x)  nil)
          ((g-number-p x)   nil)
          ((g-ite-p x)      nil)
          ((g-apply-p x)    nil)
          ((g-var-p x)      nil)
          (t
           (let ((car (gobject-hierarchy-lite (car x))))
             (and car
                  (let ((cdr (gobject-hierarchy-lite (cdr x))))
                    (and cdr
                         (if (or (eq car 'general)
                                 (eq cdr 'general))
                             'general
                           'concrete)))))))
         :exec
         (if (symbolp (tag x))
             (case (tag x)
               (:g-concrete 'general)
               (:g-boolean  nil)
               (:g-number   nil)
               (:g-ite      nil)
               (:g-apply    nil)
               (:g-var      nil)
               (otherwise (gobject-hierarchy-lite (cdr x))))
           (let ((car (gobject-hierarchy-lite (car x))))
             (and car
                  (let ((cdr (gobject-hierarchy-lite (cdr x))))
                    (and cdr
                         (if (or (eq car 'general)
                                 (eq cdr 'general))
                             'general
                           'concrete)))))))))

(encapsulate
  ()
  (local (in-theory (enable gobject-hierarchy-lite)))

  (local (defthm crock
           (implies (and (gobject-hierarchy-lite x)
                         (not (equal (gobject-hierarchy-lite x) 'general)))
                    (equal (gobject-hierarchy-lite x) 'concrete))))

  (memoize 'gobject-hierarchy-lite
           :condition '(and (consp x)
                            ;; Any object with a g-keyword in its car will be so
                            ;; fast to decide that it isn't worth storing it.
                            (not (g-keyword-symbolp (car x))))))


;; (encapsulate
;;   ()
;;   (local (defthm crock
;;            (implies (and (not (equal (gobject-hierarchy x) 'gobject))
;;                          (not (equal (gobject-hierarchy x) 'general))
;;                          (gobject-hierarchy x))
;;                     (equal (gobject-hierarchy x) 'concrete))
;;            :hints(("Goal" :in-theory (enable gobject-hierarchy)))))

;;   (defthm gobject-hierarchy-lite-redef
;;     (equal (gobject-hierarchy-lite x)
;;            (let ((result (gobject-hierarchy x)))
;;              (if (or (equal result 'general)
;;                      (equal result 'concrete))
;;                  result
;;                nil)))
;;     :hints(("Goal"
;;             :induct (gobject-hierarchy x)
;;             :in-theory (enable gobject-hierarchy
;;                                gobject-hierarchy-lite)))))

;; (encapsulate
;;   ()
;;   (local (in-theory (disable gobject-hierarchy-lite-redef)))

;;   (local (defthm crock
;;            (implies (and (not (equal (gobject-hierarchy-aig x) 'gobject))
;;                          (not (equal (gobject-hierarchy-aig x) 'general))
;;                          (gobject-hierarchy-aig x))
;;                     (equal (gobject-hierarchy-aig x) 'concrete))
;;            :hints(("Goal" :in-theory (enable gobject-hierarchy-aig)))))

;;   (defthmd gobject-hierarchy-lite->aig
;;            (equal (gobject-hierarchy-lite x)
;;                   (let ((result (gobject-hierarchy-aig x)))
;;                     (if (or (equal result 'general)
;;                             (equal result 'concrete))
;;                         result
;;                       nil)))
;;            :hints(("Goal"
;;                    :induct (gobject-hierarchy-aig x)
;;                    :in-theory (enable gobject-hierarchy-aig
;;                                       gobject-hierarchy-lite))))

;;   (theory-invariant
;;    (incompatible (:rewrite gobject-hierarchy-lite-redef)
;;                  (:rewrite gobject-hierarchy-lite->aig))))

;; (encapsulate
;;   ()
;;   (local (in-theory (disable gobject-hierarchy-lite-redef)))

;;   (local (defthm crock
;;            (implies (and (not (equal (gobject-hierarchy-bdd x) 'gobject))
;;                          (not (equal (gobject-hierarchy-bdd x) 'general))
;;                          (gobject-hierarchy-bdd x))
;;                     (equal (gobject-hierarchy-bdd x) 'concrete))
;;            :hints(("Goal" :in-theory (enable gobject-hierarchy-bdd)))))

;;   (defthmd gobject-hierarchy-lite->bdd
;;     (equal (gobject-hierarchy-lite x)
;;            (let ((result (gobject-hierarchy-bdd x)))
;;              (if (or (equal result 'general)
;;                      (equal result 'concrete))
;;                  result
;;                nil)))
;;     :hints(("Goal"
;;             :induct (gobject-hierarchy-bdd x)
;;             :in-theory (enable gobject-hierarchy-bdd
;;                                gobject-hierarchy-lite))))

;;   (theory-invariant
;;    (incompatible (:rewrite gobject-hierarchy-lite-redef)
;;                  (:rewrite gobject-hierarchy-lite->bdd))))









;; (defn concretep (x)
;;   (declare (inline tag))
;;   (or (atom x)
;;       (and (not (g-keyword-symbolp (tag x)))
;;            (concretep (car x))
;;            (concretep (cdr x)))))


;; (memoize 'concretep :condition '(consp x))

;; (defthm eval-concrete-gobjectp
;;   (implies (and (gobjectp x)
;;                 (concretep x))
;;            (equal (eval-g-base x b) x)))

;; (in-theory (disable concretep))

(defn concrete-gobjectp (x)
  (eq (gobject-hierarchy-lite x) 'concrete))


(in-theory (disable concrete-gobjectp))

(defn mk-g-concrete (x)
  (if (concrete-gobjectp x)
      x
    (g-concrete x)))

(in-theory (disable mk-g-concrete))


;; Doesn't do the hierarchical check, only avoids consing when the input is an
;; atom
(defn g-concrete-quote (x)
  (if (and (atom x)
           (not (g-keyword-symbolp x)))
      x
    (g-concrete x)))

(in-theory (disable g-concrete-quote))


;; -------------------------
;; ITE
;; -------------------------

(defun mk-g-ite (c x y)
  (declare (xargs :guard t))
  (cond ((atom c) (if c x y))
        ((hqual x y) x)
        ((not (g-keyword-symbolp (tag c)))
         ;; c is just a cons
         x)
        ((eq (tag c) :g-number) x)
        ((eq (tag c) :g-concrete)
         (if (g-concrete->obj c) x y))
        (t (g-ite c x y))))
;;      (list* :g-ite c x y))))

(in-theory (disable mk-g-ite))




;; -------------------------
;; Boolean
;; -------------------------

(defun mk-g-boolean (bdd)
  (declare (xargs :guard t))
  (if (booleanp bdd)
      bdd
    (g-boolean bdd)))

(in-theory (disable mk-g-boolean))




;; -------------------------
;; Number
;; -------------------------

(defun norm-bvec-s (v)
  (declare (xargs :guard T))
  (if (boolean-listp v)
      (bfr-list->s v nil)
    v))

(defun norm-bvec-u (v)
  (declare (xargs :guard t))
  (if (boolean-listp v)
      (bfr-list->u v nil)
    v))


(defun mk-g-number-fn (rnum rden inum iden)
  (declare (xargs :guard t))
  (b* ((rnum-norm (norm-bvec-s rnum))
       (rden-norm (norm-bvec-u rden))
       (inum-norm (norm-bvec-s inum))
       (iden-norm (norm-bvec-u iden)))
    (if (and (integerp rnum-norm) (natp rden-norm)
             (integerp inum-norm) (natp iden-norm))
        (components-to-number rnum-norm rden-norm inum-norm iden-norm)
      (flet ((to-uvec (n)
                      (if (natp n)
                          (n2v n)
                        n))
             (to-svec (n)
                      (if (integerp n)
                          (i2v n)
                        n)))
        (let* ((rst (and (not (or (eql iden 1) (equal iden '(t)))) (list (to-uvec iden))))
               (rst (and (not (or (eql inum 0) (equal inum '(nil)))) (cons (to-svec inum) rst)))
               (rst (and (or rst (not (or (eql rden 1) (equal rden '(t))))) (cons (to-uvec rden) rst))))
          (g-number (cons (to-svec rnum) rst)))))))


(defmacro mk-g-number (rnum &optional
                              (rden '1)
                              (inum '0)
                              (iden '1))
  `(mk-g-number-fn ,rnum ,rden ,inum ,iden))

(add-macro-alias mk-g-number mk-g-number-fn)


(in-theory (disable mk-g-number))


;; -------------------------
;; Cons
;; -------------------------

;; A cons of two gobjects is, most often, itself a gobject which evaluates to
;; the cons of the evaluations of the two inputs.  Gl-cons ensures that this is
;; the case, that is, if the first is a g-keyword-symbol it wraps it in a g-concrete.


(defun gl-list-macro (lst)
  (if (atom lst)
      nil
    `(gl-cons ,(car lst)
              ,(gl-list-macro (cdr lst)))))

(defmacro gl-list (&rest args)
  (gl-list-macro args))



(defsection gobj-listp
  (defund gobj-listp (x)
    (declare (xargs :guard t))
    (if (atom x)
        (eq x nil)
      (and (not (g-keyword-symbolp (car x)))
           (gobj-listp (cdr x)))))

  (local (in-theory (enable gobj-listp)))

  (defthm gobj-listp-of-gl-cons
    (implies (gobj-listp x)
             (gobj-listp (gl-cons k x)))
    :hints(("Goal" :in-theory (enable gl-cons tag)))))


(mutual-recursion
 (defun gobj-depends-on (k p x)
   (if (atom x)
       nil
     (pattern-match x
       ((g-boolean b) (pbfr-depends-on k p b))
       ((g-number n)
        (b* (((mv rn rd in id) (break-g-number n)))
          (or (pbfr-list-depends-on k p rn)
              (pbfr-list-depends-on k p rd)
              (pbfr-list-depends-on k p in)
              (pbfr-list-depends-on k p id))))
       ((g-ite test then else)
        (or (gobj-depends-on k p test)
            (gobj-depends-on k p then)
            (gobj-depends-on k p else)))
       ((g-concrete &) nil)
       ((g-var &) nil)
       ((g-apply & args) (gobj-list-depends-on k p args))
       (& (or (gobj-depends-on k p (car x))
              (gobj-depends-on k p (cdr x)))))))
 (defun gobj-list-depends-on (k p x)
   (if (atom x)
       nil
     (or (gobj-depends-on k p (car x))
         (gobj-list-depends-on k p (cdr x))))))

