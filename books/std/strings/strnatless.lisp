; ACL2 String Library
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

(in-package "STR")
(include-book "decimal")
(include-book "tools/mv-nth" :dir :system)
(local (include-book "arithmetic"))

(defsection charlistnat<
  :parents (ordering)
  :short "Mixed alphanumeric character-list less-than test."

  :long "<p>@(call charlistnat<) determines if the character list @('x') is
\"smaller\" than the character list @('y'), using an ordering that is nice for
humans.</p>

<p>This is almost an ordinary case-sensitive lexicographic ordering.  But,
unlike a simple lexicographic order, we identify sequences of natural number
digits and group them together so that they can be sorted numerically.</p>

<p>Even though this function operates on character lists, let's just talk about
strings instead since they are easier to write down.  If you give most string
sorts a list of inputs like \"x0\" through \"x11\", they will end up in a
peculiar order:</p>

@({\"x0\", \"x1\", \"x10\", \"x11\", \"x2\", \"x3\", ... \"x9\"})

<p>But in @('charlistnat<'), we see the adjacent digits as bundles and sort
them as numbers.  This leads to a nicer ordering:</p>

@({\"x0\", \"x1\", \"x2\", ..., \"x9\", \"x10\", \"x11\"})

<p>This is almost entirely straightforward.  One twist is how to accommodate
leading zeroes.  Our approach is: instead of grouping adjacent digits and
treating them as a natural number, treat them as a pair with a value and a
length.  We then sort these pairs first by value, and then by length.  Hence, a
string such as \"x0\" is considered to be less than \"x00\", etc.</p>

<p>See also @(see strnat<) and @(see icharlist<).</p>"

  (local (in-theory (disable acl2::nth-when-bigger
                             acl2::negative-when-natp
                             default-+-2
                             default-+-1
                             default-<-2
                             commutativity-of-+
                             default-<-1
                             ACL2::|x < y  =>  0 < y-x|
                             char<-trichotomy-strong
                             char<-antisymmetric
                             char<-trichotomy-weak
                             char<-transitive
                             expt
                             default-car
                             default-cdr)))

  (defund charlistnat< (x y)
    (declare (xargs :guard (and (character-listp x)
                                (character-listp y))
                    :measure (len x)))

    (cond ((atom y)
           nil)
          ((atom x)
           t)
          ((and (digitp (car x))
                (digitp (car y)))
           (b* (((mv v1 l1 rest-x) (parse-nat-from-charlist x 0 0))
                ((mv v2 l2 rest-y) (parse-nat-from-charlist y 0 0)))

; The basic idea is to order numbers by their values, and then by their
; lengths.  This second part only is necessary to accomodate leading zeroes.

             (cond ((or (< v1 v2)
                        (and (int= v1 v2)
                             (< l1 l2)))
                    t)
                   ((or (< v2 v1)
                        (and (int= v1 v2)
                             (< l2 l1)))
                    nil)
                   (t
                    (charlistnat< rest-x rest-y)))))

          ((char< (car x) (car y))
           t)
          ((char< (car y) (car x))
           nil)
          (t
           (charlistnat< (cdr x) (cdr y)))))

  (local (in-theory (enable charlistnat<)))

  (defcong charlisteqv equal (charlistnat< x y) 1)
  (defcong charlisteqv equal (charlistnat< x y) 2)

  (defthm charlistnat<-irreflexive
    (not (charlistnat< x x)))

  (defthm charlistnat<-antisymmetric
    (implies (charlistnat< x y)
             (not (charlistnat< y x)))
    :hints(("goal" :in-theory (enable char<-antisymmetric))))

  (encapsulate
    ()
    (local (defthm char<-nonsense-2
             (implies (and (char< a y)
                           (not (digitp a))
                           (digitp y)
                           (digitp z))
                      (char< a z))
             :rule-classes ((:rewrite :backchain-limit-lst 0))
             :hints(("Goal" :in-theory (enable char< digitp)))))

    (local (defthm char<-nonsense-3
             (implies (and (char< y a)
                           (not (digitp a))
                           (digitp x)
                           (digitp y))
                      (char< x a))
             :rule-classes ((:rewrite :backchain-limit-lst 0))
             :hints(("Goal" :in-theory (enable char< digitp)))))

    (local (defthm char<-nonsense-4
             (implies (and (char< x y)
                           (not (digitp y))
                           (digitp x)
                           (digitp z))
                      (not (char< y z)))
             :rule-classes ((:rewrite :backchain-limit-lst 0))
             :hints(("Goal" :in-theory (enable digitp char<)))))



    (defthm charlistnat<-transitive
      (implies (and (charlistnat< x y)
                    (charlistnat< y z))
               (charlistnat< x z))
      :hints(("Goal" :in-theory (e/d ((:induction charlistnat<)
                                      char<-trichotomy-strong
                                      char<-transitive)
                                     (expt charlistnat<-antisymmetric
                                           take-leading-digits-when-digit-listp
                                           default-+-2 default-+-1
                                           BOUND-OF-LEN-OF-TAKE-LEADING-DIGITS
                                           LEN-OF-PARSE-NAT-FROM-CHARLIST))
              :induct t
              :expand ((:free (y) (charlistnat< x y))
                       (:free (z) (charlistnat< y z)))))))


  (encapsulate
    ()

    (local
     (encapsulate ()
       ;; A slightly tricky lemma about arithmetic.

       (local (defun expr (a x b n)
                (+ a (* x (expt b n)))))

       (local (include-book "arithmetic-3/floor-mod/floor-mod" :dir :system))

       (local (defthm mod-of-expr
                (implies (and (natp a1)
                              (natp x1)
                              (natp n)
                              (natp b)
                              (< a1 (expt b n))
                              (<= x1 b))
                         (equal (mod (expr a1 x1 b n)
                                     (expt b n))
                                a1))))

       (local (defthm main-lemma
                (implies (and (natp a1)
                              (natp a2)
                              (natp x1)
                              (natp x2)
                              (natp n)
                              (natp b)
                              (< a1 (expt b n))
                              (< a2 (expt b n))
                              (<= x1 b)
                              (<= x2 b)
                              (not (equal a1 a2)))
                         (not (equal (expr a1 x1 b n)
                                     (expr a2 x2 b n))))
                :hints(("Goal" :in-theory (disable expr mod-of-expr)
                        :use ((:instance mod-of-expr)
                              (:instance mod-of-expr (a1 a2) (x1 x2)))))))

       (defthmd arith-lemma-1
         (implies (and (natp a1)
                       (natp a2)
                       (natp x1)
                       (natp x2)
                       (natp n)
                       (natp b)
                       (< a1 (expt b n))
                       (< a2 (expt b n))
                       (<= x1 b)
                       (<= x2 b)
                       (not (equal a1 a2)))
                  (not (equal (+ a1 (* x1 (expt b n)))
                              (+ a2 (* x2 (expt b n))))))
         :hints(("Goal"
                 :in-theory (enable expr)
                 :use ((:instance main-lemma)))))))

; The main proof of trichotomy

    (local (defthm lemma-1
             (IMPLIES (AND (NOT (EQUAL (DIGIT-LIST-VALUE X2)
                                       (DIGIT-LIST-VALUE Y2)))
                           (NOT (EQUAL X2 Y2))
                           (CHARACTERP X1)
                           (CHARACTERP Y1)
                           (CHARACTER-LISTP X2)
                           (CHARACTER-LISTP Y2)
                           (DIGITP X1)
                           (DIGITP Y1)
                           (DIGIT-LISTP X2)
                           (DIGIT-LISTP Y2)
                           (EQUAL (LEN X2) (LEN Y2)))
                      (NOT (EQUAL (+ (DIGIT-LIST-VALUE X2)
                                     (* (DIGIT-VAL X1) (EXPT 10 (LEN X2))))
                                  (+ (DIGIT-LIST-VALUE Y2)
                                     (* (DIGIT-VAL Y1) (EXPT 10 (LEN X2)))))))
             :hints(("Goal"
                     :use ((:instance arith-lemma-1
                                      (a1 (digit-list-value x2))
                                      (a2 (digit-list-value y2))
                                      (x1 (digit-val x1))
                                      (x2 (digit-val y1))
                                      (b 10)
                                      (n (len x2))))))))

    (local (defun my-induction (x y)
             (if (and (consp x)
                      (consp y))
                 (my-induction (cdr x) (cdr y))
               nil)))

    (local (defthm lemma-2
             (implies (and (equal (len x) (len y))
                           (character-listp x)
                           (character-listp y)
                           (digit-listp x)
                           (digit-listp y))
                      (equal (equal (digit-list-value x)
                                    (digit-list-value y))
                             (equal x y)))
             :hints(("Goal"
                     :induct (my-induction x y)
                     :in-theory (enable digit-listp
                                        digit-list-value
                                        commutativity-of-+)))))

    (local (defthm lemma-3
             (implies (and (equal (len (take-leading-digits y))
                                  (len (take-leading-digits x)))
                           (equal (digit-list-value (take-leading-digits y))
                                  (digit-list-value (take-leading-digits x)))
                           (charlisteqv (skip-leading-digits x)
                                        (skip-leading-digits y)))
                      (equal (charlisteqv x y)
                             t))
             :hints(("Goal" :in-theory (enable take-leading-digits
                                               skip-leading-digits
                                               charlisteqv
                                               digit-list-value)))))

    (defthm charlistnat<-trichotomy-weak
      (implies (and (not (charlistnat< x y))
                    (not (charlistnat< y x)))
               (equal (charlisteqv x y)
                      t))
      :hints(("Goal" :in-theory (e/d (char<-trichotomy-strong)
                                     (BOUND-OF-LEN-OF-TAKE-LEADING-DIGITS
                                      TAKE-LEADING-DIGITS-WHEN-DIGIT-LISTP
                                      ACL2::RIGHT-CANCELLATION-FOR-+
                                      CHARLISTNAT<-ANTISYMMETRIC
                                      CHARLISTNAT<-IRREFLEXIVE
                                      )))))

    (defthm charlistnat<-trichotomy-strong
      (equal (charlistnat< x y)
             (and (not (charlisteqv x y))
                  (not (charlistnat< y x))))
      :rule-classes ((:rewrite :loop-stopper ((x y)))))))




(defsection strnat<-aux
  :parents (strnat<)
  :short "Implementation of @(see strnat<)."

  :long "<p>@(call strnat<-aux) is basically the adaptation of @(see
charlistnat<) for strings.  Here, X and Y are the strings being compared, and
XL and YL are their pre-computed lengths.  XN and YN are the indices into the
two strings that are our current positions.</p>

<p>BOZO why do we have XN and YN separately?  It seems like we should only need
one index.</p>"

  (local (in-theory (disable acl2::nth-when-bigger
                             acl2::negative-when-natp
                             default-+-2
                             default-+-1
                             default-<-2
                             commutativity-of-+
                             default-<-1
                             ACL2::|x < y  =>  0 < y-x|
                             ACL2::|x < y  =>  0 < -x+y|
                             char<-trichotomy-strong
                             char<-antisymmetric
                             char<-trichotomy-weak
                             char<-transitive
                             acl2::negative-when-natp
                             acl2::natp-rw
                             expt
                             default-car
                             default-cdr
                             ;(:rewrite PROGRESS-OF-PARSE-NAT-FROM-STRING)
                             )))


  (defund strnat<-aux (x y xn yn xl yl)
    (declare (type string x)
             (type string y)
             (type integer xn)
             (type integer yn)
             (type integer xl)
             (type integer yl)
             (xargs :guard (and (stringp x)
                                (stringp y)
                                (natp xn)
                                (natp yn)
                                (equal xl (length x))
                                (equal yl (length y))
                                (<= xn xl)
                                (<= yn yl))
                    :verify-guards nil
                    :measure
                    (let* ((x  (if (stringp x) x ""))
                           (y  (if (stringp y) y ""))
                           (xn (nfix xn))
                           (yn (nfix yn))
                           (xl (length x))
                           (yl (length y)))
                      (nfix (+ (- yl yn) (- xl xn))))
                    :hints(("Goal" :in-theory (disable ;val-of-parse-nat-from-string
                                                       ;len-of-parse-nat-from-string
                                                       ))))
             (ignorable xl yl))
    (mbe :logic
         (let* ((x  (if (stringp x) x ""))
                (y  (if (stringp y) y ""))
                (xn (nfix xn))
                (yn (nfix yn))
                (xl (length x))
                (yl (length y)))
           (cond ((zp (- yl yn))
                  nil)
                 ((zp (- xl xn))
                  t)
                 ((and (digitp (char x xn))
                       (digitp (char y yn)))
                  (b* (((mv v1 l1)
                        (parse-nat-from-string x 0 0 xn xl))
                       ((mv v2 l2)
                        (parse-nat-from-string y 0 0 yn yl)))
                    (cond ((or (< v1 v2)
                               (and (int= v1 v2)
                                    (< l1 l2)))
                           t)
                          ((or (< v2 v1)
                               (and (int= v1 v2)
                                    (< l2 l1)))
                           nil)
                          (t
                           (strnat<-aux x y (+ xn l1) (+ yn l2) xl yl)))))
                 ((char< (char x xn)
                         (char y yn))
                  t)
                 ((char< (char y yn)
                         (char x xn))
                  nil)
                 (t
                  (strnat<-aux x y (+ 1 xn) (+ 1 yn) xl yl))))
         :exec
         (cond ((int= yn yl)
                nil)
               ((int= xn xl)
                t)
               (t
                (let* ((char-x (the character (char (the string x) (the integer xn))))
                       (char-y (the character (char (the string y) (the integer yn))))
                       (code-x (the (unsigned-byte 8) (char-code (the character char-x))))
                       (code-y (the (unsigned-byte 8) (char-code (the character char-y)))))
                  (declare (type character char-x)
                           (type character char-y)
                           (type (unsigned-byte 8) code-x)
                           (type (unsigned-byte 8) code-y))
                  (cond
                   ((and
                     ;; (digitp (char x xn))
                     (<= (the (unsigned-byte 8) 48) (the (unsigned-byte 8) code-x))
                     (<= (the (unsigned-byte 8) code-x) (the (unsigned-byte 8) 57))
                     ;; (digitp (char y yn))
                     (<= (the (unsigned-byte 8) 48) (the (unsigned-byte 8) code-y))
                     (<= (the (unsigned-byte 8) code-y) (the (unsigned-byte 8) 57)))
                    (b* (((mv v1 l1)
                          (parse-nat-from-string (the string x)
                                                 (the integer 0)
                                                 (the integer 0)
                                                 (the integer xn)
                                                 (the integer xl)))
                         ((mv v2 l2)
                          (parse-nat-from-string (the string y)
                                                 (the integer 0)
                                                 (the integer 0)
                                                 (the integer yn)
                                                 (the integer yl))))
                      (cond ((or (< (the integer v1) (the integer v2))
                                 (and (int= v1 v2)
                                      (< (the integer l1) (the integer l2))))
                             t)
                            ((or (< (the integer v2) (the integer v1))
                                 (and (int= v1 v2)
                                      (< (the integer l2) (the integer l1))))
                             nil)
                            (t
                             (strnat<-aux (the string x)
                                          (the string y)
                                          (the integer (+ (the integer xn) (the integer l1)))
                                          (the integer (+ (the integer yn) (the integer l2)))
                                          (the integer xl)
                                          (the integer yl))))))
                   ((< (the (unsigned-byte 8) code-x) (the (unsigned-byte 8) code-y))
                    t)
                   ((< (the (unsigned-byte 8) code-y) (the (unsigned-byte 8) code-x))
                    nil)
                   (t
                    (strnat<-aux (the string x)
                                 (the string y)
                                 (the integer (+ (the integer 1) (the integer xn)))
                                 (the integer (+ (the integer 1) (the integer yn)))
                                 (the integer xl)
                                 (the integer yl)))))))))

  (local (in-theory (enable strnat<-aux)))
  (set-inhibit-warnings "theory") ;; implicitly local

  (encapsulate
    nil
    (local (in-theory (disable acl2::nth-when-bigger
                               take-leading-digits-when-digit-listp
                               digit-listp-when-not-consp
                               (:type-prescription character-listp)
                               (:type-prescription eqlable-listp)
                               (:type-prescription atom-listp)
                               (:type-prescription digitp$inline)
                               (:type-prescription strnat<-aux)
                               (:type-prescription char<)
                               default-char-code
                               char<-antisymmetric
                               char<-trichotomy-strong
                               default-<-1 default-<-2
                               default-+-1 default-+-2
                               acl2::open-small-nthcdr
                               acl2::nthcdr-when-zp
                               acl2::nthcdr-when-atom
                               ACL2::|x < y  =>  0 < -x+y|
                               nthcdr len nth not
                               strnat<-aux
                               acl2::natp-fc-1
                               acl2::natp-fc-2
                               (:FORWARD-CHAINING EQLABLE-LISTP-FORWARD-TO-ATOM-LISTP)
                               (:FORWARD-CHAINING CHARACTER-LISTP-FORWARD-TO-EQLABLE-LISTP)
                               (:FORWARD-CHAINING ATOM-LISTP-FORWARD-TO-TRUE-LISTP)
                               )))
    (verify-guards strnat<-aux
      :hints((and stable-under-simplificationp
                  '(:in-theory (enable digitp
                                       digit-val
                                       char-fix
                                       char<))))))

  (local (defthm skip-leading-digits-to-nthcdr
           (implies (force (true-listp x))
                    (equal (skip-leading-digits x)
                           (nthcdr (len (take-leading-digits x)) x)))
           :hints(("Goal" :in-theory (enable skip-leading-digits take-leading-digits)))))

  (defthm strnat<-aux-correct
    (implies (and (stringp x)
                  (stringp y)
                  (natp xn)
                  (natp yn)
                  (equal xl (length x))
                  (equal yl (length y))
                  (<= xn xl)
                  (<= yn yl))
             (equal (strnat<-aux x y xn yn xl yl)
                    (charlistnat< (nthcdr xn (explode x))
                                  (nthcdr yn (explode y)))))
    :hints(("Goal"
            :induct (strnat<-aux x y xn yn xl yl)
            :expand ((charlistnat< (nthcdr xn (explode x))
                                   (nthcdr yn (explode y)))
                     (:free (xl yl) (strnat<-aux x y xn yn xl yl)))
            :in-theory (e/d (charlistnat<
                             commutativity-of-+
                             )
                            (charlistnat<-antisymmetric
                             charlistnat<-trichotomy-strong
                             take-leading-digits-when-digit-listp
                             digit-listp-when-not-consp
                             charlistnat<
                             (:definition strnat<-aux)
                             default-+-1 default-+-2
                             acl2::nth-when-bigger))
            :do-not '(generalize fertilize)))))



(define strnat< ((x :type string)
                 (y :type string))
  :parents (ordering)
  :short "Mixed alphanumeric string less-than test."

  :long "<p>@(call strnat<) determines if the string @('x') is \"smaller\"
than the string @('y'), using an ordering that is nice for humans.</p>

<p>See @(see charlistnat<) for a description of this order.</p>

<p>We avoid coercing the strings into character lists, and this is altogether
pretty fast.</p>"

  :inline t
  (mbe :logic
       (charlistnat< (explode x) (explode y))
       :exec
       (strnat<-aux (the string x)
                    (the string y)
                    (the integer 0)
                    (the integer 0)
                    (the integer (length (the string x)))
                    (the integer (length (the string y)))))
  ///
  (defcong streqv equal (strnat< x y) 1)
  (defcong streqv equal (strnat< x y) 2)

  (defthm strnat<-irreflexive
    (not (strnat< x x)))

  (defthm strnat<-antisymmetric
    (implies (strnat< x y)
             (not (strnat< y x))))

  (defthm strnat<-transitive
    (implies (and (strnat< x y)
                  (strnat< y z))
             (strnat< x z)))

  (defthm strnat<-transitive-alt
    (implies (and (strnat< y z)
                  (strnat< x y))
             (strnat< x z))))

