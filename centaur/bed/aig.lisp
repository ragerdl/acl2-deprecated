; Centaur BED Library
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
; Original authors: Jared Davis <jared@centtech.com>

(in-package "BED")
(include-book "mk1")
(include-book "centaur/aig/aig-base" :dir :system)
(local (include-book "centaur/misc/arith-equivs" :dir :system))
(local (in-theory (enable* arith-equiv-forwarding)))


(defsection aig-translation
  :parents (bed)
  :short "Translators to convert Hons @(see aig)s into BEDs, and vice-versa.")

(define aig-from-bed
  :parents (aig-translation)
  :short "Translate a BED into an AIG."
  ((bed "The BED to convert."))
  :returns (aig "A new AIG that is equivalent to the input @('bed').")

  :long "<p>This is an especially naive conversion.  For efficiency this
function is memoized, and you should generally clear its memo table after you
use it.</p>"

  (b* (((when (atom bed))
        (if bed t nil))
       ((cons a b) bed)
       ((when (atom a))
        (aig-ite a
                 (aig-from-bed (car$ b))
                 (aig-from-bed (cdr$ b))))
       (op    (bed-op-fix b))
       (left  (aig-from-bed (car$ a)))
       (right (aig-from-bed (cdr$ a)))
       ;; We could avoid computing left/right in some cases, but in practice we
       ;; don't expect to really ever construct these nodes, so we don't expect
       ;; it to be worthwhile to do so.
       ((when (eql op (bed-op-true)))  t)
       ((when (eql op (bed-op-false))) nil)
       ((when (eql op (bed-op-ior)))   (aig-or left right))
       ((when (eql op (bed-op-orc2)))  (aig-or left (aig-not right)))
       ((when (eql op (bed-op-arg1)))  left)
       ((when (eql op (bed-op-orc1)))  (aig-or (aig-not left) right))
       ((when (eql op (bed-op-arg2)))  right)
       ((when (eql op (bed-op-eqv)))   (aig-iff left right))
       ((when (eql op (bed-op-and)))   (aig-and left right))
       ((when (eql op (bed-op-nand)))  (aig-not (aig-and left right)))
       ((when (eql op (bed-op-xor)))   (aig-xor left right))
       ((when (eql op (bed-op-not2)))  (aig-not right))
       ((when (eql op (bed-op-andc2))) (aig-and left (aig-not right)))
       ((when (eql op (bed-op-not1)))  (aig-not left))
       ((when (eql op (bed-op-andc1))) (aig-and (aig-not left) right))
       ((when (eql op (bed-op-nor)))   (aig-not (aig-or left right)))
       )
    ;; Else, it's not valid
    :impossible)
  ///
  (memoize 'aig-from-bed :condition '(consp bed))

  (local (defthm aig-eval-of-nil
           (equal (aig-eval nil env)
                  nil)))

  (local (defthm aig-eval-of-t
           (equal (aig-eval t env)
                  t)))

  (local (defthm aig-eval-of-atom
           (implies (and (atom x)
                         (not (booleanp x)))
                    (equal (aig-eval x env)
                           (and (aig-env-lookup x env)
                                t)))
           :hints(("Goal" :in-theory (enable aig-eval)))))

  (local (defthm bed-env-lookup-removal
           (equal (bed-env-lookup var env)
                  (if (booleanp var)
                      var
                    (aig-env-lookup var env)))
           :hints(("Goal" :in-theory (enable bed-env-lookup
                                             aig-env-lookup)))))

  (local (in-theory (disable aig-env-lookup)))

  (local (defthm crock
           (implies (and (bed-op-p op)
                         (NOT (EQUAL OP (BED-OP-TRUE)))
                         (NOT (EQUAL OP (BED-OP-IOR)))
                         (NOT (EQUAL OP (BED-OP-ORC2)))
                         (NOT (EQUAL OP (BED-OP-ARG1)))
                         (NOT (EQUAL OP (BED-OP-ORC1)))
                         (NOT (EQUAL OP (BED-OP-ARG2)))
                         (NOT (EQUAL OP (BED-OP-EQV)))
                         (NOT (EQUAL OP (BED-OP-AND)))
                         (NOT (EQUAL OP (BED-OP-NAND)))
                         (NOT (EQUAL OP (BED-OP-XOR)))
                         (NOT (EQUAL OP (BED-OP-NOT2)))
                         (NOT (EQUAL OP (BED-OP-ANDC2)))
                         (NOT (EQUAL OP (BED-OP-NOT1)))
                         (NOT (EQUAL OP (BED-OP-ANDC1)))
                         (NOT (EQUAL OP (BED-OP-NOR))))
                    (equal (EQUAL OP (BED-OP-FALSE))
                           t))
           :hints(("Goal"
                   :in-theory (enable bed-op-p
                                      bed-op-true
                                      bed-op-ior
                                      bed-op-orc2
                                      bed-op-arg1
                                      bed-op-orc1
                                      bed-op-arg2
                                      bed-op-eqv
                                      bed-op-and
                                      bed-op-nand
                                      bed-op-xor
                                      bed-op-not2
                                      bed-op-andc2
                                      bed-op-not1
                                      bed-op-andc1
                                      bed-op-nor
                                      bed-op-false)))))

  (local (defun my-induct (x)
           (b* (((when (atom x))
                 nil)
                ((cons a b) x)
                ((when (atom a))
                 (list (my-induct (car b))
                       (my-induct (cdr b)))))
             (list (my-induct (car a))
                   (my-induct (cdr a))))))

  (defthm aig-eval-of-aig-from-bed
    (equal (aig-eval (aig-from-bed bed) env)
           (eql 1 (bed-eval bed env)))
    :hints(("Goal"
            :induct (my-induct bed)
            :in-theory (e/d (bed-eval)
                            (aig-eval))
            :expand (aig-from-bed bed)
            :do-not '(eliminate-destructors generalize fertilize)
            :do-not-induct t))))


