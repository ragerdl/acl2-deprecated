; Converter From ACL2 System Documentation to Text
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
; Original author: Jared Davis <jared@centtech.com>
; 10/29/2013: Mods made by Matt Kaufmann to support Emacs-based ACL2-Doc browser

(in-package "XDOC")
(set-state-ok t)
(include-book "render-doc-base")
(program)

;; Load the ACL2 system documentation and throw away any other topics (which
;; might be GPL'd) to ensure that only pure BSD-licensed topics are included.

(table xdoc 'doc acl2::*acl2-sources-xdoc-topics*)

(value-triple (len (get-xdoc-table (w state))))

(defttag :open-output-channel!)

(defun remove-acl2-parent (topics acc)
  (cond ((endp topics) (reverse acc))
        (t (remove-acl2-parent
            (cdr topics)
            (cons (cond
                   ((and (eq (cdr (assoc-eq :name (car topics)))
                             'acl2::acl2)
                         (equal (cdr (assoc-eq :parents (car topics)))
                                '(acl2::top)))
                    (put-assoc-eq :parents
                                  nil
                                  (car topics)))
                   (t (car topics)))
                  acc)))))

(acl2::defconsts
 (& & state)
 (state-global-let*
  ((current-package "ACL2" set-current-package-state))
  (b* ((all-topics (remove-acl2-parent (get-xdoc-table (w state)) nil))
       ((mv rendered state)
        (render-topics all-topics all-topics state))
       (rendered (split-acl2-topics rendered nil nil nil))
       (- (cw "Writing rendered-doc.lsp~%"))
       ((mv channel state) (open-output-channel! "rendered-doc.lsp"
                                                 :character state))
       ((unless channel)
        (cw "can't open rendered-doc.lsp for output.")
        (acl2::silent-error state))
       (state (princ$ "; Documentation for the ACL2 Theorem Prover
; WARNING: GENERATED FILE, DO NOT HAND EDIT!
; The contents of this file are derived from ACL2 Community Book
; books/system/acl2-doc.lisp.

; ACL2 Version 6.4 -- A Computational Logic for Applicative Common Lisp
; Copyright (C) 2014, Regents of the University of Texas

; This version of ACL2 is a descendent of ACL2 Version 1.9, Copyright
; (C) 1997 Computational Logic, Inc.  See the documentation topic NOTE-2-0.

; This program is free software; you can redistribute it and/or modify
; it under the terms of the LICENSE file distributed with ACL2.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; LICENSE for more details.

; Here are the original authors of books/system/acl2-doc.lisp.
; Additional contributions may have been made to that file by members
; of the ACL2 community.

; Written by:  Matt Kaufmann               and J Strother Moore
; email:       Kaufmann@cs.utexas.edu      and Moore@cs.utexas.edu
; Department of Computer Science
; University of Texas at Austin
; Austin, TX 78701 U.S.A.

; WARNING: This file is generated from ACL2 Community Book
; books/system/acl2-doc.lisp.  To edit ACL2 documentation modify that
; file, not this one!  Instructions are just above the in-package form
; in that book.

(in-package \"ACL2\")

(defconst *acl2-system-documentation* '"
                      channel state))
       (state (fms! "~x0"
                    (list (cons #\0 rendered))
                    channel state nil))
       (state (fms! ")" nil channel state nil))
       (state (newline channel state))
       (state (close-output-channel channel state)))
      (value nil))))
