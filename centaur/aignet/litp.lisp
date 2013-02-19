; AIGNET - And-Inverter Graph Networks
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
; Original authors: Sol Swords <sswords@centtech.com>
;                   Jared Davis <jared@centtech.com>

(in-package "AIGNET")
(include-book "idp")
(local (include-book "centaur/bitops/ihsext-basics" :dir :system))
(set-tau-auto-mode nil)


(define litp (x)
  :parents (aignet)
  :short "Representation of a literal (a Boolean variable or its negation)."

  :long "<p>Think of a <b>LITERAL</b> as an abstract data type that can either
represent a Boolean variable or its negation.  More concretely, you can think
of a literal as an structure with two fields:</p>

<ul>
<li>@('id'), a variable, represented as an @(see idp), and</li>
<li>@('neg'), a bit that says whether the variable is negated or not,
represented as a @(see bitp).</li>
</ul>

<p>In the implementation, we use an efficient natural-number encoding rather
than some kind of cons structure: @('neg') is the bottom bit of the literal,
and @('id') is the remaining bits.  (This trick exploits the representation of
identifiers as natural numbers.)</p>"

  (natp x)

  ;; Not :type-prescription, ACL2 infers that automatically
  :returns (bool booleanp :rule-classes :tau-system)

  ///

  (defthm litp-type
    ;; BOZO similar questions as for idp-type
    (implies (litp x)
             (natp x))
    :rule-classes (:tau-system :compound-recognizer)))


(local (in-theory (enable litp)))


(define to-lit ((nat natp))
  :parents (litp)
  :short "Raw constructor for literals."
  :long "<p>This exposes the underlying representation of literals.  You
should generally use @(see mk-lit) instead.</p>"

  (lnfix nat)

  :inline t
  :returns (lit litp :rule-classes (:rewrite :tau-system)))


(define lit-val ((lit litp))
  :parents (litp)
  :short "Raw value of a literal."
  :long "<p>This exposes the underlying representation of literals.  You should
generally use @(see lit-id) and @(see lit-neg) instead.</p>"

  (lnfix lit)

  :inline t
  ;; Not :type-prescription, ACL2 infers that automatically
  :returns (nat natp :rule-classes (:rewrite :tau-system)))

(local (in-theory (enable to-lit lit-val)))


(define lit-equiv ((x litp) (y litp))
  :parents (litp)
  :short "Basic equivalence relation for literals."
  :enabled t

  (int= (lit-val x) (lit-val y))

  ///

  (defequiv lit-equiv)
  (defcong lit-equiv equal (lit-val x) 1)
  (defcong nat-equiv equal (to-lit x) 1))


(define lit-fix ((x litp))
  :parents (litp)
  :short "Basic fixing function for literals."

  (to-lit (lit-val x))

  :inline t
  :returns (x-fix litp)

  ///

  (defcong lit-equiv equal (lit-fix x) 1)

  (defthm lit-fix-of-lit
    (implies (litp x)
             (equal (lit-fix x) x)))

  (defthm lit-equiv-of-lit-fix
    (lit-equiv (lit-fix lit) lit)))

(local (in-theory (enable lit-fix)))