(local (xdoc::set-default-parents bed-from-aig))

(define match-aig-not ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(not arg)').")
               (arg "On success, the @('arg') from the match."))
  :inline t
  (if (and (consp x)
           (not (cdr x)))
      (mv t (car x))
    (mv nil nil))
  ///
  (defthm match-aig-not-correct
    (b* (((mv okp arg) (match-aig-not x)))
      (implies okp
               (equal (aig-eval x env)
                      (not (aig-eval arg env))))))

  (defthm acl2-count-of-match-aig-not-weak
    (b* (((mv ?okp arg) (match-aig-not x)))
      (<= (acl2-count arg)
          (acl2-count x)))
    :rule-classes ((:rewrite) (:linear)))

  (defthm acl2-count-of-match-aig-not-strong
    (b* (((mv okp arg) (match-aig-not x)))
      (implies okp
               (< (acl2-count arg)
                  (acl2-count x))))
    :rule-classes ((:rewrite) (:linear))))

(defmacro def-match-aig-acl2-count-thms (fn)
  (let ((name (symbol-name fn)))
    `(progn
       (defthm ,(intern-in-package-of-symbol
                 (str::cat "ACL2-COUNT-OF-" name "-WEAK-1")
                 fn)
         (b* (((mv & arg1 &) (,fn x)))
           (<= (acl2-count arg1)
               (acl2-count x)))
         :rule-classes ((:rewrite) (:linear)))
       (defthm ,(intern-in-package-of-symbol
                 (str::cat "ACL2-COUNT-OF-" name "-WEAK-2")
                 fn)
         (b* (((mv & & arg2) (,fn x)))
           (<= (acl2-count arg2)
               (acl2-count x)))
         :rule-classes ((:rewrite) (:linear)))
       (defthm ,(intern-in-package-of-symbol
                 (str::cat "ACL2-COUNT-OF-" name "-STRONG-1")
                 fn)
         (b* (((mv okp arg1 &) (,fn x)))
           (implies okp
                    (< (acl2-count arg1)
                       (acl2-count x))))
         :rule-classes ((:rewrite) (:linear)))
       (defthm ,(intern-in-package-of-symbol
                 (str::cat "ACL2-COUNT-OF-" name "-STRONG-2")
                 fn)
         (b* (((mv okp & arg2) (,fn x)))
           (implies okp
                    (< (acl2-count arg2)
                       (acl2-count x))))
         :rule-classes ((:rewrite) (:linear))))))

(define match-aig-and ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(and arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  :inline t
  (if (and (consp x)
           (cdr x))
      (mv t (car x) (cdr x))
    (mv nil nil nil))
  ///
  (defthm match-aig-and-correct
    (b* (((mv okp arg1 arg2) (match-aig-and x)))
      (implies okp
               (equal (aig-eval x env)
                      (and (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-and))

(define match-aig-nor ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(nor arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;; (NOR A B) == (AND (NOT A) (NOT B))
  (b* (((mv okp na nb) (match-aig-and x))
       ((unless okp) (mv nil nil nil))
       ((mv okp a) (match-aig-not na))
       ((unless okp) (mv nil nil nil))
       ((mv okp b) (match-aig-not nb))
       ((unless okp) (mv nil nil nil)))
    (mv t a b))
  ///
  (defthm match-aig-nor-correct
    (b* (((mv okp arg1 arg2) (match-aig-nor x)))
      (implies okp
               (equal (aig-eval x env)
                      (not (or (aig-eval arg1 env)
                               (aig-eval arg2 env)))))))
  (def-match-aig-acl2-count-thms match-aig-nor))

(define match-aig-andc1 ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(andc1 arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;; (ANDC1 A B) == (AND (NOT A) B)
  (b* (((mv okp na b) (match-aig-and x))
       ((unless okp) (mv nil nil nil))
       ((mv okp a) (match-aig-not na))
       ((unless okp) (mv nil nil nil)))
    (mv t a b))
  ///
  (defthm match-aig-andc1-correct
    (b* (((mv okp arg1 arg2) (match-aig-andc1 x)))
      (implies okp
               (equal (aig-eval x env)
                      (and (not (aig-eval arg1 env))
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-andc1))

(define match-aig-andc2 ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(andc2 arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;; (ANDC2 A B) == (AND A (NOT B))
  (b* (((mv okp a nb) (match-aig-and x))
       ((unless okp) (mv nil nil nil))
       ((mv okp b) (match-aig-not nb))
       ((unless okp) (mv nil nil nil)))
    (mv t a b))
  ///
  (defthm match-aig-andc2-correct
    (b* (((mv okp arg1 arg2) (match-aig-andc2 x)))
      (implies okp
               (equal (aig-eval x env)
                      (and (aig-eval arg1 env)
                           (not (aig-eval arg2 env)))))))
  (def-match-aig-acl2-count-thms match-aig-andc2))

(define match-aig-or ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(or arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;; (OR A B) == (NOT (AND (NOT A) (NOT B)))
  (b* (((mv okp and-na-nb) (match-aig-not x))
       ((unless okp) (mv nil nil nil)))
    (match-aig-nor and-na-nb))
  ///
  (defthm match-aig-or-correct
    (b* (((mv okp arg1 arg2) (match-aig-or x)))
      (implies okp
               (equal (aig-eval x env)
                      (or (aig-eval arg1 env)
                          (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-or))

(define match-aig-iff-1 ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(iff arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;;  We'll look for any of these:
  ;;    (or (and a b) (nor a b))
  ;;    (or (and a b) (nor b a))
  ;;    (or (nor a b) (and a b))
  ;;    (or (nor a b) (and b a))
  (b* (((mv okp left right) (match-aig-or x))
       ((unless okp) (mv nil nil nil))
       ((mv okp a b) (match-aig-and left))
       ((when okp)
        (b* (((mv okp c d) (match-aig-nor right))
             ((unless okp)
              (mv nil nil nil))
             ((when (and (hons-equal a c) (hons-equal b d)))
              (mv t a b))
             ((when (and (hons-equal a d) (hons-equal b c)))
              (mv t a b)))
          (mv nil nil nil)))
       ((mv okp a b) (match-aig-nor left))
       ((unless okp) (mv nil nil nil))
       ((mv okp c d) (match-aig-and right))
       ((unless okp) (mv nil nil nil))
       ((when (and (hons-equal a c) (hons-equal b d)))
        (mv t a b))
       ((when (and (hons-equal a d) (hons-equal b c)))
        (mv t a b)))
    (mv nil nil nil))
  ///
  (defthm match-aig-iff-1-correct
    (b* (((mv okp arg1 arg2) (match-aig-iff-1 x)))
      (implies okp
               (equal (aig-eval x env)
                      (iff (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-iff-1))

(define match-aig-iff-2 ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(iff arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;;  We'll look for any of these:
  ;;    (nor (andc1 a b) (andc1 b a))
  ;;    (nor (andc1 a b) (andc2 a b))
  ;;    (nor (andc2 a b) (andc1 a b))
  ;;    (nor (andc2 a b) (andc2 b a))
  (b* (((mv okp left right) (match-aig-nor x))
       ((unless okp) (mv nil nil nil))
       ((mv okp a b) (match-aig-andc1 left))
       ((when okp)
        (b* (((mv okp c d) (match-aig-andc1 right))
             ((when (and okp (hons-equal a d) (hons-equal b c)))
              (mv t a b))
             ((mv okp c d) (match-aig-andc2 right))
             ((when (and okp (hons-equal a c) (hons-equal b d)))
              (mv t a b)))
          (mv nil nil nil)))
       ((mv okp a b) (match-aig-andc2 left))
       ((unless okp) (mv nil nil nil))
       ((mv okp c d) (match-aig-andc1 right))
       ((when (and okp (hons-equal a c) (hons-equal b d)))
        (mv t a b))
       ((mv okp c d) (match-aig-andc2 right))
       ((when (and okp (hons-equal a d) (hons-equal b c)))
        (mv t a b)))
    (mv nil nil nil))
  ///
  (defthm match-aig-iff-2-correct
    (b* (((mv okp arg1 arg2) (match-aig-iff-2 x)))
      (implies okp
               (equal (aig-eval x env)
                      (iff (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-iff-2))

(define match-aig-iff ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(iff arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  (b* (((mv okp a b) (match-aig-iff-1 x))
       ((when okp) (mv okp a b)))
    (match-aig-iff-2 x))
  ///
  (defthm match-aig-iff-correct
    (b* (((mv okp arg1 arg2) (match-aig-iff x)))
      (implies okp
               (equal (aig-eval x env)
                      (iff (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-iff))

(define match-aig-xor-1 ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(xor arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;;  We'll look for any of these:
  ;;    (or (andc1 a b) (andc1 b a))
  ;;    (or (andc1 a b) (andc2 a b))
  ;;    (or (andc2 a b) (andc1 a b))
  ;;    (or (andc2 a b) (andc2 b a))
  (b* (((mv okp left right) (match-aig-or x))
       ((unless okp) (mv nil nil nil))
       ((mv okp a b) (match-aig-andc1 left))
       ((when okp)
        (b* (((mv okp c d) (match-aig-andc1 right))
             ((when (and okp (hons-equal a d) (hons-equal b c)))
              (mv t a b))
             ((mv okp c d) (match-aig-andc2 right))
             ((when (and okp (hons-equal a c) (hons-equal b d)))
              (mv t a b)))
          (mv nil nil nil)))
       ((mv okp a b) (match-aig-andc2 left))
       ((unless okp) (mv nil nil nil))
       ((mv okp c d) (match-aig-andc1 right))
       ((when (and okp (hons-equal a c) (hons-equal b d)))
        (mv t a b))
       ((mv okp c d) (match-aig-andc2 right))
       ((when (and okp (hons-equal a d) (hons-equal b c)))
        (mv t a b)))
    (mv nil nil nil))
  ///
  (defthm match-aig-xor-1-correct
    (b* (((mv okp arg1 arg2) (match-aig-xor-1 x)))
      (implies okp
               (equal (aig-eval x env)
                      (xor (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-xor-1))

(define match-aig-xor-2 ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(iff arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  ;;  We'll look for any of these:
  ;;    (nor (and a b) (nor a b))
  ;;    (nor (and a b) (nor b a))
  ;;    (nor (nor a b) (and a b))
  ;;    (nor (nor a b) (and b a))
  (b* (((mv okp left right) (match-aig-nor x))
       ((unless okp) (mv nil nil nil))
       ((mv okp a b) (match-aig-and left))
       ((when okp)
        (b* (((mv okp c d) (match-aig-nor right))
             ((unless okp)
              (mv nil nil nil))
             ((when (and (hons-equal a c) (hons-equal b d)))
              (mv t a b))
             ((when (and (hons-equal a d) (hons-equal b c)))
              (mv t a b)))
          (mv nil nil nil)))
       ((mv okp a b) (match-aig-nor left))
       ((unless okp) (mv nil nil nil))
       ((mv okp c d) (match-aig-and right))
       ((unless okp) (mv nil nil nil))
       ((when (and (hons-equal a c) (hons-equal b d)))
        (mv t a b))
       ((when (and (hons-equal a d) (hons-equal b c)))
        (mv t a b)))
    (mv nil nil nil))
  ///
  (defthm match-aig-xor-2-correct
    (b* (((mv okp arg1 arg2) (match-aig-xor-2 x)))
      (implies okp
               (equal (aig-eval x env)
                      (xor (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-xor-2))

(define match-aig-xor ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(xor arg1 arg2)').")
               (arg1 "On success, @('arg1') from the match.")
               (arg2 "On success, @('arg2') from the match."))
  (b* (((mv okp a b) (match-aig-xor-1 x))
       ((when okp) (mv okp a b)))
    (match-aig-xor-2 x))
  ///
  (defthm match-aig-xor-correct
    (b* (((mv okp arg1 arg2) (match-aig-xor x)))
      (implies okp
               (equal (aig-eval x env)
                      (xor (aig-eval arg1 env)
                           (aig-eval arg2 env))))))
  (def-match-aig-acl2-count-thms match-aig-xor))


(define match-aig-var-ite-aux
  (var a1 a2 b1 b2 x)
  ;; The use of X here is a horrible, redundant hack, just so that I can write
  ;; a theorem that fires in the right way.
  (declare (ignore x))
  :returns (mv okp
               (var atom :rule-classes :type-prescription)
               a b)
  :short "We have been given the AIG @('(OR (AND A1 A2) (OR B1 B2))').  We want
to pattern match it against @('(IF VAR A B)')?"
  (b* (((unless (and (atom var)
                     (not (booleanp var))))
        (mv nil nil nil nil))

       ((when (equal var a1))
        ;; (OR (AND VAR A) (AND (NOT VAR) B))
        ;; (OR (AND VAR A) (AND B (NOT VAR)))
        (b* (((mv okp b1-guts) (match-aig-not b1))
             ((when (and okp (equal b1-guts var)))
              (mv t var a2 b2))
             ((mv okp b2-guts) (match-aig-not b2))
             ((when (and okp (equal b2-guts var)))
              (mv t var a2 b1)))
          (mv nil nil nil nil)))

       ((when (equal var a2))
        ;; (OR (AND A VAR) (AND (NOT VAR) B))
        ;; (OR (AND A VAR) (AND B (NOT VAR)))
        (b* (((mv okp b1-guts) (match-aig-not b1))
             ((when (and okp (equal b1-guts var)))
              (mv t var a1 b2))
             ((mv okp b2-guts) (match-aig-not b2))
             ((when (and okp (equal b2-guts var)))
              (mv t var a1 b1)))
          (mv nil nil nil nil)))

       ((when (equal var b1))
        ;; (OR (AND (NOT VAR) B) (AND VAR A))
        ;; (OR (AND B (NOT VAR)) (AND VAR A))
        (b* (((mv okp a1-guts) (match-aig-not a1))
             ((when (and okp (equal a1-guts var)))
              (mv t var b2 a2))
             ((mv okp a2-guts) (match-aig-not a2))
             ((when (and okp (equal a2-guts var)))
              (mv t var b2 a1)))
          (mv nil nil nil nil)))

       ((when (equal var b2))
        ;; (OR (AND (NOT VAR) B) (AND A VAR))
        ;; (OR (AND B (NOT VAR)) (AND A VAR))
        (b* (((mv okp a1-guts) (match-aig-not a1))
             ((when (and okp (equal a1-guts var)))
              (mv t var b1 a2))
             ((mv okp a2-guts) (match-aig-not a2))
             ((when (and okp (equal a2-guts var)))
              (mv t var b1 a1)))
          (mv nil nil nil nil))))
    (mv nil nil nil nil))
  ///
  (defthm not-booleanp-of-match-aig-var-ite-aux
    (b* (((mv okp var & &) (match-aig-var-ite-aux var a1 a2 b1 b2 x)))
      (implies okp
               (and (atom var)
                    (not (equal var t))
                    (not (equal var nil)))))
    :rule-classes :type-prescription)

  (defthmd match-aig-var-ite-aux-correct
    (b* (((mv okp1 left right) (match-aig-or x))
         ((mv okp2 a1 a2)      (match-aig-and left))
         ((mv okp3 b1 b2)      (match-aig-and right))
         ((mv okp4 var a b)    (match-aig-var-ite-aux var a1 a2 b1 b2 x)))
      (implies (and okp1
                    okp2
                    okp3
                    okp4)
               (equal (aig-eval x env)
                      (if (aig-eval var env)
                          (aig-eval a env)
                        (aig-eval b env))))))

  (defthmd acl2-count-of-match-aig-var-ite-aux-weak
    (b* (((mv okp1 left right) (match-aig-or x))
         ((mv okp2 a1 a2)      (match-aig-and left))
         ((mv okp3 b1 b2)      (match-aig-and right))
         ((mv ?okp var a b)    (match-aig-var-ite-aux var a1 a2 b1 b2 x)))
      (implies (and okp1 okp2 okp3)
               (and (<= (acl2-count var)
                        (acl2-count x))
                    (<= (acl2-count a)
                        (acl2-count x))
                    (<= (acl2-count b)
                        (acl2-count x))))))

  (defthmd acl2-count-of-match-aig-var-ite-aux-strong
    (b* (((mv okp1 left right) (match-aig-or x))
         ((mv okp2 a1 a2)      (match-aig-and left))
         ((mv okp3 b1 b2)      (match-aig-and right))
         ((mv okp4 var a b)    (match-aig-var-ite-aux var a1 a2 b1 b2 x)))
      (implies (and okp1
                    okp2
                    okp3
                    okp4)
               (and (< (acl2-count var)
                       (acl2-count x))
                    (< (acl2-count a)
                       (acl2-count x))
                    (< (acl2-count b)
                       (acl2-count x)))))))

(define match-aig-var-ite ((x "AIG to pattern match."))
  :returns (mv (okp "Whether @('x') matches @('(if var a b)').")
               (var "On success, @('var') from the match."
                    atom :rule-classes :type-prescription)
               (a   "On success, @('a') from the match.")
               (b   "On success, @('b') from the match."))
  (b* (((mv okp left right) (match-aig-or x))
       ((unless okp) (mv nil nil nil nil))
       ((mv okp a1 a2) (match-aig-and left))
       ((unless okp) (mv nil nil nil nil))
       ((mv okp b1 b2) (match-aig-and right))
       ((unless okp) (mv nil nil nil nil))
       ((mv okp var a b) (match-aig-var-ite-aux a1 a1 a2 b1 b2 x))
       ((when okp) (mv t var a b))
       ((mv okp var a b) (match-aig-var-ite-aux a2 a1 a2 b1 b2 x))
       ((when okp) (mv t var a b))
       ((mv okp var a b) (match-aig-var-ite-aux b1 a1 a2 b1 b2 x))
       ((when okp) (mv t var a b))
       ((mv okp var a b) (match-aig-var-ite-aux b2 a1 a2 b1 b2 x))
       ((when okp) (mv t var a b)))
    (mv nil nil nil nil))
  ///
  (local (in-theory (enable match-aig-var-ite-aux-correct)))
  (defthm match-aig-var-ite-correct
    (b* (((mv okp var a b) (match-aig-var-ite x)))
      (implies okp
               (equal (aig-eval x env)
                      (if (aig-eval var env)
                          (aig-eval a env)
                        (aig-eval b env))))))

  (defthm not-booleanp-of-match-aig-var-ite
    (b* (((mv okp var & &) (match-aig-var-ite x)))
      (implies okp
               (and (atom var)
                    (not (equal var t))
                    (not (equal var nil)))))
    :rule-classes :type-prescription)

  (local (in-theory (enable acl2-count-of-match-aig-var-ite-aux-weak
                            acl2-count-of-match-aig-var-ite-aux-strong)))

  (defthm acl2-count-of-match-aig-var-ite-weak-1
    (b* (((mv ?okp ?var ?a ?b) (match-aig-var-ite x)))
      (<= (acl2-count var)
          (acl2-count x)))
    :rule-classes ((:rewrite) (:linear)))
  (defthm acl2-count-of-match-aig-var-ite-weak-2
    (b* (((mv ?okp ?var ?a ?b) (match-aig-var-ite x)))
      (<= (acl2-count a)
          (acl2-count x)))
    :rule-classes ((:rewrite) (:linear)))
  (defthm acl2-count-of-match-aig-var-ite-weak-3
    (b* (((mv ?okp ?var ?a ?b) (match-aig-var-ite x)))
      (<= (acl2-count b)
          (acl2-count x)))
    :rule-classes ((:rewrite) (:linear)))

  (defthm acl2-count-of-match-aig-var-ite-strong-1
    (b* (((mv ?okp ?var ?a ?b) (match-aig-var-ite x)))
      (implies okp
               (< (acl2-count var)
                  (acl2-count x))))
    :rule-classes ((:rewrite) (:linear)))
  (defthm acl2-count-of-match-aig-var-ite-strong-2
    (b* (((mv ?okp ?var ?a ?b) (match-aig-var-ite x)))
      (implies okp
               (< (acl2-count a)
                  (acl2-count x))))
    :rule-classes ((:rewrite) (:linear)))
  (defthm acl2-count-of-match-aig-var-ite-strong-3
    (b* (((mv ?okp ?var ?a ?b) (match-aig-var-ite x)))
      (implies okp
               (< (acl2-count b)
                  (acl2-count x))))
    :rule-classes ((:rewrite) (:linear))))

(define bed-from-aig-aux ((x     "The AIG to transform into a BED.")
                          (order "The ordering for @(see bed-order).")
                          (memo  "Seen table, associates AIGs to BEDs."))
  :returns (mv (bed   "A bed that evaluates in the same way as @('x').")
               (order "The updated ordering.")
               (memo  "The updated seen table."))
  :parents (bed-from-aig)
  (b* (((when (atom x))
        (cond ((or (eq x t)
                   (eq x nil))
               (mv x order memo))
              (t
               (mv (mk-var-raw x t nil) order memo))))

       (look (hons-get x memo))
       ((when look)
        (mv (cdr look) order memo))

       ;; Probably silly: we will try to notice higher level structures in the
       ;; AIG and convert them into more natural BED nodes.

       ((mv okp var a b) (match-aig-var-ite x))
       ((when okp)
        (b* (((mv bed1 order memo) (bed-from-aig-aux a order memo))
             ((mv bed2 order memo) (bed-from-aig-aux b order memo))
             (ans                  (mk-var1 var bed1 bed2))
             (memo                 (hons-acons x ans memo)))
          (mv ans order memo)))

       ((mv okp a b) (match-aig-iff x))
       ((when okp)
        (b* (((mv bed1 order memo) (bed-from-aig-aux a order memo))
             ((mv bed2 order memo) (bed-from-aig-aux b order memo))
             ((mv ans order)       (mk-op1 (bed-op-eqv) bed1 bed2 order))
             (memo                 (hons-acons x ans memo)))
          (mv ans order memo)))

       ((mv okp a b) (match-aig-xor x))
       ((when okp)
        (b* (((mv bed1 order memo) (bed-from-aig-aux a order memo))
             ((mv bed2 order memo) (bed-from-aig-aux b order memo))
             ((mv ans order)       (mk-op1 (bed-op-xor) bed1 bed2 order))
             (memo                 (hons-acons x ans memo)))
          (mv ans order memo)))

       ((mv okp a b) (match-aig-or x))
       ((when okp)
        (b* (((mv bed1 order memo) (bed-from-aig-aux a order memo))
             ((when (eq bed1 t))
              ;; Short circuit: no need to process the CDR.
              (mv t order (hons-acons x t memo)))
             ((mv bed2 order memo) (bed-from-aig-aux b order memo))
             ((mv ans order)       (mk-op1 (bed-op-ior) bed1 bed2 order))
             (memo                 (hons-acons x ans memo)))
          (mv ans order memo)))

       ((unless (cdr x))
        (b* (((mv arg order memo)
              (bed-from-aig-aux (car x) order memo)))
          (mv (mk-not arg) order memo)))

       ((mv bed1 order memo) (bed-from-aig-aux (car x) order memo))
       ((when (not bed1))
        ;; Reduced it all the way to NIL, no need to process the CDR.
        (mv nil order (hons-acons x nil memo)))

       ((mv bed2 order memo) (bed-from-aig-aux (cdr x) order memo))
       ((mv ans order) (mk-op1 (bed-op-and) bed1 bed2 order)))
    (mv ans order (hons-acons x ans memo))))

(define bed-from-aig ((x "An AIG to transform into a BED."))
  :returns (mv (bed   "A bed that evaluates in the same way as @('x').")
               (order "An ordering on the nodes of bed for @(see bed-order)."))
  :short "Translate an AIG into a BED."
  (b* ((memo  10000)
       (order :bed-order)
       ((mv bed order memo) (bed-from-aig-aux x order memo)))
    (fast-alist-free memo)
    (mv bed order))
  ///
  (local (include-book "centaur/misc/arith-equivs" :dir :system))
  (local (in-theory (enable* arith-equiv-forwarding)))

  (local (in-theory (enable bed-from-aig-aux)))

  (local (defun-sk memo-okp (env memo)
           (forall (aig)
                   (b* ((look (hons-assoc-equal aig memo)))
                     (implies look
                              (equal (bed-eval (cdr look) env)
                                     (bool->bit (aig-eval aig env))))))
           :rewrite :direct))

  (local (defthm memo-okp-when-atom
           (implies (atom memo)
                    (memo-okp env memo))))

  (local (defthm memo-okp-lookup
           (implies (and (case-split (memo-okp env memo))
                         (case-split (hons-assoc-equal aig memo)))
                    (equal (bed-eval (cdr (hons-assoc-equal aig memo)) env)
                           (bool->bit (aig-eval aig env))))))

  (local (defthm memo-okp-extend
           (implies (and (case-split (memo-okp env memo))
                         (case-split (equal (bed-eval bed env)
                                            (bool->bit (aig-eval aig env)))))
                    (memo-okp env (hons-acons aig bed memo)))))

  (local (defthm bed-env-lookup-is-aig-env-lookup
           (implies (not (booleanp var))
                    (equal (bed-env-lookup var env)
                           (aig-env-lookup var env)))
           :hints(("Goal" :in-theory (enable bed-env-lookup)))))
  (local (in-theory (disable aig-env-lookup)))

  (local (defthm crux
           (implies (memo-okp env memo)
                    (b* (((mv bed ?order memo) (bed-from-aig-aux x order memo)))
                      (and (equal (bed-eval bed env)
                                  (bool->bit (aig-eval x env)))
                           (memo-okp env memo))))
           :hints(("Goal"
                   :induct (bed-from-aig-aux x order memo)
                   :in-theory (disable memo-okp
                                       hons-acons)))))

  (defthm bed-eval-of-bed-from-aig
    (b* (((mv bed ?order) (bed-from-aig aig)))
      (equal (bed-eval bed env)
             (bool->bit (aig-eval aig env))))
    :hints(("Goal" :in-theory (e/d (bed-from-aig)
                                   (bed-from-aig-aux
                                    bed-eval
                                    aig-eval))))))

