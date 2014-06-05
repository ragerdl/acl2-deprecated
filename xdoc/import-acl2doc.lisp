; XDOC Documentation System for ACL2
; Copyright (C) 2009-2013 Centaur Technology
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

(in-package "ACL2")
(include-book "write-acl2-xdoc")
(set-state-ok t)
(program)

; Historically this file was used to read in the DEFDOC style ACL2
; documentation from the ACL2 Sources, and also from any books.  However,
; starting in revision 2168, the ACL2 system documentation is now in XDOC
; format and available in the system/doc books.  So now we can just load it
; instead of jumping through hoops to import it.  (Actually, for awhile there
; still remained defdoc-style documentation in the ACL2 sources.  But that was
; no longer true as of the time of the release of ACL 2 Version 6.4.)

(include-book "system/doc/acl2-doc-wrap" :dir :system)


; Hack for broken links to be reported differently in the community manual.

#!XDOC
(defun remove-topics-by-name (topics names)
  (cond ((atom topics)
         nil)
        ((member (cdr (assoc :name (car topics))) names)
         (remove-topics-by-name (cdr topics) names))
        (t
         (cons (car topics) (remove-topics-by-name (cdr topics) names)))))

#!XDOC
(table xdoc 'doc
       (remove-topics-by-name (get-xdoc-table world)
                              '(acl2::acl2 acl2::broken-link)))

(defxdoc acl2::acl2
  :short "Documentation for the <a
  href=\"http://www.cs.utexas.edu/users/moore/acl2\">ACL2 Theorem Prover</a>."

  :long "<p>This is a parent topic for ACL2 system @(see documentation).  (We
take some liberties with the hierarchy present in the ACL2 User's Manual to
integrate certain topics into more appropriate places.)</p>")

(defxdoc acl2::broken-link
  :parents (documentation)
  :short "Placeholder for broken links in a fancy xdoc manual."

  :long "<p>Sorry friend, the topic you were trying to reach doesn't exist.</p>

<p>Sometimes this happens because we make a link to the wrong package or just
misspell something.  A quick search (or even <i>jump to</i>) might help you
find what you want.</p>")

;; ; Initial import of acl2 system documentation.  We do this before including any
;; ; books other than the basic portcullis, because we don't want any libraries
;; ; loaded when we import the system-level documentation.
;; ;
;; ; One other minor fixup: In ACL2, a top-level topic has a parent of itself.  We
;; ; change all such top-level topics so that they have a parent of acl2::acl2.

;; (defun remove-alist-key (key x)
;;   (cond ((atom x)
;;          nil)
;;         ((atom (car x))
;;          (remove-alist-key key (cdr x)))
;;         ((equal (caar x) key)
;;          (remove-alist-key key (cdr x)))
;;         (t
;;          (cons (car x) (remove-alist-key key (cdr x))))))

;; (defun change-self-parent-to-acl2 (topic)
;;   (let ((name    (cdr (assoc :name topic)))
;;         (parents (cdr (assoc :parents topic))))
;;     (if (member name parents)
;;         (acons :parents
;;                (cons 'acl2::acl2 (remove-equal name parents))
;;                (remove-alist-key :parents topic))
;;       topic)))

;; (defun change-self-parents-to-acl2 (topics)
;;   (if (atom topics)
;;       nil
;;     (cons (change-self-parent-to-acl2 (car topics))
;;           (change-self-parents-to-acl2 (cdr topics)))))

;; (defun add-from-acl2 (topics)
;;   (if (atom topics)
;;       nil
;;     (cons (acons :from "ACL2 Sources" (car topics))
;;           (add-from-acl2 (cdr topics)))))

;; (make-event
;;  (mv-let (er val state)
;;    (time$ (acl2::write-xdoc-alist)
;;           :msg "; Importing ground-zero acl2 :doc topics: ~st sec, ~sa bytes~%"
;;           :mintime 1)
;;    (declare (ignore er val))
;;    (let* ((topics (acl2::f-get-global 'acl2::xdoc-alist state))
;;           (topics (change-self-parents-to-acl2 topics))
;;           (topics (add-from-acl2 topics)))
;;      (value `(defconst *acl2-ground-zero-topics* ',topics)))))

(include-book "base")
(include-book "tools/bstar" :dir :system)

;; ;; Actually install the ground-zero topics
;; #!XDOC
;; (table xdoc 'doc

;; ; Something subtle about this is, what do we do if there is both an ACL2 :doc
;; ; topic and an XDOC topic?  As of the ACL2 Version 6.4 release, that is no
;; ; longer possible, since ACL2 :doc strings have been removed from the source
;; ; code.  But we keep the following historical comment for now....
;; ;
;; ; Originally we appended the *acl2-ground-zero-topics* to (get-xdoc-table
;; ; world), which meant that built-in ACL2 documentation "won" and overwrote the
;; ; xdoc documentation.  But when I documented the system/io.lisp book, I found
;; ; that this wasn't what I wanted, because it meant stupid tiny little
;; ; placeholder documentation for things like read-char$ was overwriting the much
;; ; nicer XDOC documentation for it.
;; ;
;; ; Arguably we should do some kind of smart merge, but, well, this *is* xdoc
;; ; after all.  So I'm just going to say ACL2 loses, and if someone cares enough
;; ; to come up with something better, power to them.

;;        (append (get-xdoc-table world)
;;                *acl2-ground-zero-topics*))


(include-book "system/origin" :dir :system)

(defun defdoc-include-book-path (name wrld)

; Tool from Matt Kaufmann for figuring out where a DEFDOC event comes from.
;
; We return nil if there is no defdoc for name.  Otherwise, we return the
; include-book path (with closest book first, hence opposite from the order
; typically displayed by :pe) for the most recent defdoc of name, else
; :built-in if that path is nil.

  (declare (xargs :mode :program))
  (cond ((endp wrld)
         nil)
        (t (or (let ((x (car wrld)))
                 (case-match x
                   (('EVENT-LANDMARK 'GLOBAL-VALUE . event-tuple)
                    (let ((form (access-event-tuple-form event-tuple)))
                      (case-match form
                        (('DEFDOC !name . &)
                         ;; Matt's version didn't reverse these, but mine
                         ;; does for compatibility with the origin book.
                         (or (reverse (global-val 'include-book-path wrld))
                             ;; Originally we returned T here.  Now I return
                             ;; :built-in for better compatibility with
                             ;; extend-topic-with-origin.  I ran into a weird
                             ;; problem with e0-ordinalp here.
                             :built-in)))))))
               (defdoc-include-book-path name (cdr wrld))))))

#!XDOC
(defun extend-topic-with-origin (topic state)
  ;; Returns (MV TOPIC STATE)
  (b* ((name (cdr (assoc :name topic)))
       (from (cdr (assoc :from topic)))

       ((when from)
        (er hard? 'extend-topic-with-origin
            "Topic ~x0 already has :from." name)
        (mv topic state))

       ((unless (symbolp name))
        (er hard? 'extend-topic-with-origin
            "Topic with non-symbolic name ~x0" name)
        (mv topic state))

       ((mv er val state)
        (acl2::origin-fn name state))
       ((mv er val)
        (b* (((unless er)
              (mv er val))
             ;; This can occur at least in cases such as DEFDOC, which do not
             ;; introduce logical names.
             ;(- (cw "~x0: unknown: ~@1~%" name er))
             (new-val (acl2::defdoc-include-book-path name (w state)))
             ((when new-val)
              ;(cw "~x0: tried harder and found ~x1.~%" name new-val)
              (mv nil new-val)))
          ;(cw "~x0: tried harder and still failed." name)
          (mv er val)))

       ((when er)
        (mv (acons :from "Unknown" topic)
            state))

       ((when (eq val :built-in))
        ;;(cw "~x0: built-in~%" name)
        (mv (acons :from "ACL2 Sources" topic)
            state))

       ((when (eq val :top-level))
        ;;(cw "~x0: current session.~%" name)
        (mv (acons :from "Current Interactive Session" topic)
            state))

       ((when (and (consp val)
                   (string-listp val)))
        (b* ((bookname (car (last val)))
             (bookname (normalize-bookname bookname state)))
          ;; (cw "~x0: ~x1~%" name bookname)
          (mv (acons :from bookname topic)
              state))))

    (er hard? 'extend-topic-with-origin
        "origin-fn returned unexpected value ~x0." val)
    (mv topic state)))

#!XDOC
(defun extend-topics-with-origins (topics state)
  (b* (((when (atom topics))
        (mv nil state))
       ((mv first state)
        (extend-topic-with-origin (car topics) state))
       ((mv rest state)
        (extend-topics-with-origins (cdr topics) state)))
    (mv (cons first rest) state)))

#!XDOC
(defun all-topic-names (topics)
  (if (atom topics)
      nil
    (cons (cdr (assoc :name (car topics)))
          (all-topic-names (cdr topics)))))

#!XDOC
(defun set-diff-fal (x fal)
  (cond ((atom x)
         nil)
        ((hons-get (car x) fal)
         (set-diff-fal (cdr x) fal))
        (t
         (cons (car x)
               (set-diff-fal (cdr x) fal)))))

#!XDOC
(defun extend-skip-fal (built-ins fal)
  (if (atom built-ins)
      fal
    (hons-acons (car built-ins) t
                (extend-skip-fal (cdr built-ins) fal))))

(include-book "verbosep")

#!XDOC
(defmacro import-acl2doc ()
  ;; This is for refreshing the documentation to reflect topics documented in
  ;; libraries.  We throw away any defdoc topics for names that already have
  ;; documentation.  This saves us the work of repeatedly importing
  ;; documentation topics, and usually allows XDOC topics to override ACL2
  ;; defdoc topics.
  `(make-event
    (b* ((all-topics (get-xdoc-table (w state)))
         (names      (xdoc::all-topic-names all-topics))
         (skip-fal   (make-fast-alist (pairlis$ names nil)))
         ((mv ?er ?val state)
          (time$ (acl2::write-xdoc-alist :skip-topics-fal skip-fal)
                 :msg "~|; Importing acl2 :doc topics: ~st sec, ~sa bytes~%"
                 :mintime 1))
         (new-topics (acl2::f-get-global 'acl2::xdoc-alist state))
         ((mv new-topics state)
          (extend-topics-with-origins new-topics state)))
      (value `(table xdoc 'doc
                     (append ',new-topics (get-xdoc-table world)))))))


#||
;; Test code:

(len (xdoc::get-xdoc-table (w state)))  ;; 1546
(make-event
 `(defconst *prev-names*
    ',(xdoc::all-topic-names (xdoc::get-xdoc-table (w state)))))
(include-book
 "ihs/logops-lemmas" :dir :system)
(len (xdoc::get-xdoc-table (w state)))  ;; 1546
(time$ (xdoc::import-acl2doc))  ;; .2 seconds, converting all that ihs doc
(len (xdoc::get-xdoc-table (w state)))  ;; 1841
(set-difference-equal
 (xdoc::all-topic-names (xdoc::get-xdoc-table (w state)))
 *prev-names*)
(time$ (xdoc::import-acl2doc))  ;; almost no time
(len (xdoc::get-xdoc-table (w state))) ;; 1841


(defun all-topic-froms (topics)
  (if (atom topics)
      nil
    (cons (cdr (assoc :from (car topics)))
          (all-topic-froms (cdr topics)))))

(let ((topics (xdoc::get-xdoc-table (w state))))
  (pairlis$ (xdoc::all-topic-names topics)
            (all-topic-froms topics)))

;; ACL2::UNSIGNED-BYTE-P-LEMMAS: unknown: Not logical name: 
;; ACL2::UNSIGNED-BYTE-P-LEMMAS.
;; ACL2::SIGNED-BYTE-P-LEMMAS: unknown: Not logical name: 
;; ACL2::SIGNED-BYTE-P-LEMMAS.
;; ACL2::IHS: unknown: Not logical name: ACL2::IHS.
;; ACL2::DATA-STRUCTURES: unknown: Not logical name: ACL2::DATA-STRUCTURES.
;; ACL2::B*-BINDERS: unknown: Not logical name: ACL2::B*-BINDERS.

(acl2::defdoc-include-book-path 'acl2::ihs (w state))



||#
