#|-*-Lisp-*-=================================================================|#
#|                                                                           |#
#| coi: Computational Object Inference                                       |#
#|                                                                           |#
#|===========================================================================|#
;; defs.lisp
;; Definitions of our path functions


;; GROSS - This file is really bad!
;;
;; The library we have developed here for reasoning about paths is pretty nice.
;; Ultimately we want it to replace the current theory of dominates and diverge
;; which is found in records/path.lisp.  But unfortunately, it is hard to make
;; everything work, and we have NO TIME.
;;
;; So here is what we are going to do.  We create this file which is just a
;; redundant list of definitions.  These definitions can be included into the
;; dtrees library, so that it can write theorems about dominates, etc.
;; 
;; Dtrees will then only LOCALLY include the top.lisp, so that it can reason
;; about dominates and diverge without exporting our theory.  This is basically
;; the same coverup trick we do with arithmetic books.
;;
;; But this is really bad!  We want to get rid of this file and just let dtrees
;; include the whole, improved theory about paths.  We just don't have time to
;; make it all work with records/path.lisp yet.

(in-package "PATH")
(include-book "../lists/basic")

(defund dominates (x y)
  (declare (type t x y))
  (if (consp x)
      (and (consp y)
           (equal (car x) (car y))
           (dominates (cdr x) (cdr y)))
    t))

(defund strictly-dominates (x y)
  (declare (type t x y))
  (and (dominates x y)
       (not (list::equiv x y))))

(defund dominates-some (a x)
  (declare (type t a x))
  (if (consp x)
      (or (dominates a (car x))
          (dominates-some a (cdr x)))
    nil))

(defund strictly-dominates-some (a x)
  (declare (type t a x))
  (if (consp x)
      (or (strictly-dominates a (car x))
          (strictly-dominates-some a (cdr x)))
    nil))

(defund dominated-by-some (a x)
  (declare (type t a x))
  (if (consp x)
      (or (dominates (car x) a)
          (dominated-by-some a (cdr x)))
    nil))

(defund strictly-dominated-by-some (a x)
  (declare (type t a x))
  (if (consp x)
      (or (strictly-dominates (car x) a)
          (strictly-dominated-by-some a (cdr x)))
    nil))

(defund first-dominator (a x)
  (declare (type t a x))
  (if (atom x)
      nil
    (if (dominates (car x) a)
        (car x)
      (first-dominator a (cdr x)))))

(defund diverge (x y)
  (declare (type t x y))
  (and (not (dominates x y))
       (not (dominates y x))))

(defund diverges-from-all (a x)
  (declare (type t a x))
  (if (consp x)
      (and (diverge a (car x))
           (diverges-from-all a (cdr x)))
    t))

(defund all-diverge-from-all (x y)
  (declare (type t x y))
  (if (consp x)
      (and (diverges-from-all (car x) y)
           (all-diverge-from-all (cdr x) y))
    t))

(defund all-diverge (x)
  (declare (type t x))
  (if (consp x)
      (and (diverges-from-all (car x) (cdr x))
           (all-diverge (cdr x)))
    t))
