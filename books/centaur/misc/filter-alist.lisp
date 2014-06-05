; Centaur Miscellaneous Books
; Copyright (C) 2008-2011 Centaur Technology
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

; filter-alist.lisp -- generic function to filter an alist

(in-package "ACL2")
(include-book "centaur/misc/fast-alists" :dir :system)
(local (include-book "std/lists/rev" :dir :system))


(defstub filter-alist-criteria (entry) t)

(defund filter-alist (x keep skip)
  (cond ((atom x)
         (mv keep skip))
        ((atom (car x))
         (filter-alist (cdr x) keep skip))
        ((filter-alist-criteria (car x))
         (filter-alist (cdr x) (cons (car x) keep) skip))
        (t
         (filter-alist (cdr x) keep (cons (car x) skip)))))

(local (defun filter-alist-keep (x)
         (cond ((atom x)
                nil)
               ((atom (car x))
                (filter-alist-keep (cdr x)))
               ((filter-alist-criteria (car x))
                (cons (car x) (filter-alist-keep (cdr x))))
               (t
                (filter-alist-keep (cdr x))))))

(local (defun filter-alist-skip (x)
         (cond ((atom x)
                nil)
               ((atom (car x))
                (filter-alist-skip (cdr x)))
               ((filter-alist-criteria (car x))
                (filter-alist-skip (cdr x)))
               (t
                (cons (car x) (filter-alist-skip (cdr x)))))))

(local
 (defsection filter-alist-redef

   (local (in-theory (enable filter-alist)))

   (local (defthm l0
            (equal (mv-nth 0 (filter-alist x keep skip))
                   (revappend (filter-alist-keep x) keep))))

   (local (defthm l1
            (equal (mv-nth 1 (filter-alist x keep skip))
                   (revappend (filter-alist-skip x) skip))))

   (defthm filter-alist-redef
     (equal (filter-alist x keep skip)
            (mv (revappend (filter-alist-keep x) keep)
                (revappend (filter-alist-skip x) skip))))))

(local
 (encapsulate
   ()
   (local (defthm l0
            (implies (not (hons-assoc-equal a x))
                     (not (hons-assoc-equal a (filter-alist-keep x))))))

   (defthm hons-assoc-equal-of-filter-alist-keep
     (implies (no-duplicatesp-equal (alist-keys x))
              (equal (hons-assoc-equal key (filter-alist-keep x))
                     (if (filter-alist-criteria (hons-assoc-equal key x))
                         (hons-assoc-equal key x)
                       nil))))))

(local
 (encapsulate
   ()
   (local (defthm l0
            (implies (not (hons-assoc-equal a x))
                     (not (hons-assoc-equal a (filter-alist-skip x))))))

   (defthm hons-assoc-equal-of-filter-alist-skip
     (implies (no-duplicatesp-equal (alist-keys x))
              (equal (hons-assoc-equal key (filter-alist-skip x))
                     (if (filter-alist-criteria (hons-assoc-equal key x))
                         nil
                       (hons-assoc-equal key x)))))))


(encapsulate
  ()
  (local (defthm l0
           (implies (no-duplicatesp-equal (alist-keys x))
                    (equal (hons-assoc-equal key (rev x))
                           (hons-assoc-equal key x)))
           :hints(("Goal"
                   :induct (len x)
                   :in-theory (enable hons-assoc-equal)))))

  (local (defthm l1
           (implies (no-duplicatesp-equal (alist-keys x))
                    (no-duplicatesp-equal (alist-keys (filter-alist-keep x))))))

  (local (defthm l2
           (implies (no-duplicatesp-equal (alist-keys x))
                    (no-duplicatesp-equal (alist-keys (filter-alist-skip x))))))

  (defthm filter-alist-correct
    ;; Basic correctness property that can be functionally instantiated
    ;; Note: this is not a good rewrite rule; use :rule-classes nil instead!
    (b* (((mv keep skip) (filter-alist x nil nil)))
      (implies (no-duplicatesp-equal (alist-keys x))
               (equal (hons-assoc-equal key x)
                      (or (hons-assoc-equal key keep)
                          (hons-assoc-equal key skip)))))
    :rule-classes nil))