(defsection lit-raw-theorems
  :parents (litp)
  :short "Basic theorems about raw literal functions like @(see to-lit) and
@(see lit-val)."

  (defthm lit-val-of-to-lit
    (equal (lit-val (to-lit x))
           (nfix x)))

  (defthm lit-equiv-of-to-lit-of-lit-val
    (lit-equiv (to-lit (lit-val lit)) lit))

  (defthm equal-of-to-lit-hyp
    (implies (syntaxp (acl2::rewriting-negative-literal-fn
                       `(equal (to-lit$inline ,x) ,y)
                       mfc state))
             (equal (equal (to-lit x) y)
                    (and (litp y)
                         (equal (nfix x) (lit-val y))))))

  (defthm equal-of-lit-fix-hyp
    (implies (syntaxp (acl2::rewriting-negative-literal-fn
                       `(equal (lit-fix$inline ,x) ,y)
                       mfc state))
             (equal (equal (lit-fix x) y)
                    (and (litp y)
                         (equal (lit-val x) (lit-val y))))))

  (defthm equal-of-to-lit-backchain
    (implies (and (litp y)
                  (equal (nfix x) (lit-val y)))
             (equal (equal (to-lit x) y) t))
    :hints (("goal" :use equal-of-to-lit-hyp)))

  (defthm equal-of-lit-fix-backchain
    (implies (and (litp y)
                  (equal (lit-val x) (lit-val y)))
             (equal (equal (lit-fix x) y) t))
    :hints (("goal" :use equal-of-to-lit-hyp)))

  (in-theory (disable litp to-lit lit-val))

  (defthm equal-lit-val-forward-to-lit-equiv
    (implies (and (equal (lit-val x) y)
                  (syntaxp (not (and (consp y)
                                     (or (eq (car y) 'lit-val)
                                         (eq (car y) 'nfix))))))
             (lit-equiv x (to-lit y)))
    :rule-classes :forward-chaining)

  (defthm equal-lit-val-nfix-forward-to-lit-equiv
    (implies (equal (lit-val x) (nfix y))
             (lit-equiv x (to-lit y)))
    :rule-classes :forward-chaining)

  (defthm equal-lit-val-forward-to-lit-equiv-both
    (implies (equal (lit-val x) (lit-val y))
             (lit-equiv x y))
    :rule-classes :forward-chaining)

  (defthm to-lit-of-lit-val
    (equal (to-lit (lit-val x))
           (lit-fix x))))



(local (in-theory (disable litp
                           to-lit
                           lit-val
                           lit-fix)))


(local (in-theory (enable* acl2::ihsext-recursive-redefs
                           acl2::ihsext-bounds-thms
                           nfix natp)))


(define lit-id ((lit litp))
  :parents (litp)
  :short "Access the @('id') component of a literal."

  (declare (type (integer 0 *) lit))
  (to-id (ash (lit-val lit) -1))

  :inline t
  ;; BOZO type-prescription doesn't make sense unless we strenghten
  ;; the compound-recognizer rule for idp?
  :returns (id idp :rule-classes (:rewrite :type-prescription))

  ///
  (defcong lit-equiv equal (lit-id lit) 1))


(define lit-neg ((lit litp))
  :parents (litp)
  :short "Access the @('neg') bit of a literal."

  (declare (type (integer 0 *) lit))
  (logand 1 (lit-val lit))

  :inline t
  :returns (neg bitp)

  ///

  (defthm natp-of-lit-neg
    ;; You might think this is unnecessary because ACL2 should infer it.  That's
    ;; true here, but when we include this file in other books that don't know
    ;; about LOGAND we lose it.  So, we make it explicit.
    (natp (lit-neg lit))
    :rule-classes (:type-prescription :tau-system))

  (in-theory (disable (:t lit-neg)))

  (defthm lit-neg-bound
    (<= (lit-neg lit) 1)
    :rule-classes :linear)

  (defcong lit-equiv equal (lit-neg lit) 1))


(acl2::def-b*-decomp lit
                     (id . lit-id)
                     (neg . lit-neg))


(define mk-lit ((id idp) (neg bitp))
  :parents (litp)
  :short "Construct a literal with the given @('id') and @('neg')."

  (declare (type (integer 0 *) id)
           (type bit neg))

  (to-lit (logior (ash (id-val id) 1)
                  (acl2::lbfix neg)))

  :inline t
  ;; BOZO type-prescription doesn't make sense unless we strenghten
  ;; the compound-recognizer rule for litp?
  :returns (lit litp :rule-classes (:rewrite :type-prescription))
  :prepwork ((local (in-theory (enable lit-id lit-neg))))
  ///
  (defcong id-equiv equal (mk-lit id neg) 1)
  (defcong acl2::bit-equiv equal (mk-lit id neg) 2)

  (defthm lit-id-of-mk-lit
    (equal (lit-id (mk-lit id neg))
           (id-fix id)))

  (defthm lit-neg-of-mk-lit
    (equal (lit-neg (mk-lit id neg))
           (acl2::bfix neg)))

  (defthm mk-lit-identity
    (equal (mk-lit (lit-id lit)
                   (lit-neg lit))
           (lit-fix lit))
    :hints(("Goal" :in-theory (disable acl2::logior$))))

  (local (defthm equal-of-mk-lit-lemma
           (implies (and (idp id) (acl2::bitp neg))
                    (equal (equal a (mk-lit id neg))
                           (and (litp a)
                                (equal (id-val (lit-id a)) (id-val id))
                                (equal (lit-neg a) neg))))
           :hints(("Goal" :in-theory (disable mk-lit
                                              mk-lit-identity
                                              lit-id lit-neg)
                   :use ((:instance mk-lit-identity (lit a)))))
           :rule-classes nil))

  (defthmd equal-of-mk-lit
    (equal (equal a (mk-lit id neg))
           (and (litp a)
                (equal (id-val (lit-id a)) (id-val id))
                (equal (lit-neg a) (acl2::bfix neg))))
    :hints(("Goal" :use ((:instance equal-of-mk-lit-lemma
                          (id (id-fix id)) (neg (acl2::bfix neg))))
            :in-theory (disable lit-id lit-neg)))))


(local (in-theory (e/d (acl2::logxor**)
                       (acl2::logior$ acl2::logxor$))))


(define lit-negate ((lit litp))
  :parents (litp)
  :short "Efficiently negate a literal."
  :enabled t
  :inline t
  (declare (type (integer 0 *) lit))
  (mbe :logic (b* ((id (lit-id lit))
                   (neg (lit-neg lit)))
                (mk-lit id (acl2::b-not neg)))
       :exec (to-lit (logxor (lit-val lit) 1)))

  :guard-hints(("Goal" :in-theory (enable mk-lit lit-id lit-neg))))



(define lit-negate-cond ((lit litp) (c bitp))
  :parents (litp)
  :short "Efficiently negate a literal."
  :long "<p>When @('c') is 1, we negate @('lit').  Otherwise, when @('c') is 0,
we return @('lit') unchanged.</p>"
  :enabled t
  :inline t
  (declare (type (integer 0 *) lit)
           (type bit c))

  (mbe :logic (b* ((id (lit-id lit))
                   (neg (acl2::b-xor (lit-neg lit) c)))
                (mk-lit id neg))
       :exec (to-lit (logxor (lit-val lit) c)))

  :guard-hints(("Goal" :in-theory (enable mk-lit lit-id lit-neg)))

  ///

  (defthmd lit-negate-cond-correct
    (implies (and (litp lit)
                  (bitp c))
             (equal (lit-negate-cond lit c)
                    (if (= c 1)
                        (lit-negate lit)
                      lit)))
    :hints(("Goal" :in-theory (enable b-xor equal-of-mk-lit)))))


(define lit-listp (x)
  :parents (litp)
  :short "Recognize a list of literals."

  (if (atom x)
      (eq x nil)
    (and (litp (car x))
         (lit-listp (cdr x))))

  ///
  (defthm lit-listp-when-atom
    (implies (atom x)
             (equal (lit-listp x)
                    (not x))))

  (defthm lit-listp-of-cons
    (equal (lit-listp (cons a x))
           (and (litp a)
                (lit-listp x))))

  (defthm true-listp-when-lit-listp
    (implies (lit-listp x)
             (true-listp x))
    :rule-classes :compound-recognizer))


(define lit-list-listp (x)
  :parents (litp)
  :short "Recognize a list of @(see lit-listp)s."

  (if (atom x)
      (eq x nil)
    (and (lit-listp (car x))
         (lit-list-listp (cdr x))))

  ///
  (defthm lit-list-listp-when-atom
    (implies (atom x)
             (equal (lit-list-listp x)
                    (not x))))

  (defthm lit-list-listp-of-cons
    (equal (lit-list-listp (cons a x))
           (and (lit-listp a)
                (lit-list-listp x))))

  (defthm true-listp-when-lit-list-listp
    (implies (lit-list-listp x)
             (true-listp x))
    :rule-classes :compound-recognizer))


