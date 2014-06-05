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
(include-book "support")
(include-book "std/strings/cat" :dir :system)
(include-book "centaur/fty/fixtype" :dir :system)
(set-state-ok t)

(defxdoc defenum
  :parents (std/util)
  :short "Introduce an enumeration type, like an @('enum') in C."

  :long "<p>General form:</p>
@({
 (defenum name
   elements
   &key mode         ; current defun-mode by default
        parents      ; nil by default
        short        ; nil by default
        long         ; nil by default
        )
})

<p>For example,</p>

@({
 (defenum day-p
   (:monday :tuesday :wednesday :thursday :friday :saturday :sunday))
})

<p>results in a new function, @('(day-p x)'), that recognizes @(':monday'),
@(':tuesday'), etc.</p>

<h3>Usage and Options</h3>

<p>I often use keyword symbols as the elements, but any objects (even conses)
can be used.</p>

<p>The optional @(':mode') keyword can be set to @(':logic') or @(':program')
to introduce the recognizer in logic or program mode.  The default is whatever
the current default defun-mode is for ACL2, i.e., if you are already in program
mode, it will default to program mode, etc.</p>

<p>The optional @(':parents'), @(':short'), and @(':long') parameters are like
those in @(see xdoc::defxdoc).</p>

<h3>Performance Notes</h3>

<p>The recognizer just tests its argument against the elements, in order.
Because of this, you might want to order your elements so that the most common
elements come first.  For instance, @('day-p') will be fastest on @(':monday')
and slowest on @(':sunday').</p>

<p>The recognizer uses @(see eq) or @(see eql) checks where possible, so if
your enumeration includes a mix of, say, conses and atom like symbols, you may
wish to put the atoms first.</p>

<p>Checking the argument against each element is probably a perfectly good
strategy when the number of elements is small (perhaps fewer than 20) and when
the equality checks are relatively fast (e.g., symbols, characters, numbers).
It is probably is not a good strategy otherwise.  If you want to use defenum
for something more complex, it might be best to modify it to adaptively use a
fast alist or other schemes, based on the elements it is given.</p>")

(defund defenum-members-to-tests (members xvar)
  ;; Generate ((equal xvar member1) (equal xvar member2) ...), except use EQ or
  ;; EQL instead of EQUAL where possible.
  (declare (xargs :guard t))
  (if (atom members)
      nil
    (let ((e (car members)))
      (cons (cond ((symbolp e)
                   `(eq ,xvar ',e))
                  ((eqlablep e)
                   `(eql ,xvar ',e))
                  (t
                   `(equal ,xvar ',e)))
            (defenum-members-to-tests (cdr members) xvar)))))

(defund defenum-members-to-tests-equal (members xvar)
  ;; Generate ((equal xvar member1) (equal xvar member2) ...)
  (declare (xargs :guard t))
  (if (atom members)
      nil
    (let ((e (car members)))
      (cons `(equal ,xvar ',e)
            (defenum-members-to-tests-equal (cdr members) xvar)))))

; (defenum-members-to-tests '(:a :b 3 5 #\a "foo" '(1 . 2)) 'x)

(defun defenum-deduce-type-set (members)
  ;; Figure out the best type set that covers all of members.
  (declare (xargs :mode :program))
  (if (atom members)
      0
    (acl2::ts-union
     (acl2::type-set-quote (car members))
     (defenum-deduce-type-set (cdr members)))))

;(acl2::decode-type-set
; (defenum-deduce-type-set '(:foo :bar 3 5)))
;  -->
; (ACL2::TS-UNION ACL2::*TS-POSITIVE-INTEGER*
;                 ACL2::*TS-NON-T-NON-NIL-SYMBOL*)

(defun dumb-collect-duplicates (x acc)
  (declare (xargs :mode :program))
  (cond ((atom x)
         acc)
        ((and (member-equal (car x) (cdr x))
              (not (member-equal (car x) acc)))
         (dumb-collect-duplicates (cdr x)
                                  (cons (car x) acc)))
        (t
         (dumb-collect-duplicates (cdr x) acc))))

(defun strip-p-from-symbol (name)
  ;; FOO-P --> FOO
  (let* ((sname (symbol-name name))
         (len   (length sname)))
    (if (and (<= 2 len)
             (equal (char sname (- len 1)) #\P)
             (equal (char sname (- len 2)) #\-))
        (intern-in-package-of-symbol (subseq sname 0 (- len 2))
                                     name)
      name)))

(defun defenum-fn (name members mode parents short long defaultp default state)
  (declare (xargs :mode :program))
  (b* ((__function__ 'defenum)
       ((unless (symbolp name))
        (raise "Name must be a symbol, but is ~x0." name))

       (?mksym-package-symbol name)
       (x (intern-in-package-of-symbol "X" name))

       ((unless (consp members))
        (raise "There must be at least one member."))

       ((unless (no-duplicatesp-equal members))
        (raise "The members must be a list of unique, but there are duplicate ~
                entries for ~x0."
               (reverse (dumb-collect-duplicates members nil))))

       ((unless (or (eq mode :logic)
                    (eq mode :program)))
        (raise ":mode must be one of :logic or :program, but is ~x0." mode))

       (body (cons 'or (defenum-members-to-tests members x)))
       (def `(defund ,name (,x)
               (declare (xargs :guard t))
               ,body))

       (long (str::cat (or long "")
                       "<p>This is an ordinary @(see defenum).</p>"
                       "@(def " (symbol-name name) ")"))

       (doc `(defxdoc ,name
               :parents ,parents
               :short ,short
               :long ,long))

       ((when (eq mode :program))
        `(encapsulate
           ()
           (program)
           ,doc
           ,def))

       (long (str::cat long "@(gthm type-when-" (symbol-name name) ")"))

       (doc `(defxdoc ,name
               :parents ,parents
               :short ,short
               :long ,long))

       (ts (defenum-deduce-type-set members))

       ((mv ts-concl &)
        ;; Magic function from :doc type-set
        (acl2::convert-type-set-to-term x ts (acl2::ens state) (w state) nil))

       (fc-rule `(defthm ,(intern-in-package-of-symbol
                           (concatenate 'string (symbol-name name) "-POSSIBILITIES")
                           name)
                   (implies (,name ,x)
                            (or . ,(defenum-members-to-tests-equal members x)))
                   :rule-classes :forward-chaining))

       (name-without-p (std::strip-p-from-symbol name))

       (fixname (intern-in-package-of-symbol
                 (concatenate 'string (symbol-name name-without-p) "-FIX")
                 name))
       (equivname (intern-in-package-of-symbol
                   (concatenate 'string (symbol-name name-without-p) "-EQUIV")
                   name))

       (fix `(defund-inline ,fixname (,x)
               (declare (xargs :guard (,name ,x)))
               (mbe :logic
                    (if (,name ,x)
                        ,x
                      ',(if defaultp default (car (last members))))
                    :exec
                    ,x)))

       (fix-type `(defthm ,(intern-in-package-of-symbol
                            (concatenate 'string "RETURN-TYPE-OF-" (symbol-name name) "-FIX")
                            name)
                    (,name (,fixname ,x))))

       (fix-id `(defthm ,(intern-in-package-of-symbol
                            (concatenate 'string (symbol-name name) "-FIX-IDEMPOTENT")
                            name)
                  (implies (,name ,x)
                           (equal (,fixname ,x) ,x)))))

    `(encapsulate
       ()
       (logic)
       ,doc
       ,def
       (local (in-theory (enable ,name)))

       (with-output
        :off observation
        (defthm ,(mksym 'type-when- name)
          (implies (,name ,x)
                   ,ts-concl)
          :rule-classes :compound-recognizer))

       ,fc-rule

       ,fix

       (local (in-theory (enable ,fixname)))

       ,fix-type

       ,fix-id

       (fty::deffixtype ,name
         :pred ,name
         :fix ,fixname
         :equiv ,equivname
         :define t)
       )))

(defmacro defenum (name members
                        &key
                        mode
                        (parents 'nil parents-p)
                        (short 'nil)
                        (long 'nil)
                        (default 'nil defaultp))
  `(make-event (let ((mode (or ',mode (default-defun-mode (w state))))
                     (parents (if ',parents-p
                                  ',parents
                                (or (xdoc::get-default-parents (w state))
                                    '(acl2::undocumented)))))
                 (defenum-fn ',name ',members mode parents ',short ',long ,defaultp ',default state))))


;; Primitive tests
(local
 (encapsulate
   ()
   (defenum day-p
     (:monday :tuesday :wednesday :thursday :friday :saturday :sunday))

   (defenum chartest-p
     (#\a #\b #\c))

   (defenum strsymtest-p
     ("foo" "bar" foo bar))

   (defenum universal-ts-test-p
     (0 1 -1 1/2 -1/2 #c(3 4) nil t foo (1 . 2) (1) "foo" #\a))))

