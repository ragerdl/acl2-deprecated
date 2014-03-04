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
; fast-alist-pop.lisp
; Original authors: Sol Swords <sswords@centtech.com>
;                   Jared Davis <jared@centtech.com>

(in-package "ACL2")
(include-book "tools/include-raw" :dir :system)
(include-book "xdoc/top" :dir :system)

(defttag fast-alist-pop)

(defxdoc fast-alist-pop
  :parents (hons-and-memoization)
  :short "@('fast-alist-pop') removes the first key-value pair from a fast alist."
  :long "<p>This is a user extension to the ACL2 (in particular, ACL2H) system.
It may eventually be added to acl2h proper, but until then it requires a trust
tag since it hasn't been thoroughly vetted for soundness.</p>

<p>Logically, fast-alist-pop is just @('CDR').  However, it has a special
side-effect when called on a fast alist (see @(see hons-acons)).  A fast alist
has a backing hash table mapping its keys to their corresponding (unshadowed)
pairs, which supports constant-time alist lookup.  @(see Hons-acons) adds
key/value pairs to the alist and its backing hash table, and @(see hons-get)
performs constant-time lookup by finding the backing hash table and looking up
the key in the table.  However, logically, hons-get is just @(see
hons-assoc-equal), a more traditional alist lookup function that traverses the
alist until it finds the matching key.  Correspondingly, fast-alist-pop is
logically just CDR, but it removes the key/value pair corresponding to the CAR
of the alist from its backing hash table.</p>

<p>To maintain both the consistency of the alist with the backing hash table
and constant-time performance, fast-alist-pop has a guard requiring that the
key of that first pair not be bound in the cdr of the alist.  Otherwise, simply
removing that pair from the hash table would not be correct, since the key
would remain in the alist bound to some value, which could only be discovered
by linearly traversing the alist.</p>")

(defun fast-alist-pop (x)
  "Has an under-the-hood definition."
  (declare (xargs :guard (or (not (consp x))
                             (not (consp (car x)))
                             (not (hons-assoc-equal (caar x) (cdr x))))))
  (mbe :logic (cdr x)
       :exec
       (progn$
        (er hard? 'fast-alist-pop
            "Under the hood definition not installed?")
        (and (consp x)
             (cdr x)))))

; (depends-on "fast-alist-pop-raw.lsp")
(include-raw "fast-alist-pop-raw.lsp")

#||

(include-book
 "tools/bstar" :dir :system)

(b* ((alist (hons-acons 'a 1 nil))
     (alist (hons-acons 'b 2 alist))
     (alist (fast-alist-pop alist)))
  (and (not (hons-get 'b alist))
       (equal (hons-get 'a alist) '(a . 1))))

||#
