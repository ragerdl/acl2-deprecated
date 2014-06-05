; Copyright (C) 2013 Centaur Technology
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

;; A set of utility functions for finding or collecting subterms of a
;; term/clause that match some pattern.

(include-book "unify-subst")

;; Find one occurrence of a matching term.  Don't look
;; in lambda bodies.  Return the subterm.
(mutual-recursion
 (defun find-match (pat x initial-alist)
   (declare (xargs :guard (and (pseudo-termp pat)
                               (pseudo-termp x)
                               (alistp initial-alist))))
   (b* (((mv match ?alist) (simple-one-way-unify pat x initial-alist))
        ((when match) (mv t x))
        ((when (or (variablep x) (fquotep x))) (mv nil nil)))
     (find-match-list pat (cdr x) initial-alist)))

 (defun find-match-list (pat x initial-alist)
   (declare (xargs :guard (and (pseudo-termp pat)
                               (pseudo-term-listp x)
                               (alistp initial-alist))))
   (b* (((when (atom x)) (mv nil nil))
        ((mv ok subterm) (find-match pat (car x) initial-alist))
        ((when ok) (mv ok subterm)))
     (find-match-list pat (cdr x) initial-alist))))

;; This variant finds a literal in the clause that matches
(defun find-matching-literal-in-clause (pat clause initial-alist)
  (declare (xargs :guard (and (pseudo-termp pat)
                              (pseudo-term-listp clause)
                              (alistp initial-alist))))
  (b* (((when (atom clause)) (mv nil nil))
       ((mv match ?alist) (simple-one-way-unify pat (car clause)
                                                initial-alist))
       ((when match) (mv t (car clause))))
    (find-matching-literal-in-clause pat (cdr clause) initial-alist)))
    



;; Find as many occurrences as exist; return the list of subterms.
(mutual-recursion
 (defun find-matches (pat x initial-alist)
   (declare (xargs :guard (and (pseudo-termp pat)
                               (pseudo-termp x)
                               (alistp initial-alist))))
   (b* (((mv match ?alist) (simple-one-way-unify pat x initial-alist))
        ((when (or (variablep x) (fquotep x)))
         (and match (list x)))
        (rest (find-matches-list pat (cdr x) initial-alist)))
     (if match
         (cons x rest)
       rest)))

 (defun find-matches-list (pat x initial-alist)
   (declare (xargs :guard (and (pseudo-termp pat)
                               (pseudo-term-listp x)
                               (alistp initial-alist))))
   (if (atom x)
       nil
     (append (find-matches pat (car x) initial-alist)
             (find-matches-list pat (cdr x) initial-alist)))))

(flag::make-flag find-matches-flg find-matches)

(defthm-find-matches-flg
  (defthm pseudo-termp-find-match
    (implies (pseudo-termp x)
             (pseudo-termp (mv-nth 1 (find-match pat x initial-alist))))
    :flag find-matches)
  (defthm pseudo-termp-find-match-list
    (implies (pseudo-term-listp x)
             (pseudo-termp (mv-nth 1 (find-match-list pat x initial-alist))))
    :flag find-matches-list))

(defthm-find-matches-flg
  (defthm pseudo-term-listp-find-matches
    (implies (pseudo-termp x)
             (pseudo-term-listp (find-matches pat x initial-alist)))
    :flag find-matches)
  (defthm pseudo-term-listp-find-matches-list
    (implies (pseudo-term-listp x)
             (pseudo-term-listp (find-matches-list pat x initial-alist)))
    :flag find-matches-list))
