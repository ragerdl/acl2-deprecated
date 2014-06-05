; VL Verilog Toolkit
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

(in-package "VL")
(include-book "tokens")
(local (include-book "../../util/arithmetic"))
(local (in-theory (enable str-fix)))

(defun revappend-of-take (n x y)
  ;; BOZO move to utilities
  (declare (xargs :guard (and (natp n)
                              (<= n (len x)))))
  (mbe :logic (revappend (take n x) y)
       :exec (if (eql n 0)
                 y
               (revappend-of-take (- n 1) (cdr x) (cons (car x) y)))))


(defsection lexer-utils
  :parents (lexer)
  :short "Utilities for writing lexer functions and proving theorems about
  them.")

(local (xdoc::set-default-parents lexer-utils))

(defsection def-prefix/remainder-thms
  :short "Introduce prefix/remainder theorems for a lexing function."

  :long "<p>Many of our lexing routines take @('echars'), an @(see
vl-echarlist-p), as input, and split this list into a @('prefix') and
@('remainder').  This macro allows us to quickly prove several common
properties about such a function.  In particular, we show:</p>

<ul>

<li>@('prefix') is always a true-listp, and furthermore it is also a
vl-echarlist-p as long as the @('echars') is.</li>

<li>@('remainder') is a true-listp exactly when @('echars') is, and furthermore
it is a vl-echarlist-p whenever @('echars') is.</li>

<li>Appending the @('prefix') and @('remainder') always returns the original
@('echars').  A corollary is that whenever @('prefix') is empty, @('remainder')
is the whole of @('echars').</li>

<li>The acl2-count of @('remainder') is never greater than that of @('echars'),
and strictly decreases whenever @('prefix') is non-nil.</li>

</ul>"

  (defmacro def-prefix/remainder-thms (fn &key
                                          (formals '(echars))
                                          (prefix-n '0)
                                          (remainder-n '1))
    (let ((mksym-package-symbol 'vl::foo))
      `(defsection ,(mksym fn '-prefix/remainder-thms)
         :parents (,fn)
         :short "Prefix and remainder theorems, automatically generated
                 by @(see def-prefix/remainder-thms)."

         (local (in-theory (enable ,fn)))

         (defrule ,(mksym 'prefix-of- fn)
           (and (true-listp (mv-nth ,prefix-n (,fn . ,formals)))
                (implies (force (vl-echarlist-p echars))
                         (vl-echarlist-p (mv-nth ,prefix-n (,fn . ,formals)))))
           :rule-classes ((:rewrite)
                          (:type-prescription :corollary
                                              (true-listp (mv-nth ,prefix-n (,fn . ,formals))))))

         (defrule ,(mksym 'remainder-of- fn)
           (and (equal (true-listp (mv-nth ,remainder-n (,fn . ,formals)))
                       (true-listp echars))
                (implies (force (vl-echarlist-p echars))
                         (vl-echarlist-p (mv-nth ,remainder-n (,fn . ,formals)))))
           :rule-classes ((:rewrite)
                          (:type-prescription
                           :corollary
                           (implies (true-listp echars)
                                    (true-listp (mv-nth ,remainder-n (,fn . ,formals))))))
           :disable (force))

         (defrule ,(mksym 'append-of- fn)
           (equal (append (mv-nth ,prefix-n (,fn . ,formals))
                          (mv-nth ,remainder-n (,fn . ,formals)))
                  echars))

         (defrule ,(mksym 'no-change-loser-of- fn)
           (implies (not (mv-nth ,prefix-n (,fn . ,formals)))
                    (equal (mv-nth ,remainder-n (,fn . ,formals))
                           echars)))

         (defrule ,(mksym 'acl2-count-of- fn '-weak)
           (<= (acl2-count (mv-nth ,remainder-n (,fn . ,formals)))
               (acl2-count echars))
           :rule-classes ((:rewrite) (:linear))
           :disable (force))

         (defrule ,(mksym 'acl2-count-of- fn '-strong)
           (implies (mv-nth ,prefix-n (,fn . ,formals))
                    (< (acl2-count (mv-nth ,remainder-n (,fn . ,formals)))
                       (acl2-count echars)))
           :rule-classes ((:rewrite) (:linear))
           :disable (force))))))


(define vl-matches-string-p-impl
  :parents (vl-matches-string-p)
  ((string :type string)
   (i      :type unsigned-byte)
   (len    (equal len (length string)))
   (echars vl-echarlist-p))
  :measure (if (< (nfix i) (nfix len))
               (nfix (- (nfix len) (nfix i)))
             0)
  (mbe :logic
       (or (>= (nfix i) (nfix len))
           (and (consp echars)
                (eql (char string i) (vl-echar->char (car echars)))
                (vl-matches-string-p-impl string (+ (nfix i) 1) len (cdr echars))))
       :exec
       (or (>= i len)
           (and (consp echars)
                (eql (char string i)
                     (the character (vl-echar->char (car echars))))
                (vl-matches-string-p-impl string (+ i 1) len (cdr echars))))))

(define vl-matches-string-p
  :short "See if a string occurs at the front of an @(see vl-echarlist-p)."

  ((string :type string "String we're looking for.")
   (echars vl-echarlist-p "Characters we're lexing."))
  :returns bool

  :long "<p>This function determines if some @('string') occurs at the front of
@('echars').  More exactly, it computes:</p>

@({
 (prefixp (explode string)
          (vl-echarlist->chars echars))
})

<p>But we actually implement the operation with a fast function that does not
call @(see explode) or build the list of characters.</p>"

  :guard (not (equal string ""))
  :verify-guards nil
  :inline t

  (mbe :logic (prefixp (explode string) (vl-echarlist->chars echars))
       :exec (vl-matches-string-p-impl string 0 (length string) echars))
  ///

  (local (defrule lemma
           (implies (and (stringp string)
                         (natp i)
                         (natp len)
                         (equal len (length string))
                         (vl-echarlist-p echars))
                    (equal (vl-matches-string-p-impl string i len echars)
                           (prefixp (nthcdr i (explode string))
                                    (vl-echarlist->chars echars))))
           :enable vl-matches-string-p-impl))

  (verify-guards vl-matches-string-p$inline)

  (defrule len-when-vl-matches-string-p-fc
    (implies (vl-matches-string-p string echars)
             (<= (len (explode string))
                 (len echars)))
    :rule-classes ((:forward-chaining)
                   (:linear)))

  (defrule consp-when-vl-matches-string-p-fc
    (implies (and (vl-matches-string-p string echars)
                  (stringp string)
                  (not (equal string "")))
             (consp echars))
    :rule-classes :forward-chaining)

  (defrule vl-matches-string-p-when-acl2-count-zero
    (implies (and (equal 0 (acl2-count echars))
                  (force (stringp string)))
             (equal (vl-matches-string-p string echars)
                    (equal string "")))
    :enable acl2-count))

(define vl-read-literal
  :short "Match an exact literal string."
  ((string "The string we're looking for." :type string)
   (echars "The characters we're lexing." vl-echarlist-p))
  :guard (not (equal string ""))
  :returns (mv (prefix "@('nil') on failure, or the matching prefix of
                        @('echars') on success.")
               (remainder))
  :inline t
  (if (vl-matches-string-p string echars)
      (let ((strlen (length (string-fix string))))
        (mv (first-n strlen echars)
            (rest-n strlen echars)))
    (mv nil echars))
  ///
  (local (in-theory (enable vl-matches-string-p)))

  (defrule vl-echarlist->chars-of-prefix-of-vl-read-literal
    (b* (((mv prefix ?remainder) (vl-read-literal string echars)))
      (implies prefix
               (equal (vl-echarlist->chars prefix)
                      (explode string)))))

  (defrule vl-echarlist->string-of-prefix-of-vl-read-literal
    (b* (((mv prefix ?remainder) (vl-read-literal string echars)))
      (implies prefix
               (equal (vl-echarlist->string prefix)
                      (string-fix string))))))

(def-prefix/remainder-thms vl-read-literal :formals (string echars))


(define vl-read-some-literal
  :short "Match one of many exact literal strings."

  ((strings "The strings to search for, in priority order." string-listp)
   (echars  "The characters we're lexing." vl-echarlist-p))
  :guard (not (member-equal "" strings))
  :returns (mv (prefix "@('nil') on failure, or the matching prefix of
                        @('echars') on success.")
               remainder)

  (b* (((when (atom strings))
        (mv nil echars))
       ((mv prefix remainder)
        (vl-read-literal (car strings) echars))
       ((when prefix)
        (mv prefix remainder)))
    (vl-read-some-literal (cdr strings) echars)))

(def-prefix/remainder-thms vl-read-some-literal
  :formals (strings echars))


(define vl-read-until-literal-impl ((string :type string)
                                    (echars vl-echarlist-p)
                                    acc)
  :parents (vl-read-until-literal)
  :guard (not (equal string ""))
  (cond ((atom echars)
         (mv nil acc echars))
        ((vl-matches-string-p string echars)
         (mv t acc echars))
        (t
         (vl-read-until-literal-impl string (cdr echars) (cons (car echars) acc)))))

(define vl-read-until-literal
  :short "Match any characters up until some literal."
  ((string "The ending string that we're looking for." stringp)
   (echars "The characters that we're lexing." vl-echarlist-p))
  :guard (not (equal string ""))
  :returns (mv (successp "Whether we ever found @('string').")
               (prefix "All characters from @('echars') leading up to <i>but
                        not including</i> the first occurrence of @('string').
                        When @('string') never occurs in @('echars'),
                        @('prefix') is just the entire list of @('echars') and
                        @('remainder') is its final cdr.")
               (remainder))
  :verify-guards nil
  :inline t
  (mbe :logic (b* (((when (atom echars))
                    (mv nil nil echars))
                   ((when (vl-matches-string-p string echars))
                    (mv t nil echars))
                   ((mv successp prefix remainder)
                    (vl-read-until-literal string (cdr echars))))
                (mv successp
                    (cons (car echars) prefix)
                    remainder))
       :exec (b* (((mv successp acc remainder)
                   (vl-read-until-literal-impl string echars nil)))
               (mv successp (reverse acc) remainder)))
  ///
  (local (in-theory (enable vl-read-until-literal-impl)))

  (defmvtypes vl-read-until-literal$inline
    (booleanp true-listp nil))

  (defrule vl-read-until-literal-impl-equiv
    (b* (((mv successp prefix remainder)
          (vl-read-until-literal string echars)))
      (equal (vl-read-until-literal-impl string echars acc)
             (list successp
                   (revappend prefix acc)
                   remainder))))

  (verify-guards vl-read-until-literal$inline)

  (defrule len-of-vl-read-until-literal
    (b* (((mv successp ?prefix remainder)
          (vl-read-until-literal string echars)))
      (implies successp
               (<= (len (explode string))
                   (len remainder))))
    :rule-classes ((:rewrite) (:linear)))

  (defrule vl-matches-string-p-after-vl-read-until-literal
    (b* (((mv successp ?prefix remainder)
          (vl-read-until-literal string echars)))
      (implies successp
               (vl-matches-string-p string remainder)))))

(def-prefix/remainder-thms vl-read-until-literal
  :formals (string echars)
  :prefix-n 1
  :remainder-n 2)


(define vl-read-through-literal
  :short "Match any characters until and through some literal."

  ((string :type string)
   (echars (vl-echarlist-p echars)))
  :guard (not (equal string ""))
  :guard-debug t
  :returns (mv (successp "Whether we ever found @('string').")
               (prefix "On success, all characters from @('echars') leading up
                        to <i>and including</i> the first occurrence of
                        @('string').  When @('string') never occurs in
                        @('echars'), then @('prefix') is the entire list of
                        @('echars') and @('remainder') is its final cdr.")
               (remainder))

  (mbe :logic (b* ((string (string-fix string))
                   ((mv successp prefix remainder)
                    (vl-read-until-literal string echars))
                   ((unless successp)
                    (mv nil prefix remainder)))
                (mv t
                    (append prefix (take (length string) remainder))
                    (nthcdr (length string) remainder)))
         :exec (b* (((mv successp prefix remainder)
                     (vl-read-until-literal-impl string echars nil))
                    ((unless successp)
                     (mv nil (reverse prefix) remainder))
                    (strlen (length string)))
                 (mv t
                     (reverse (revappend-of-take strlen remainder prefix))
                     (rest-n strlen remainder))))

  ///
  (defrule prefix-of-vl-read-through-literal-under-iff
    (b* (((mv ?successp prefix ?remainder) (vl-read-through-literal string echars)))
      (implies (and (stringp string)
                    (not (equal string "")))
               (iff prefix
                    (consp echars))))
    :enable vl-read-until-literal))

(def-prefix/remainder-thms vl-read-through-literal
  :formals (string echars)
  :prefix-n 1
  :remainder-n 2)


(define vl-echarlist-kill-underscores
  :short "Remove all occurrences of the underscore character from a @(see
vl-echarlist-p)."
  ((x vl-echarlist-p))
  :returns (reduced-x vl-echarlist-p :hyp :fguard)
  :long "<p>Verilog uses underscores as a digit separator, e.g., you can write
@('1_000_000') instead of @('1000000') for greater readability on long numbers.
This function strips away the underscores so we can interpret the remaining
digits with @(see vl-echarlist-unsigned-value).</p>"

  (cond ((atom x)
         nil)
        ((eql (vl-echar->char (car x)) #\_)
         (vl-echarlist-kill-underscores (cdr x)))
        (t
         (cons (car x) (vl-echarlist-kill-underscores (cdr x))))))


(defmacro def-token/remainder-thms (fn &key
                                       (formals '(echars))
                                       (extra-tokenhyp 't)
                                       (extra-appendhyp 't)
                                       (extra-strongcounthyp 't)
                                       (token-n '0)
                                       (remainder-n '1))
  (let ((mksym-package-symbol (pkg-witness "VL")))
    `(defsection ,(mksym fn '-token/remainder-thms)
       :parents (,fn)
       :short "Basic token/remainder theorems automatically added with
               @(see vl::def-token/remainder-thms)."

       (local (in-theory (enable ,fn)))

       (defthm ,(mksym 'vl-token-p-of- fn)
         (implies (and (force (vl-echarlist-p echars))
                       ,extra-tokenhyp)
                  (equal (vl-token-p (mv-nth ,token-n (,fn . ,formals)))
                         (if (mv-nth ,token-n (,fn . ,formals))
                             t
                           nil))))

       (defthm ,(mksym 'true-listp-of- fn)
         (equal (true-listp (mv-nth ,remainder-n (,fn . ,formals)))
                (true-listp echars))
         :rule-classes ((:rewrite)
                        (:type-prescription
                         :corollary
                         (implies (true-listp echars)
                                  (true-listp (mv-nth ,remainder-n (,fn . ,formals))))))
         :hints(("Goal" :in-theory (disable (force)))))

       (defthm ,(mksym 'vl-echarlist-p-of- fn)
         (implies (force (vl-echarlist-p echars))
                  (equal (vl-echarlist-p (mv-nth ,remainder-n (,fn . ,formals)))
                         t)))

       (defthm ,(mksym 'append-of- fn)
         (implies (and (mv-nth ,token-n (,fn . ,formals))
                       (force (vl-echarlist-p echars))
                       ,extra-appendhyp)
                  (equal (append (vl-token->etext (mv-nth ,token-n (,fn . ,formals)))
                                 (mv-nth ,remainder-n (,fn . ,formals)))
                         echars)))

       (defthm ,(mksym 'no-change-loser-of- fn)
         (implies (not (mv-nth ,token-n (,fn . ,formals)))
                  (equal (mv-nth ,remainder-n (,fn . ,formals))
                         echars)))

       (defthm ,(mksym 'acl2-count-of- fn '-weak)
         (<= (acl2-count (mv-nth ,remainder-n (,fn . ,formals)))
             (acl2-count echars))
         :rule-classes ((:rewrite) (:linear))
         :hints(("Goal" :in-theory (disable (force)))))

       (defthm ,(mksym 'acl2-count-of- fn '-strong)
         (implies (and (mv-nth ,token-n (,fn . ,formals))
                       ,extra-strongcounthyp)
                  (< (acl2-count (mv-nth ,remainder-n (,fn . ,formals)))
                     (acl2-count echars)))
         :rule-classes ((:rewrite) (:linear))
         :hints(("Goal" :in-theory (disable (force))))))))
