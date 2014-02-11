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
; Original author: Sol Swords <sswords@centtech.com>

; witness-cp.lisp:  Clause processor for reasoning about quantifier-like
; predicates.

(in-package "ACL2")

(include-book "use-by-hint")
(include-book "generalize")
(include-book "unify-subst")
(include-book "tools/bstar" :dir :system)
(include-book "ev-theoremp")
(include-book "tools/def-functional-instance" :dir :system)
(include-book "data-structures/no-duplicates" :dir :system)
(include-book "magic-ev")
(include-book "std/util/defaggregate" :dir :system)
(include-book "std/util/defines" :dir :system)
(include-book "meta-extract-user")
(include-book "tools/easy-simplify" :dir :system)
(set-inhibit-warnings "theory")


(local (in-theory (disable state-p1-forward)))

;; See :DOC WITNESS-CP, or read it below.


(local (in-theory (disable true-listp default-car default-cdr
                           alistp default-+-2 default-+-1
; [Removed by Matt K. to handle changes to member, assoc, etc. after ACL2 4.2.]
;                            assoc
                           pseudo-termp pseudo-term-listp
                           pseudo-term-list-listp nth
                           intersectp-equal-non-cons
                           substitute-into-term
                           state-p-implies-and-forward-to-state-p1
                           w
                           (force))))


;; ;; [Jared] I localized these theorems since they're not really the point of
;; ;; this book, and it seems nicer not to "randomly" export stuff like this.

(local (defthm alistp-append
         (implies (and (alistp a) (alistp b))
                  (alistp (append a b)))
         :hints(("Goal" :in-theory (enable alistp)))))

(local (defthm symbol-listp-of-append
         (implies (and (symbol-listp x)
                       (symbol-listp y))
                  (symbol-listp (append x y)))))

(local (defthm strip-cdrs-of-append
         (equal (strip-cdrs (append a b))
                (append (strip-cdrs a) (strip-cdrs b)))))

(local (defthm member-equal-of-append
         (iff (member-equal x (append a b))
              (or (member-equal x a)
                  (member-equal x b)))))

(local (defthm len-append
         (equal (len (append a b))
                (+ (len a) (len b)))))

(local (defthm strip-cdrs-pairlis$
         (implies (and (equal (len a) (len b))
                       (true-listp b))
                  (equal (strip-cdrs (pairlis$ a b)) b))))

(local (defthm len-strip-cars
         (equal (len (strip-cars x)) (len x))))

(local (defthm len-strip-cdrs
         (equal (len (strip-cdrs x)) (len x))))

(local (defthm strip-cdrs-pairlis
         (implies (and (equal (len a) (len b))
                       (true-listp b))
                  (equal (strip-cdrs (pairlis$ a b)) b))))

(local (defthmd pseudo-term-listp-true-listp
         (implies (pseudo-term-listp x)
                  (true-listp x))))

(local (defthmd pseudo-term-list-listp-true-listp
         (implies (pseudo-term-list-listp x)
                  (true-listp x))
         :hints(("Goal" :in-theory (enable pseudo-term-list-listp)))))

(local (defthmd alistp-implies-true-listp
         (implies (alistp x) (true-listp x))
         :hints(("Goal" :in-theory (enable alistp)))))


(local (defthm pseudo-term-list-listp-append
         (implies (and (pseudo-term-list-listp a)
                       (pseudo-term-list-listp b))
                  (pseudo-term-list-listp (append a b)))
         :hints(("Goal" :in-theory (enable pseudo-term-list-listp)))))


(local (defthm pseudo-term-listp-append
         (implies (and (pseudo-term-listp a)
                       (pseudo-term-listp b))
                  (pseudo-term-listp (append a b)))
         :hints(("Goal" :in-theory (enable pseudo-term-listp)))))

(local (defthm strip-cars-of-append
         (equal (strip-cars (append a b))
                (append (strip-cars a) (strip-cars b)))))




(defevaluator-fast witness-ev witness-ev-lst
  ((if a b c)
   (not a)
   (equal a b)
   (use-these-hints x)
   (implies a b) (hide x)
   (cons a b) (binary-+ a b)
   (typespec-check ts x)
   (iff a b))
  :namedp t)

(def-meta-extract witness-ev witness-ev-lst)
(def-ev-theoremp witness-ev)
(def-unify witness-ev witness-ev-alist)

(defsection dumb-negate-lit-lemmas
  (defthm witness-ev-of-dumb-negate-lit
    (implies (pseudo-termp lit)
             (iff (witness-ev (dumb-negate-lit lit) a)
                  (not (witness-ev lit a))))
    :hints(("Goal" :in-theory (enable pseudo-termp))))

  (defthm pseudo-termp-dumb-negate-lit
    (implies (pseudo-termp lit)
             (pseudo-termp (dumb-negate-lit lit)))
    :hints(("Goal" :in-theory (enable pseudo-termp
                                      pseudo-term-listp))))

  ;; non-book-local in-theory?
  (in-theory (disable dumb-negate-lit)))


(defun assert-msg (msg arg)
  (declare (xargs :guard t))
  (b* (((mv str alist) (if (atom msg)
                           (mv msg nil)
                         (mv (car msg) (cdr msg)))))
    (cons str (cons (cons #\t arg) alist))))


(defun asserts-macro (msg terms)
  (if (atom terms)
      t
    `(and (or ,(car terms)
              (cw "~@0~%" (assert-msg ,msg ',(car terms))))
          ,(asserts-macro msg (cdr terms)))))

(defmacro asserts (msg &rest terms)
  `(let ((msg ,msg))
     ,(asserts-macro 'msg terms)))

;;========================================================================
;; Structures
;;========================================================================

(std::defaggregate wcp-witness-rule
  ((name symbolp)
   (enabledp)
   (term pseudo-termp)
   (expr pseudo-termp)
   restriction
   (theorem symbolp) ;; name of formula justifying the rule
   (generalize (and (alistp generalize)
                    (pseudo-term-listp (strip-cars generalize))
                    (symbol-listp (strip-cdrs generalize))))))

(std::defaggregate wcp-instance-rule
  ((name symbolp)
   (enabledp)
   (pred pseudo-termp)
   (vars (and (symbol-listp vars)
              (not (intersectp-equal vars (simple-term-vars pred)))))
   (expr pseudo-termp)
   (restriction pseudo-termp)
   (theorem symbolp)))

(define wcp-instance-rulesp (x)
  (or (atom x)
      (and (wcp-instance-rule-p (car x))
           (wcp-instance-rulesp (cdr x))))
  ///
  (defopen wcp-instance-rulesp-when-consp
    (wcp-instance-rulesp x)
    :hyp (consp x)
    :hint (:expand ((wcp-instance-rulesp x)))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))

(std::defaggregate wcp-template
  ((name symbolp)
   (enabledp)
   (pat pseudo-termp)
   (templ pseudo-term-listp)
   (rulenames symbol-listp)
   (restriction pseudo-termp)))

(define wcp-templatesp (templates)
  (or (atom templates)
      (and (wcp-template-p (car templates))
           (wcp-templatesp (cdr templates))))
  ///
  (defopen wcp-templatesp-when-consp
    (wcp-templatesp templates)
    :hyp (consp templates)
    :hint (:expand ((wcp-templatesp templates)))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))

(std::defaggregate wcp-example-app
  ((instrule wcp-instance-rule-p)
   (bindings (and (pseudo-term-listp bindings)
                  (eql (len bindings) (len (wcp-instance-rule->vars instrule)))))))

(define wcp-witness-rulesp (x)
  (if (atom x)
      (eq x nil)
    (and (wcp-witness-rule-p (car x))
         (wcp-witness-rulesp (cdr x))))
  ///
  (defopen wcp-witness-rulesp-when-consp
    (wcp-witness-rulesp x)
    :hyp (consp x)
    :hint (:expand ((wcp-witness-rulesp x)))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))

(define wcp-example-appsp (x)
  (if (atom x)
      (eq x nil)
    (and (wcp-example-app-p (car x))
         (wcp-example-appsp (cdr x))))
  ///
  (defopen wcp-example-appsp-when-consp
    (wcp-example-appsp x)
    :hyp (consp x)
    :hint (:expand ((wcp-example-appsp x)))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))

(std::defaggregate wcp-lit-actions
  ((witnesses wcp-witness-rulesp)
   (examples wcp-example-appsp)))

(define wcp-lit-actions-listp (x)
  (if (atom x)
      (eq x nil)
    (and (wcp-lit-actions-p (car x))
         (wcp-lit-actions-listp (cdr x))))
  ///
  (defopen wcp-lit-actions-listp-when-consp
    (wcp-lit-actions-listp x)
    :hyp (consp x)
    :hint (:expand ((wcp-lit-actions-listp x)))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))


;; (std::defaggregate witness-cp-hints
;;   ((generalizep)
;;    (witness-rules wcp-witness-rulesp)
;;    (example-templates wcp-templatesp)
;;    (instance-rules wcp-instance-rulesp)
;;    (examples (wcp-example-alist-listp instance-rules examples))))



;;========================================================================
;; WCP-MATCH-IMPLICATION
;;========================================================================
;; Checks that the theorem justifying a witness/instance rule is OK and
;; therefore it's sound to apply the rule.

(define wcp-match-implication ((hyp pseudo-termp)
                               (concl pseudo-termp)
                               (thmname symbolp)
                               state)
  (b* ((formula (meta-extract-formula thmname state)))
    (and (consp formula)
         (true-listp formula)
         (eq (car formula) 'implies)
         (equal (cadr formula) hyp)
         (equal (caddr formula) concl)))
  ///
  (defthmd wcp-match-implication-implies
    (implies (and (wcp-match-implication hyp concl thmname st)
                  (witness-ev-meta-extract-global-facts)
                  (equal (w st) (w state))
                  (pseudo-termp hyp)
                  (pseudo-termp concl)
                  (witness-ev hyp a))
             (witness-ev concl a))
    :hints (("goal" :use ((:instance witness-ev-meta-extract-formula
                           (name thmname)))
             :in-theory (disable witness-ev-meta-extract-formula))))

  (defthmd wcp-match-implication-implies-inv
    (implies (and (wcp-match-implication hyp concl thmname st)
                  (witness-ev-meta-extract-global-facts)
                  (equal (w st) (w state))
                  (pseudo-termp hyp)
                  (pseudo-termp concl)
                  (not (witness-ev concl a)))
             (not (witness-ev hyp a)))
    :hints (("goal" :use ((:instance witness-ev-meta-extract-formula
                           (name thmname)))
             :in-theory (disable witness-ev-meta-extract-formula)))))




;;========================================================================
;; WCP-LIT-APPLY-WITNESSES
;;========================================================================
;; (phase 1)




(define witness-generalize-alist ((generalize-map alistp)
                                  (alist alistp))
  :guard (pseudo-term-listp
          (strip-cars generalize-map))
  (pairlis$ (substitute-into-list (strip-cars generalize-map) alist)
            (strip-cdrs generalize-map))
  ///
  (defthm alistp-witness-generalize-alist
    (alistp (witness-generalize-alist generalize-map alist))
    :hints(("Goal" :in-theory (enable alistp))))

  (defthm symbol-listp-cdrs-witness-generalize-alist
    (implies (symbol-listp (strip-cdrs generalize-map))
             (symbol-listp
              (strip-cdrs (witness-generalize-alist generalize-map alist)))))

  (defthm pseudo-term-listp-cars-of-witness-generalize-alist
    (implies (and (pseudo-term-listp (strip-cars generalize-map))
                  (pseudo-term-val-alistp alist))
             (pseudo-term-listp (strip-cars (witness-generalize-alist
                                             generalize-map alist))))
    :hints(("Goal" :in-theory (enable pseudo-term-listp)))))


(define wcp-lit-apply-witness ((lit pseudo-termp)
                               (rule wcp-witness-rule-p)
                               state)
  :returns (mv (new-lit pseudo-term-listp :hints(("Goal" :in-theory (enable pseudo-term-listp))))
               (genmap (and (alistp genmap)
                            (pseudo-term-listp (strip-cars genmap))
                            (symbol-listp (strip-cdrs genmap)))))
  (b* (((wcp-witness-rule rule) rule)
       ((when (not (mbt (and (wcp-witness-rule-p rule)
                             (pseudo-termp lit)))))
        (mv nil nil))
       ((mv unify-ok alist)
        (simple-one-way-unify rule.term lit nil))
       ((when (not unify-ok))
        (raise "Witness rule ~x0 can't be applied to literal ~x1~%" rule.name lit)
        (mv nil nil))
       ((unless (wcp-match-implication rule.expr rule.term rule.theorem state))
        (raise "In witness rule ~x0, the theorem name ~x1 did not have the correct form!"
               rule.name rule.theorem)
        (mv nil nil))
       (- (and (boundp-global :witness-cp-debug state)
               (@ :witness-cp-debug)
               (cw "Applying witness rule ~x0 to literal ~x1~%" rule.name lit)))
       (genmap (witness-generalize-alist rule.generalize alist))
       (new-lit (substitute-into-term rule.expr alist)))
    (mv (list new-lit) genmap))
  ///
  (defthm wcp-lit-apply-witness-correct
    (b* (((mv newlits ?gen) (wcp-lit-apply-witness lit rule st)))
      (implies (and (not (witness-ev lit a)) ;; (not (subsetp-equal a b))
                    (witness-ev-meta-extract-global-facts)
                    (equal (w st) (w state)))
               (not (witness-ev (disjoin newlits) a))))
    :hints (("goal" 
             :do-not-induct t
             :in-theory (e/d (wcp-match-implication-implies)
                             (pseudo-termp assoc-equal substitute-into-term
                                           pseudo-term-listp
                                           simple-one-way-unify simple-term-vars
                                           nth))))
    :otf-flg t))

;; Lit is a member of the clause.  wcp-witness-rules is a list of tuples
;; conaining:
;; name: name of the witness rule
;; term: predicate term to match against
;; expr: expression implied by the predicate.
;; restriction: term in terms of the free vars of the predicate which
;;    will be evaluated with those variables bound to their matching
;;    terms; the witnessing will not be done if this evaluates to NIL
;; hint: hint to use to prove the resulting obligation.
;; generalize-exprs:  alist mapping subterms of EXPR to symbols; these
;;    will be generalized away to similar symbols.

;; Returns:
;; list of witnessing terms
;; alist (term . symbol) for generalization
;; list of proof obligations.

;; Example: lit is (subsetp-equal a b), i.e. hyp is
;; (not (subsetp-equal a b))
;; new hyp is:
;; (and (member-equal (car (set-difference-equal a b)) a)
;;      (not (member-equal (car (set-difference-equal a b)) b)))
;; therefore new-lits contains:
;; (not (and (member-equal (car (set-difference-equal a b)) a)
;;           (not (member-equal (car (set-difference-equal a b)) b))))
;; proof oblig is:
;; (implies (not (subsetp-equal a b))
;;          (and (member-equal (car (set-difference-equal a b)) a)
;;               (not (member-equal (car (set-difference-equal a b)) b))))

(define wcp-lit-apply-witnesses ((lit pseudo-termp)
                                 (rules wcp-witness-rulesp)
                                 state)
  :returns (mv (newlits pseudo-term-listp
                        :hints(("Goal" :in-theory (enable pseudo-term-listp pseudo-termp))))
               (genmap (and (alistp genmap)
                            (symbol-listp (strip-cdrs genmap))
                            (pseudo-term-listp (strip-cars genmap)))))
  (b* (((when (atom rules))
        (mv nil nil))
       ((mv newlit1 genal1)
        (wcp-lit-apply-witness lit (car rules) state))
       ((mv newlits genalist)
        (wcp-lit-apply-witnesses lit (cdr rules) state)))
    (mv (append newlit1 newlits)
        (append genal1 genalist)))
  ///
  (defthm wcp-lit-apply-witnesses-correct
    (b* (((mv newlits ?genmap) (wcp-lit-apply-witnesses lit rules st)))
      (implies (and (not (witness-ev lit a)) ;; (not (subsetp-equal a b))
                    (witness-ev-meta-extract-global-facts)
                    (equal (w st) (w state)))
               (not (witness-ev (disjoin newlits) a))))
    :hints (("goal" :induct t))
    :otf-flg t))



;;========================================================================
;; WCP-LIT-APPLY-EXAMPLES
;;========================================================================

(local (defthm pseudo-term-val-alistp-append
         (implies (and (pseudo-term-val-alistp a)
                       (pseudo-term-val-alistp b))
                  (pseudo-term-val-alistp (append a b)))))

(local
 (defsection witness-ev-alist-lemmas
   (defthm-simple-term-vars-flag
     (defthm witness-ev-remove-non-var
       (implies (and (pseudo-termp term)
                     (not (member-equal var (simple-term-vars term))))
                (equal (witness-ev term (cons (cons var val) a))
                       (witness-ev term a)))
       :flag simple-term-vars)
     (defthm witness-ev-lst-remove-non-var
       (implies (and (pseudo-term-listp term)
                     (not (member-equal var (simple-term-vars-lst term))))
                (equal (witness-ev-lst term (cons (cons var val) a))
                       (witness-ev-lst term a)))
       :flag simple-term-vars-lst)
     :hints (("goal" :induct (simple-term-vars-flag flag term)
              :in-theory (enable pseudo-termp pseudo-term-listp))
             (and stable-under-simplificationp
                  '(:in-theory (enable witness-ev-of-fncall-args)))))

   (defthm witness-ev-remove-non-vars
     (implies (and (pseudo-termp term)
                   (not (intersectp-equal vars (simple-term-vars term))))
              (equal (witness-ev term (append (pairlis$ vars vals) a))
                     (witness-ev term a))))

   (defthm witness-ev-alist-append
     (equal (witness-ev-alist (append al1 al2) a)
            (append (witness-ev-alist al1 a)
                    (witness-ev-alist al2 a))))

   (defthm witness-ev-alist-of-pairlis$
     (equal (witness-ev-alist (pairlis$ keys vals) a)
            (pairlis$ keys (witness-ev-lst vals a))))))


(define wcp-lit-apply-example ((lit pseudo-termp)
                               (example wcp-example-app-p)
                               state)
  :returns (new-lit? pseudo-term-listp :hints(("Goal" :in-theory (enable pseudo-term-listp))))
  (b* (((unless (mbt (and (wcp-example-app-p example)
                          (pseudo-termp lit))))
        nil)
       ((wcp-example-app ex) example)
       ((wcp-instance-rule inst) ex.instrule)
       ((mv unify-ok alist)
        (simple-one-way-unify inst.pred lit nil))
       ((when (not unify-ok))
        (raise "Couldn't apply instance rule ~x0 to literal ~x1~%" inst.name lit))
       ((unless (wcp-match-implication inst.expr inst.pred inst.theorem state))
        (raise "In instancing rule ~x0, the theorem name ~x1 did not have the correct form!"
               inst.name inst.theorem))
       (full-alist (append (pairlis$ inst.vars ex.bindings) alist))
       (new-lit (substitute-into-term inst.expr full-alist)))
    (list new-lit))
  ///
  (defthm wcp-lit-apply-example-correct
    (b* ((new-lits (wcp-lit-apply-example lit example st)))
      (implies (and (not (witness-ev lit a))
                    (witness-ev-meta-extract-global-facts)
                    (equal (w st) (w state)))
               (not (witness-ev (disjoin new-lits) a))))
    :hints(("Goal" :in-theory (enable wcp-match-implication-implies-inv)))))



(define wcp-lit-apply-examples ((lit pseudo-termp)
                                (examples wcp-example-appsp)
                                state)
  :returns (new-lits pseudo-term-listp :hints(("Goal" :in-theory (enable pseudo-term-listp))))
  (if (atom examples)
      nil
    (append (wcp-lit-apply-example lit (car examples) state)
            (wcp-lit-apply-examples lit (cdr examples) state)))
  ///
  (defthm wcp-lit-apply-examples-correct
    (b* ((new-lits (wcp-lit-apply-examples lit example st)))
      (implies (and (not (witness-ev lit a))
                    (witness-ev-meta-extract-global-facts)
                    (equal (w st) (w state)))
               (not (witness-ev (disjoin new-lits) a))))))


;;========================================================================
;; WCP-LIT-APPLY-ACTIONS
;;========================================================================

(define wcp-lit-apply-actions ((lit pseudo-termp)
                               (actions wcp-lit-actions-p)
                               state)
  :returns (mv (newlits pseudo-term-listp)
               (genmap (and (alistp genmap)
                            (symbol-listp (strip-cdrs genmap))
                            (pseudo-term-listp (strip-cars genmap)))))
  (b* (((mv wlits gen-alist)
        (wcp-lit-apply-witnesses
         lit (wcp-lit-actions->witnesses actions) state))
       (elits
        (wcp-lit-apply-examples
         lit (wcp-lit-actions->examples actions) state)))
    (mv (append wlits elits) gen-alist))
  ///
  (defthm wcp-lit-apply-actions-correct
    (b* (((mv new-lits ?genalist) (wcp-lit-apply-actions lit actions st)))
      (implies (and (not (witness-ev lit a))
                    (witness-ev-meta-extract-global-facts)
                    (equal (w st) (w state)))
               (not (witness-ev (disjoin new-lits) a))))))

(define wcp-clause-apply-actions ((clause pseudo-term-listp)
                                  (actions wcp-lit-actions-listp)
                                  state)
  :guard (equal (len clause) (len actions))
  :guard-hints (("goal" :in-theory (enable pseudo-term-listp
                                           pseudo-termp)))
  :returns (mv (new-clause pseudo-term-listp :hyp (pseudo-term-listp clause)
                           :hints(("Goal" :in-theory (enable pseudo-term-listp
                                                             pseudo-termp))))
               (genmap (and (alistp genmap)
                            (symbol-listp (strip-cdrs genmap))
                            (pseudo-term-listp (strip-cars genmap)))))
  (b* (((when (atom clause)) (mv nil nil))
       ((mv first-newlits first-genalist)
        (wcp-lit-apply-actions (car clause) (car actions) state))
       ((mv rest-newclause rest-genalist)
        (wcp-clause-apply-actions (cdr clause) (cdr actions) state))
       (lit (if first-newlits `(hide ,(car clause)) (car clause))))
    (mv (cons lit (append first-newlits rest-newclause))
        (append first-genalist rest-genalist)))
  ///
  (defthm wcp-clause-apply-actions-correct
    (b* (((mv new-clause ?genalist) (wcp-clause-apply-actions clause actions st)))
      (implies (and (not (witness-ev (disjoin clause) a))
                    (witness-ev-meta-extract-global-facts)
                    (equal (w st) (w state)))
               (not (witness-ev (disjoin new-clause) a))))
    :hints (("goal" :expand ((:free (x) (hide x)))))))


;;========================================================================
;; WCP-GENERALIZE
;;========================================================================
;; (step 4)

(defun witness-ev-replace-alist-to-bindings (alist bindings)
  (if (atom alist)
      nil
    (cons (cons (cdar alist) (witness-ev (caar alist) bindings))
          (witness-ev-replace-alist-to-bindings (cdr alist) bindings))))

(def-functional-instance
  witness-ev-disjoin-replace-subterms-list
  disjoin-replace-subterms-list
  ((replace-alist-to-bindings witness-ev-replace-alist-to-bindings)
   (gen-eval witness-ev)
   (gen-eval-lst witness-ev-lst))
  :hints((and stable-under-simplificationp
              '(:in-theory (enable witness-ev-of-fncall-args)))))


(define make-non-dup-vars ((x symbol-listp)
                           (avoid true-listp))
  :returns (vars symbol-listp)
  (if (atom x)
      nil
    (let ((newvar (make-n-vars 1 (if (mbt (symbolp (car x)))
                                     (car x)
                                   'x) 0 avoid)))
      (append newvar
              (make-non-dup-vars (cdr x) (append newvar avoid)))))
  ///

  (defthm make-non-dup-vars-not-nil
    (not (member-equal nil (make-non-dup-vars x avoid))))

  (defthm len-make-non-dup-vars
    (equal (len (make-non-dup-vars x avoid))
           (len x)))

  (defthm no-intersect-make-non-dup-vars
    (not (intersectp-equal avoid (make-non-dup-vars x avoid)))
    :hints (("goal" :induct (make-non-dup-vars x avoid))
            (and stable-under-simplificationp
                 '(:use ((:instance make-n-vars-not-in-avoid
                          (n 1)
                          (base (if (symbolp (car x)) (car x) 'x)) (m 0)
                          (avoid-lst avoid)))
                   :in-theory (disable
                               make-n-vars-not-in-avoid)))))

  (defthm no-duplicates-make-non-dup-vars
    (no-duplicatesp-equal (make-non-dup-vars x avoid))
    :hints (("goal" :induct t)
            (and stable-under-simplificationp
                 '(:use
                   ((:instance no-intersect-make-non-dup-vars
                     (x (cdr x))
                     (avoid (append
                             (make-n-vars
                              1 (if (symbolp (car x)) (car x)
                                  'x)
                              0 avoid)
                             avoid))))
                   :in-theory (disable
                               no-intersect-make-non-dup-vars))))))

(local
 (defthm alistp-pairlis$
   (alistp (pairlis$ a b))
   :hints(("Goal" :in-theory (enable alistp)))))


(define wcp-fix-generalize-alist ((alist (and (alistp alist)
                                          (symbol-listp (strip-cdrs alist))))
                              (used-vars true-listp))
  :returns (genalist (and (alistp genalist)
                          (not (intersectp-equal used-vars
                                                 (strip-cdrs genalist)))
                          (symbol-listp (strip-cdrs genalist))
                          (not (member-equal nil (strip-cdrs genalist)))
                          (no-duplicatesp-equal (strip-cdrs genalist)))
                     :hints(("Goal" :in-theory (enable alistp))))
  (pairlis$ (strip-cars alist)
            (make-non-dup-vars (strip-cdrs alist) used-vars)))



(define wcp-generalize-clause ((genalist (and (alistp genalist)
                                              (symbol-listp (strip-cdrs genalist))))
                               (clause pseudo-term-listp))
  :prepwork ((local (defthm true-listp-make-non-dup-vars
                      (equal (true-listp (make-non-dup-vars x avoid)) t)))

             (local (defthm pseudo-term-listp-when-symbol-listp
                      (implies (symbol-listp x)
                               (pseudo-term-listp x))
                      :hints (("goal" :induct (len x)
                               :in-theory (enable symbol-listp
                                                  pseudo-term-listp
                                                  pseudo-termp))))))
  :returns (newclause pseudo-term-listp
                      :hyp (and (pseudo-term-listp clause)
                                (alistp genalist)
                                (symbol-listp (strip-cdrs genalist))))
  (replace-subterms-list
   clause (wcp-fix-generalize-alist genalist
                                    (term-vars-list clause)))
  ///
  

  (defthm wcp-generalize-clause-correct
    (implies (and (bind-free '((a . a)) (a))
                  (not (witness-ev (disjoin clause) a))
                  (pseudo-term-listp clause))
             (not (witness-ev-theoremp
                   (disjoin (wcp-generalize-clause
                             genalist clause)))))
    :hints (("goal" :in-theory (e/d ()
                                    (replace-subterms-list
                                     wcp-fix-generalize-alist
                                     term-vars-list))
             :use ((:instance witness-ev-falsify
                    (x (disjoin
                        (wcp-generalize-clause
                         genalist clause)))
                    (a (append
                        (witness-ev-replace-alist-to-bindings
                         (wcp-fix-generalize-alist
                          genalist (term-vars-list clause))
                         a)
                        a))))))))




;;========================================================================
;; WITNESS-CP
;;========================================================================

(define witness-cp ((clause pseudo-term-listp)
                    hint state)
  :returns (mv err
               (new-clause pseudo-term-list-listp
                           :hyp (pseudo-term-listp clause)
                           :hints(("Goal" :in-theory (enable pseudo-term-list-listp)))))
  (b* (((unless (and (wcp-lit-actions-listp hint)
                     (eql (len hint) (len clause))))
        (raise "The hint to witness-cp must be a list of ~x0 objects of the ~
                same length as the clause, which the following hint is not: ~
                ~x1" 'wcp-lit-actions-p hint)
        (mv nil (list clause)))
       ((mv new-clause1 gen-alist)
        (wcp-clause-apply-actions clause hint state)))
    (mv nil (list (wcp-generalize-clause gen-alist new-clause1))))
  ///
  (defthm witness-cp-correct
    (implies (and (pseudo-term-listp clause)
                  (alistp a)
                  (witness-ev-meta-extract-global-facts)
                  (witness-ev (conjoin-clauses
                               (clauses-result
                                (witness-cp clause hint state)))
                              (witness-ev-falsify
                               (conjoin-clauses
                                (clauses-result
                                 (witness-cp clause hint state))))))
             (witness-ev (disjoin clause) a))
    :hints (("goal" :use ((:instance witness-ev-falsify
                           (x (conjoin-clauses
                               (clauses-result
                                (witness-cp clause hint state))))
                           (a a)))))
    :rule-classes :clause-processor))

(defxdoc witness-cp
  
  :parents (proof-automation)
  :short "Clause processor for quantifier-based reasoning"
  :long "<p>You should not call witness-cp directly, but rather using the
WITNESS macro as a computed hint.  This documentation is an overview of the
witness-cp system.</p>

<p>WITNESS-CP is an extensible clause processor that can use various sets of
rules to do \"witnessing\" transformations.  Taking set-based reasoning as an
example, we might want to look at hypotheses of the form @('(subsetp-equal a
b)') and conclude specific examples such as @('(implies (member-equal k
a) (member-equal k b))') for various k.  We might also want to look at
hypotheses of the form @('(not (subsetp-equal c d))') and conclude
@('(and (member-equal j c) (not (member-equal j d)))') for some witness
@('j').</p>

<p>There are thus four steps to this transformation:</p>
<ol>
<li> Introduce witnesses for negative occurrences of universally-quantified
 predicates and positive occurrences of existentially-quantified ones.</li>
<li>Optionally, generalize newly introduced witness terms into fresh
 variables, for readability.</li>
<li> Find the set of examples with which to instantiate positive
 universally-quantified and negative existentially-quantified predicates.</li>
<li> Instantiate these predicates with these examples.</li>
</ol>

<p>The clause processor needs two types of information to accomplish this:</p>
<ul>
<li> what predicates are to be taken as universal/existential quantifiers and
   what they mean; i.e. how to introduce witnesses/instantiate. </li>
<li>what examples to use when doing the instantiation.</li>
</ul>

<p>The witness-introduction and instantiation may both be lossy, i.e. result
 in a formula that isn't a theorem even if the original formula is one.</p>

<p> To set up witnessing for not-subsetp-equal hypotheses:</p>

@({
 (defwitness subsetp-witnessing
   :predicate (not (subsetp-equal a b))
   :expr (and (member-equal (subsetp-equal-witness a b) a)
              (not (member-equal (subsetp-equal-witness a b) b)))
   :generalize (((subsetp-equal-witness a b) . ssew))
   :hints ('(:in-theory '(subsetp-equal-witness-correct))))
 })

<p> This means that in the witnessing phase, we search for hypotheses of the
 form (not (subsetp-equal a b)) and for each such hypothesis, we add the
 hypothesis</p>
@({
 (and (member-equal (subsetp-equal-witness a b) a)
      (not (member-equal (subsetp-equal-witness a b) b)))
 })
<p>but then generalize away the term (subsetp-equal-witness a b) to a fresh
 variable from the set SSEW0, SSEW1, ... yielding new hyps:</p>
@({
     (member-equal ssew0 a)
     (not (member-equal ssew0 b))
 })
<p> So effectively we've taken an existential assumption and introduced a fresh
 variable witnessing it.  We wrap (hide ...) around the original hyp to leave
 a trace of what we've done (otherwise it would likely be rewritten away,
 since the two hyps we've introduced imply its truth).</p>

<p> We add these new hypotheses to our main formula.  To show that this is
sound, we have the defwitness event prove the following theorem, using the
provided hints:</p>
@({
 (implies (not (subsetp-equal a b))
          (and (member-equal (subsetp-equal-witness a b) a)
               (not (member-equal (subsetp-equal-witness a b) b))))
 })

<p>To set up instantiation of subsetp-equal hypotheses:</p>

@({
 (definstantiate subsetp-equal-instancing
   :predicate (subsetp-equal a b)
   :vars (k)
   :expr (implies (member-equal k a)
                  (member-equal k b))
   :hints ('(:in-theory '(subsetp-member))))
 })

<p> This will mean that for each subsetp-equal hypothesis we find, we'll add
 hypotheses of the form (implies (member-equal k a) (member-equal k b)) for
 each of (possibly) several k.  The terms we use to instantiate k are
 determined by @(see defexample); see below.
 To show that it sound to add these hypotheses, the definstantiate event proves:</p>
@({
  (implies (subsetp-equal a b)
           (implies (member-equal k a)
                    (member-equal k b)))
 })

<p>The terms used to instantiate k above are determined by defexample rules,
 like the following:</p>
@({
  (defexample subsetp-member-template
   :pattern (member-equal k a)
   :templates (k)
   :instance-rulename subsetp-equal-instancing)
 })

<p> This means that in phase 2, we'll look through the clause for expressions
 (member-equal k a) and whenever we find one, include k in the list of
 witnesses to use for instantiating using the subsetp-equal-instance rule.
 Defexample doesn't require any proof obligation; it's just a heuristic that
 adds to the set of terms used to instantiate universal quantifiers.</p>

<p> To use the scheme we've introduced for reasoning about subsetp-equal, we can
 introduce a witness ruleset:</p>

@({
 (def-wcp-witness-ruleset subsetp-witnessing-rules
   '(subsetp-witnessing
     subsetp-equal-instancing
     subsetp-member-template))
 })

<p> Then when we want to use this reasoning strategy, we can provide a computed
 hint:</p.
@({
 :hints ((witness :ruleset subsetp-witnessing-rules))
 })

<p> This implicitly waits til the formula is stable-under-simplification and
 invokes the witness-cp clause processor, allowing it to use the
 witnessing/instancing/example rules listed.  You can also define a macro
 so that you don't have to remember this syntax:</p>

@({
 (defmacro subset-reasoning () '(witness :ruleset subsetp-witnessing-rules))
 (defthm foo
   ...
  :hints ((\"goal\" ...)
          (subset-reasoning)))
 })

<p> Documentation is available for @(see defwitness), @(see definstantiate),
and @(see defexample). Also see @(see defquantexpr), which is a shortcut for
the common pattern (as above) of doing both a defwitness and definstantiate for
a certain term, and @(see defquant), which defines a quantified function (using
@(see defun-sk)) and sets up defwitness/definstantiate rules for it.</p>")



;;========================================================================
;; Heuristics for generating the hint list.
;;========================================================================


;;========================================================================
;; witness-eval-restriction
;;========================================================================

;; This is an attachable function that may be used to implement arbitrary
;; restrictions on the application of witness rules.
;; A :restrict term may be added to witness/instance/example rules.  When
;; attempting to apply such a rule, this term is passed to
;; witness-eval-restriction along with the substitution alist.
;; Witness-eval-restriction returns (mv err okp), where ERR should be an error
;; message or NIL, and OKP says (in absence of an error) whether to apply the
;; rule or not.
(encapsulate
  (((witness-eval-restriction * * state) => (mv * *)))
  (local (defun witness-eval-restriction (term alist state)
           (declare (xargs :stobjs state)
                    (ignore term alist state))
           (mv nil t))))

(defun witness-eval-restriction-default (term alist state)
  (declare (xargs :stobjs state))
  (if (and (pseudo-termp term)
           (symbol-alistp alist))
      (magic-ev term (cons (cons 'world (w state)) alist)
                state t t)
    (mv "guards violated" nil)))

(defattach witness-eval-restriction witness-eval-restriction-default)




(define wcp-witnesses-for-lit ((lit pseudo-termp)
                               (witness-rules wcp-witness-rulesp)
                               state)
  :returns (rules wcp-witness-rulesp)
  (b* (((when (atom witness-rules))
        nil)
       (rest (wcp-witnesses-for-lit lit (cdr witness-rules) state))
       ((unless (mbt (wcp-witness-rule-p (car witness-rules)))) rest)
       ((wcp-witness-rule rule) (car witness-rules))
       ((mv unify-ok alist)
        (simple-one-way-unify rule.term lit nil))
       ((unless unify-ok) rest)
       ((mv erp val)
        (if (equal rule.restriction ''t)
            (mv nil t)
          (witness-eval-restriction rule.restriction alist state)))
       ((when erp)
        (raise
         "Evaluation of the restriction term, ~x0, produced an error: ~@1~%"
         rule.restriction erp)
        rest)
       ((when (not val)) rest))
    (cons (car witness-rules) rest)))


(define wcp-find-instance-rule ((name symbolp)
                                (inst-rules wcp-instance-rulesp))
  :returns (rule (iff (wcp-instance-rule-p rule) rule))
  (if (atom inst-rules)
      nil
    (if (and (mbt (wcp-instance-rule-p (car inst-rules)))
             (eq (wcp-instance-rule->name (car inst-rules)) name))
        (car inst-rules)
      (wcp-find-instance-rule name (cdr inst-rules)))))

(define wcp-add-example-apps ((bindings pseudo-term-listp)
                              (inst-rulenames symbol-listp)
                              (inst-rules wcp-instance-rulesp)
                              (acc wcp-example-appsp))
  :returns (apps wcp-example-appsp
                 :hyp (wcp-example-appsp acc))
  (b* (((when (atom inst-rulenames)) acc)
       (rule (wcp-find-instance-rule (car inst-rulenames) inst-rules))
       (rest (wcp-add-example-apps bindings (cdr inst-rulenames) inst-rules acc))
       ((unless (and rule
                     (mbt (pseudo-term-listp bindings))
                     (eql (len (wcp-instance-rule->vars rule))
                          (len bindings))))
        rest))
    (cons (make-wcp-example-app :instrule rule :bindings bindings)
          rest)))


(define wcp-examples-for-term ((term pseudo-termp)
                               (templates wcp-templatesp)
                               (inst-rules wcp-instance-rulesp)
                               (acc wcp-example-appsp)
                               state)
  :returns (exalist wcp-example-appsp
                    :hyp (wcp-example-appsp acc))
  (b* (((when (atom templates)) acc)
       ((unless (mbt (and (wcp-template-p (car templates))
                          (pseudo-termp term))))
        (wcp-examples-for-term term (cdr templates) inst-rules acc state))
       ((wcp-template tmpl) (car templates))
;; (nths ?exname enabledp pat templ rulenames restriction)
       ((when (not tmpl.enabledp))
        (wcp-examples-for-term term (cdr templates) inst-rules acc state))
       ((mv unify-ok alist) (simple-one-way-unify tmpl.pat term nil))
       ((when (not unify-ok))
        (wcp-examples-for-term term (cdr templates) inst-rules acc state))
       ((mv erp val)
        (if (equal tmpl.restriction ''t)
            (mv nil t)
          (witness-eval-restriction tmpl.restriction alist state)))
       ((when erp)
        (raise
         "Evaluation of the restriction term, ~x0, produced an error: ~@1~%"
         tmpl.restriction erp)
        (wcp-examples-for-term term (cdr templates) inst-rules acc state))
       ((when (not val))
        ;; Restriction not met
        (wcp-examples-for-term term (cdr templates) inst-rules acc state))
       (bindings (substitute-into-list tmpl.templ alist))
       (acc (wcp-add-example-apps bindings tmpl.rulenames inst-rules acc)))
    (wcp-examples-for-term term (cdr templates) inst-rules acc state)))

(std::defines wcp-beta-reduce
  :verify-guards nil
  (define wcp-beta-reduce-term ((x pseudo-termp))
    :returns (res pseudo-termp :hyp (pseudo-termp x)
                  :hints ('(:in-theory (enable pseudo-termp))))
    :flag term
    (b* (((when (or (atom x) (eq (car X) 'quote))) x)
         (f (car x))
         (args (wcp-beta-reduce-list (cdr x)))
         ((when (atom f)) (cons f args))
         (vars (cadr f))
         (body (wcp-beta-reduce-term (caddr f))))
      (substitute-into-term body (pairlis$ vars args))))
  (define wcp-beta-reduce-list ((x pseudo-term-listp))
    :returns (res pseudo-term-listp :hyp (pseudo-term-listp x)
                  :hints('(:in-theory (enable pseudo-term-listp))))
    :flag list
    (if (atom x)
        nil
      (cons (wcp-beta-reduce-term (car x))
            (wcp-beta-reduce-list (cdr x)))))
  ///

  (verify-guards wcp-beta-reduce-term
    :hints (("goal" :in-theory (enable pseudo-termp
                                       pseudo-term-listp)))))


(set-state-ok t)

(std::defines wcp-collect-examples
  :verify-guards nil
  (define wcp-collect-examples-term ((x pseudo-termp)
                                            (templates wcp-templatesp)
                                            (inst-rules wcp-instance-rulesp)
                                            (acc wcp-example-appsp)
                                            state)
    :returns (res wcp-example-appsp
                  :hyp (wcp-example-appsp acc))
    :flag term
    (b* (((when (atom x)) acc)
         ((when (eq (car x) 'quote)) acc)
         (acc
          (wcp-collect-examples-list (cdr x) templates inst-rules acc state))
         ;; no lambdas -- beta reduced
         )
      (wcp-examples-for-term x templates inst-rules acc state)))

  (define wcp-collect-examples-list ((x pseudo-term-listp)
                                            (templates wcp-templatesp)
                                            (inst-rules wcp-instance-rulesp)
                                            (acc wcp-example-appsp)
                                            state)
    :returns (res wcp-example-appsp
                  :hyp (wcp-example-appsp acc))
    :flag list
    (b* (((when (atom x)) acc)
         (acc
          (wcp-collect-examples-list
           (cdr x) templates inst-rules acc state)))
      (wcp-collect-examples-term
       (car x) templates inst-rules acc state)))
  ///
  (verify-guards wcp-collect-examples-term
    :hints(("Goal" :expand ((pseudo-termp x)
                            (pseudo-term-listp x))))))


(define wcp-example-apps-for-lit ((lit pseudo-termp)
                                  (examples wcp-example-appsp)
                                  state)
  :returns (apps wcp-example-appsp)
  (b* (((when (atom examples)) nil)
       (rest (wcp-example-apps-for-lit lit (cdr examples) state))
       ((when (not (mbt (wcp-example-app-p (car examples))))) rest)
       ((wcp-example-app ex) (car examples))
       ((wcp-instance-rule rule) ex.instrule)
       ((when (not rule.enabledp)) rest)
       ((mv unify-ok alist)
        (simple-one-way-unify rule.pred lit nil))
       ((when (not unify-ok)) rest)
       ((mv erp val)
        (if (equal rule.restriction ''t)
            (mv nil t)
          (witness-eval-restriction rule.restriction alist state)))
       ((when erp)
        (raise "Evaluation of the restriction term, ~x0, produced an error: ~@1~%"
               rule.restriction erp)
        rest)
       ((when (not val))
        ;; Did not conform to restriction
        rest))
    (cons (car examples) rest)))

(define wcp-lit-actions-for-lit ((lit pseudo-termp)
                                 (examples wcp-example-appsp)
                                 (witness-rules wcp-witness-rulesp)
                                 state)
  :returns (actions wcp-lit-actions-p)
  (make-wcp-lit-actions
   :witnesses (wcp-witnesses-for-lit lit witness-rules state)
   :examples (wcp-example-apps-for-lit lit examples state)))



(define wcp-actions-for-lits ((lits pseudo-term-listp)
                              (examples wcp-example-appsp)
                              (witness-rules wcp-witness-rulesp)
                              state)
  :guard-hints (("goal" :in-theory (enable pseudo-term-listp)))
  :returns (actions wcp-lit-actions-listp)
  (if (atom lits)
      nil
    (cons (wcp-lit-actions-for-lit (car lits) examples witness-rules state)
          (wcp-actions-for-lits (cdr lits) examples witness-rules state)))
  ///
  (defthm len-of-wcp-actions-for-lits
    (equal (len (wcp-actions-for-lits lits examples witness-rules state))
           (len lits))))

(define wcp-hint-for-clause ((clause pseudo-term-listp)
                             (witness-rules wcp-witness-rulesp)
                             (inst-rules wcp-instance-rulesp)
                             (templates wcp-templatesp)
                             state)
  :returns (actions wcp-lit-actions-listp)
  ;; There is a bunch of redundant work here -- we'll end up computing the
  ;; witness rule unifications for successful rule applications a total of 4
  ;; times apiece, three here and one in witness-cp.  Well... optimizations are
  ;; possible, but this is pretty nice and clean.
  (b* ((witness-only-actions (wcp-actions-for-lits clause nil witness-rules state))
       ((mv witness-extended-clause ?gen-alist)
        (wcp-clause-apply-actions clause witness-only-actions state))
       (examples (wcp-collect-examples-list
                  (wcp-beta-reduce-list witness-extended-clause)
                  templates inst-rules nil state)))
    (wcp-actions-for-lits clause examples witness-rules state))
  ///
  (defthm len-of-wcp-hint-for-clause
    (equal (len (wcp-hint-for-clause clause witness-rules inst-rules templates state))
           (len clause))))




;;========================================================================
;; Defwitness/definstantiate/defexample.
;;========================================================================



(defun wcp-translate (term ctx state)
  (declare (xargs :mode :program))
  (b* (((er term)
        (translate term t t nil ctx (w state) state))
       (term (remove-guard-holders term)))
    (value term)))

(defun wcp-translate-lst (lst ctx state)
  (declare (xargs :mode :program))
  (if (atom lst)
      (value nil)
    (b* (((er rest) (wcp-translate-lst (cdr lst) ctx state))
         ((er first)
          (wcp-translate (car lst) ctx state)))
      (value (cons first rest)))))

(defun defwitness-fn (name predicate expr restriction generalize hints
                           state)
  (declare (xargs :mode :program :stobjs state))
  (b* (((when (not predicate))
        (mv "DEFWITNESS: Must supply a :PREDICATE.~%" nil state))
       ((when (not expr))
        (mv "DEFWITNESS: Must supply an :EXPR.~%" nil state))
       ((er predicate)
        (wcp-translate predicate 'defwitness state))
       ((er expr)
        (wcp-translate expr 'defwitness state))
       ((er restriction)
        (wcp-translate restriction 'defwitness state))
       ((er generalize-terms)
        (wcp-translate-lst (strip-cars generalize) 'defwitness state))
       (generalize (pairlis$ generalize-terms (strip-cdrs generalize)))

       (thmname (intern-in-package-of-symbol
                 (concatenate 
                  'string (symbol-name name) "-WITNESS-RULE-CORRECT")
                 name))
       (obj (make-wcp-witness-rule :name name
                                   :enabledp t
                                   :term (dumb-negate-lit predicate)
                                   :expr (dumb-negate-lit expr)
                                   :restriction restriction
                                   :theorem thmname
                                   :generalize generalize))
                              
       ;;                         `((prog2$ (cw "clause: ~x0~%" clause)
       ;;                                   '(:computed-hint-replacement
       ;;                                     :do-not '(preprocess simplify)))) nil nil))
       )
    (value
     `(progn
        (defthm ,thmname
          (implies ,(dumb-negate-lit expr)
                   ,(dumb-negate-lit predicate))
          :hints ,hints
          :rule-classes nil)
        (table witness-cp-witness-rules
               ',name ',obj)))))

(defxdoc defwitness
  :parents (witness-cp)
  :short ""
  :long 
  ":doc-section witness-cp
 Defwitness -- add a WITNESS-CP rule providing a witness for an
 existential-quantifier hypothesis (or universal-quantifier conclusion).~/

 Usage example:
 (defwitness subsetp-witnessing
   :predicate (not (subsetp-equal a b))
   :expr (and (member-equal (subsetp-equal-witness a b) a)
              (not (member-equal (subsetp-equal-witness a b) b)))
   :generalize (((subsetp-equal-witness a b) . ssew)
   :hints ('(:in-theory '(subsetp-equal-witness-correct))))

 Additional arguments:
   :restriction term
 where term may have free variables that occur also in the :predicate term, and
 may also use the variable WORLD to stand for the ACL2 world.

 The above example tells WITNESS-CP how to expand a hypothesis of the form
 (not (subsetp-equal a b)) or, equivalently, a conclusion of the form
 (subsetp-equal a b), generating a fresh variable named SSEW or similar that
 represents an object that proves that A is not a subset of B (because that
 object is in A but not B.)

 See ~il[witness-cp] for background.~/

 When this rule is in place, WITNESS-CP will look for literals in the clause
 that unify with the negation of PREDICATE.  It will replace these by a term
 generated from EXPR.  It will generalize away terms that are keys in
 GENERALIZE, replacing them by fresh variables based on their corresponding
 values.  It will use HINTS to relieve the proof obligation that this
 replacement is sound (which is also done when the defwitness form is run).

 If a RESTRICTION is given, then this replacement will only take place when
 it evaluates to a non-nil value.~/")


(defmacro defwitness (name &key predicate expr
                           (restriction ''t)
                           generalize hints)
  `(make-event (defwitness-fn ',name ',predicate ',expr ',restriction
                 ',generalize ',hints state)))



(defun definstantiate-fn (name predicate vars expr restriction hints
                               state)
  (declare (xargs :mode :program :stobjs state))
  (b* (((when (not predicate))
        (mv "DEFINSTANTIATE: Must supply a :PREDICATE.~%" nil state))
       ((when (not vars))
        (mv "DEFINSTANTIATE: Must supply :VARS.~%" nil state))
       ((when (not expr))
        (mv "DEFINSTANTIATE: Must supply an :EXPR.~%" nil state))
       ((er predicate)
        (wcp-translate predicate 'definstantiate state))
       ((er expr)
        (wcp-translate expr 'definstantiate state))
       ((er restriction)
        (wcp-translate restriction 'definstantiate state))

       (thmname (intern-in-package-of-symbol
                 (concatenate 
                  'string (symbol-name name) "-INSTANCE-RULE-CORRECT")
                 name))
       (obj (make-wcp-instance-rule :name name
                                    :enabledp t
                                    :pred (dumb-negate-lit predicate)
                                    :vars vars
                                    :expr (dumb-negate-lit expr)
                                    :restriction restriction
                                    :theorem thmname)))
    (value
     `(progn
        (defthm ,thmname
          (implies ,(dumb-negate-lit expr)
                   ,(dumb-negate-lit predicate))
          :hints ,hints
          :rule-classes nil)
        (table witness-cp-instance-rules ',name ',obj)))))

(defxdoc definstantiate
  :parents (witness-cp)
  :short ""
  :long ":doc-section witness-cp
 Definstantiate -- add a WITNESS-CP rule showing how to instantiate a
 universial-quantifier hyptothesis (or an existential-quantifier conclusion).~/

 Usage example:
 (definstantiate subsetp-equal-instancing
   :predicate (subsetp-equal a b)
   :vars (k)
   :expr (implies (member-equal k a)
                  (member-equal k b))
   :hints ('(:in-theory '(subsetp-member))))

 Additional arguments:
   :restriction term
 where term may have free variables that occur also in the :predicate term or
 the list :vars, as well as WORLD, standing for the ACL2 world.

 The above example tells WITNESS-CP how to expand a hypothesis of the form
 (subsetp-equal a b) or, equivalently, a conclusion of the form
 (not (subsetp-equal a b)), introducing a term of the form EXPR for each of
 some set of K.  Which K are chosen depends on the set of existing ~il[defexample]
 rules and the user-provided examples from the call of WITNESS.

 See ~il[witness-cp] for background.~/

 In more detail, WITNESS-CP will look in the clause for literals that unify
 with the negation of PREDICATE.  It will replace these with a conjunction of
 several instantiations of EXPR, with the free variables present in VARS
 replaced by either user-provided terms or terms generated by a defexample rule.
 It will use HINTS to relieve the proof obligation that this replacement is
 sound (which is also done when the definstantiate form is run).

 If a RESTRICTION is given, then this replacement will only take place when
 it evaluates to a non-nil value.~/")

(defmacro definstantiate (name &key predicate vars expr
                               (restriction ''t) hints)
  
  `(make-event (definstantiate-fn
                 ',name ',predicate ',vars ',expr ',restriction
                 ',hints state)))


(define missing-instance-rules ((instance-rules symbol-listp)
                                (alist alistp))
  (if (atom instance-rules)
      nil
    (if (assoc (car instance-rules) alist)
        (missing-instance-rules (cdr instance-rules) alist)
      (cons (car instance-rules)
            (missing-instance-rules (cdr instance-rules) alist)))))


(defun wrong-arity-instance-rules (arity instance-rules alist)
  (declare (xargs :mode :program))
  (if (atom instance-rules)
      nil
    (if (= (len (wcp-instance-rule->vars (cdr (assoc (car instance-rules) alist)))) arity)
        (wrong-arity-instance-rules arity (cdr instance-rules) alist)
      (cons (car instance-rules)
            (wrong-arity-instance-rules arity (cdr instance-rules) alist)))))

(defun defexample-fn (name pattern templates instance-rules restriction
                           state)
  (declare (Xargs :mode :program :stobjs state))
  (b* (((when (not pattern))
        (mv "DEFEXAMPLE: Must supply a :PATTERN.~%" nil state))
       ((when (not templates))
        (mv "DEFEXAMPLE: Must supply :TEMPLATES.~%" nil state))
       ((when (not instance-rules))
        (mv "DEFEXAMPLE: Must supply an :INSTANCE-RULENAME.~%" nil state))
       (instance-rule-alist (table-alist 'witness-cp-instance-rules
                                         (w state)))
       (missing-rules (missing-instance-rules instance-rules instance-rule-alist))
       ((when missing-rules)
        (mv (msg "DEFEXAMPLE: The following instance rules do not exist: ~x0~%"
                 missing-rules)
            nil state))
       (nvars (len templates))
       (bad-rules (wrong-arity-instance-rules nvars instance-rules instance-rule-alist))
       ((when bad-rules)
        (mv (msg "DEFEXAMPLE: The following instance rules do not have the
right number of free variables (~x0): ~x1~%"
                 nvars bad-rules)
            nil state))
       ((er pattern)
        (wcp-translate pattern 'defexample state))
       ((er restriction)
        (wcp-translate restriction 'defexample state))
       ((er templates)
        (wcp-translate-lst templates 'defexample state))
       (obj (make-wcp-template :name name
                               :enabledp t
                               :pat pattern
                               :templ templates
                               :rulenames instance-rules
                               :restriction restriction)))
    (value
     `(table witness-cp-example-templates
             ',name ',obj))))

(defxdoc defexample
  :parents (witness-cp)
  :short ""
  :long 
  ":doc-section witness-cp
Defexample -- tell witness-cp how to instantiate the free variables of
definstantiate rules~/

Example:
~bv[]
 (defexample set-reasoning-member-template
   :pattern (member-equal k y)
   :templates (k)
   :instance-rules
   (subsetp-equal-instancing
    intersectp-equal-instancing
    set-equiv-instancing
    set-consp-instancing))
~ev[]

Additional arguments:
  :restriction term
 where term may have free variables present in pattern as well as WORLD,
  :instance-rulename rule
 may be used instead of :instance-rules when there is only one rule.

Meaning: Find terms of the form ~c[(member-equal k y)] throughout the clause,
and for each such ~c[k], for any match of one of the instance-rules listed, add
an instance using that ~c[k].  For example, if we have a hypothesis
~c[(subsetp-equal a b)] and terms
~bv[]
 (member-equal (foo x) (bar y))
 (member-equal q a)
~ev[]
present somewhere in the clause, then this rule along with the
subsetp-equal-instancing rule will cause the following hyps to be added:
~bv[]
 (implies (member-equal (foo x) a)
          (member-equal (bar x) a))
 (implies (member-equal q a)
          (member-equal q b)).
~ev[]

If a :restriction is present, then the rule only applies to occurrences of
pattern for which the restriction evaluates to non-nil.~/~/")

(defmacro defexample (name &key pattern templates instance-rulename
                           instance-rules
                           (restriction ''t))
  `(make-event
    (defexample-fn ',name ',pattern ',templates
      ',(if instance-rulename (list instance-rulename) instance-rules)
      ',restriction state)))
       
                                           














(defun quantexpr-bindings-to-generalize (bindings)
  (b* (((when (atom bindings)) nil)
       ((list var expr) (car bindings)))
    (cons (cons expr var)
          (quantexpr-bindings-to-generalize (cdr bindings)))))


(defun defquantexpr-fn (name predicate quantifier expr witnesses
                             instance-restriction witness-restriction
                             instance-hints witness-hints
                             wcp-witness-rulename instance-rulename
                             generalize in-package-of)
  (b* ((in-package-of (or in-package-of name))
       ((unless (member quantifier '(:forall :exists)))
        (er hard? 'defquantexpr
            "Quantifier argument must be either :FORALL or :EXISTS~%"))
       (wcp-witness-rulename
        (or wcp-witness-rulename
            (intern-in-package-of-symbol
             (concatenate 'string (symbol-name name) "-WITNESSING")
             in-package-of)))
       (instance-rulename
        (or instance-rulename
            (intern-in-package-of-symbol
             (concatenate 'string (symbol-name name) "-INSTANCING")
             in-package-of)))
       ((mv witness-pred instance-pred witness-expr instance-expr)
        (if (eq quantifier :forall)
            (mv `(not ,predicate)
                predicate
                `(let ,witnesses
                   (not ,expr))
                expr)
          (mv predicate
              `(not ,predicate)
              `(let ,witnesses ,expr)
              `(not ,expr))))
       (generalize-alist (quantexpr-bindings-to-generalize witnesses)))
    `(progn (defwitness ,wcp-witness-rulename
              :predicate ,witness-pred
              :expr ,witness-expr
              :hints ,witness-hints
              ,@(and generalize `(:generalize ,generalize-alist))
              :restriction ,witness-restriction)
            (definstantiate ,instance-rulename
              :predicate ,instance-pred
              :vars ,(strip-cars witnesses)
              :expr ,instance-expr
              :hints ,instance-hints
              :restriction ,instance-restriction))))


(defxdoc defquantexpr
  :parents (witness-cp)
  :short ""
  :long ":doc-section witness-cp
 Defquantexpr -- shortcut to perform both a DEFWITNESS and DEFINSTANTIATE~/

 Usage:
~bv[]
 (defquantexpr subsetp-equal
  :predicate (subsetp-equal x y)
  :quantifier :forall
  :witnesses ((k (subsetp-equal-witness x y)))
  :expr (implies (member-equal k x)
                 (member-equal k y))
  :witness-hints ('(:in-theory '(subsetp-equal-witness-correct)))
  :instance-hints ('(:in-theory '(subsetp-member))))
~ev[]
 This expands to a DEFWITNESS and DEFINSTANTIATE form.  The names of the
 defwitness and definstantiate rules produced are generated from the name
 (first argument) of the defquantexpr form; in this case they are
 subsetp-witnessing and subsetp-equal-instancing.  Keyword arguments
 wcp-witness-rulename and instance-rulename may be provided to override these
 defaults.

 Witness-hints and instance-hints are the hints passed to the two forms.

 Additional arguments: instance-restriction, witness-restriction, generalize.
 Instance-restriction and witness-restriction are the :restriction arguments
 passed to defwitness and definstantiate, respectively.  If :generalize is nil,
 then the defwitness rule will not do generalization; otherwise, it will use
 the keys of :witnesses as the variable names.~/

 The meaning of this form is as follows:
~bv[]
 \":predicate holds iff (:quantifier) (keys of :witnesses), :expr.\"
~ev[]

 In our example above:

~bv[]
 \"(subsetp-equal x y) iff for all k,
   (implies (member-equal k x)
            (member-equal k y)).\"
~ev[]

 An example of this with an existential quantifier:
~bv[]
 (defquantexpr intersectp-equal
  :predicate (intersectp-equal x y)
  :quantifier :exists
  :witnesses ((k (intersectp-equal-witness x y)))
  :expr (and (member-equal k x)
             (member-equal k y))
  :witness-hints ('(:in-theory '(intersectp-equal-witness-correct)))
  :instance-hints ('(:in-theory '(intersectp-equal-member))))
~ev[]

 meaning:
~bv[]
 \"(intersectp-equal x y) iff there exists k such that
      (and (member-equal k x)
           (member-equal k y))\".
~ev[]

 the values bound to each key in :witnesses should be witnesses for the
 existential quantifier in the direction of the bi-implication that involves
 (the forward direction for :exists and the backward for :forall):

 for the first example,
~bv[]
 \"(let ((k (subsetp-equal-witness x y)))
      (implies (member-equal k x)
               (member-equal k y)))
   implies
   (subsetp-equal x y).\"
~ev[]

 for the second example,
~bv[]
 \"(intersectp-equal x y)
   implies
   (let ((k (intersectp-equal-witness x y)))
     (and (member-equal k x)
          (member-equal k y))).\"
~ev[]~/

")

(defmacro defquantexpr (name &key predicate
                             (quantifier ':forall)
                             expr witnesses
                             (instance-restriction ''t)
                             (witness-restriction ''t)
                             instance-hints witness-hints
                             wcp-witness-rulename
                             instance-rulename
                             in-package-of
                             (generalize 't))
  
  (defquantexpr-fn name predicate quantifier expr witnesses
     instance-restriction witness-restriction
     instance-hints witness-hints wcp-witness-rulename instance-rulename generalize in-package-of))









(defun look-up-wcp-witness-rules (rules table)
  (if (atom rules)
      (mv nil nil)
    (b* (((mv rest missing) (look-up-wcp-witness-rules (cdr rules) table))
         (look (assoc (car rules) table)))
      (if look
          (mv (cons look rest) missing)
        (mv rest (cons (car rules) missing))))))


;; (defun def-wcp-witness-ruleset-fn (name witness-names instance-names
;;                                     example-names state)
;;   (b* (((mv wcp-witness-rules missing)
;;         (look-up-wcp-witness-rules
;;          witness-names
;;          (table-alist 'witness-cp-witness-rules (w state))))
;;        ((when missing)
;;         (mv (msg "DEF-WCP-WITNESS-RULESET: Witness ~s0 not found: ~x1~%"
;;                  (if (consp (cdr missing)) "rules" "rule")
;;                  missing)
;;             nil state))
;;        ((mv instance-rules missing)
;;         (look-up-wcp-witness-rules
;;          instance-names
;;          (table-alist 'witness-cp-instance-rules (w state))))
;;        ((when missing)
;;         (mv (msg "DEF-WCP-WITNESS-RULESET: Instance ~s0 not found: ~x1~%"
;;                  (if (consp (cdr missing)) "rules" "rule")
;;                  missing)
;;             nil state))
;;        ((mv example-templates missing)
;;         (look-up-wcp-witness-rules
;;          example-names
;;          (table-alist 'witness-cp-example-templates (w state))))
;;        ((when missing)
;;         (mv (msg "DEF-WCP-WITNESS-RULESET: Example ~s0 not found: ~x1~%"
;;                  (if (consp (cdr missing)) "templates" "template")
;;                  missing)
;;             nil state)))
;;     (value `(table witness-cp-rulesets ',name
;;                    ',(list wcp-witness-rules
;;                            example-templates
;;                            instance-rules)))))

(defxdoc def-witness-ruleset
  :parents (witness-cp)
  :short ""
  :long ":doc-section witness-cp
def-witness-ruleset: name a set of witness-cp rules~/

The WITNESS computed-hint macro takes a :ruleset argument that determines
which witness-cp rules are allowed to fire.  def-witness-ruleset allows
one name to abbreviate several actual rules in this context.

Usage:
~bv[]
 (def-witness-ruleset foo-rules
    '(foo-instancing
      foo-witnessing
      bar-example-for-foo
      baz-example-for-foo))
~ev[]

After submitting this form, the following invocations of WITNESS are
equivalent:

~bv[]
 (witness :ruleset foo-rules)
 (witness :ruleset (foo-rules))
 (witness :ruleset (foo-instancing
                    foo-witnessing
                    bar-example-for-foo
                    baz-example-for-foo))
~ev[]

 These rulesets are defined using a table event.  If multiple different
definitions are given for the same ruleset name, the latest one is always in
effect.

 Rulesets can contain other rulesets.  These are expanded at the time the
WITNESS hint is run.  A ruleset can be expanded with
~bv[]
 (witness-expand-ruleset names (w state))
~ev[]

Witness rules can also be enabled/disabled using ~il[witness-enable] and
~il[witness-disable]; these settings take effect when WITNESS is called without
specifying a ruleset.  Ruleset names may be used in witness-enable and
witness-disable just as they are used in the ruleset argument of WITNESS.
~/~/")

(defmacro def-witness-ruleset (name rules)
  
  `(table witness-cp-rulesets ',name ,rules))

;; (defun defquant-witness-binding1 (n qvars witness-expr)
;;   (if (atom qvars)
;;       nil
;;     (cons `(,(car qvars) (mv-nth ,n ,witness-expr))
;;           (defquant-witness-binding1 (1+ n) (cdr qvars) witness-expr))))

;; (defun defquant-witness-binding (qvars witness-expr body)
;;   (if (eql (len qvars) 1)
;;       `(let ((,(car qvars) ,witness-expr)) ,body)
;;     `(let ,(defquant-witness-binding1 0 qvars witness-expr)
;;        ,body)))

;; (defun defquant-generalize-alist1 (n qvars witness-expr generalize-vars)
;;   (if (atom qvars)
;;       nil
;;     (cons `((mv-nth ,n ,witness-expr)
;;             . ,(or (car generalize-vars) (car qvars)))
;;           (defquant-generalize-alist1 (1+ n) (cdr qvars)
;;             witness-expr (cdr generalize-vars)))))


;; (defun defquant-generalize-alist (qvars witness-expr generalize-vars)
;;   (if (eql (len qvars) 1)
;;       `((,witness-expr . ,(or (car generalize-vars) (car qvars))))
;;     (defquant-generalize-alist1 0 qvars witness-expr generalize-vars)))

(defun defquant-witnesses-mv (n vars witness-call)
  (if (atom vars)
      nil
    (cons `(,(car vars) (mv-nth ,n ,witness-call))
          (defquant-witnesses-mv (1+ n) (cdr vars) witness-call))))

(defun defquant-witnesses (vars witness-call)
  (cond ((atom vars) nil) ;; ?
        ((atom (cdr vars))
         `((,(car vars) ,witness-call)))
        (t (defquant-witnesses-mv 0 vars witness-call))))


(defun defquant-fn (name vars quant-expr define
                         wcp-witness-rulename
                         instance-rulename
                         doc
                         quant-ok
                         skolem-name
                         thm-name
                         rewrite
                         strengthen
                         witness-dcls
                         in-package-of)
  (b* ((in-package-of (or in-package-of name))
       (qcall (cons name vars))
       ((when (not (and (eql (len quant-expr) 3)
                        (member-equal (symbol-name (car quant-expr))
                                     '("FORALL" "EXISTS"))
                        (or (symbolp (cadr quant-expr))
                            (symbol-listp (cadr quant-expr))))))
        (er hard? 'defquant "Malformed quantifier expression: ~x0~%"
            quant-expr))
       (exists-p (equal (symbol-name (car quant-expr)) "EXISTS"))
       (qvars (nth 1 quant-expr))
       (qvars (if (atom qvars) (list qvars) qvars))
       (qexpr (nth 2 quant-expr))
       ;; these need to be chosen the same way as in defun-sk
       (skolem-name (or skolem-name
                        (intern-in-package-of-symbol
                         (concatenate 'string (symbol-name name)
                                      "-WITNESS")
                         in-package-of)))
       (witness-expr (cons skolem-name vars))
       (thm-name (or thm-name
                     (intern-in-package-of-symbol
                      (concatenate 'string (symbol-name name)
                                   (if exists-p
                                       "-SUFF" "-NECC"))
                      in-package-of))))

  `(progn
     ,@(and define `((defun-sk ,name ,vars ,quant-expr
                       :doc ,doc
                       :quant-ok ,quant-ok
                       :skolem-name ,skolem-name
                       :thm-name ,thm-name
                       :rewrite ,rewrite
                       :strengthen ,strengthen
                       :witness-dcls ,witness-dcls)))
     (defquantexpr ,name
       :predicate ,qcall
       :quantifier ,(if exists-p :exists :forall)
       :witnesses ,(defquant-witnesses qvars witness-expr)
       :expr ,qexpr
       :witness-hints ('(:in-theory '(,name)))
       :instance-hints ('(:in-theory nil :use ,thm-name))
       :wcp-witness-rulename ,wcp-witness-rulename
       :instance-rulename ,instance-rulename)
     (in-theory (disable ,name ,thm-name)))))

(defxdoc defquant
  :parents (witness-cp)
  :short ""
  :long ":doc-section witness-cp
Defquant -- define a quantified function and corresponding witness-cp rules~/

Defquant introduces a quantified function using ~il[defun-sk] and subsequently
adds appropriate defwitness and definstantiate rules for that function.  Note
that no defexample rules are provided (we judge these too hard to get right
automatically).

Usage: Defquant takes the same arguments as ~il[defun-sk], plus the following
additional keywords:

  :define -- default t, use nil to skip the defun-sk step (useful if it
       has already been done)

  :wcp-witness-rulename, :instance-rulename --
     name the generated witness and instance rules.  The defaults are
     name-witnessing and name-instancing.~/~/")


(defmacro defquant (name vars quant-expr &key
                         (define 't)
                         wcp-witness-rulename
                         instance-rulename
                         ;; defun-sk args
                         doc
                         quant-ok
                         skolem-name
                         thm-name
                         rewrite
                         strengthen
                         in-package-of
                         (witness-dcls '((DECLARE (XARGS :NON-EXECUTABLE T)))))
  

  (defquant-fn name vars quant-expr define wcp-witness-rulename instance-rulename
    doc
    quant-ok
    skolem-name
    thm-name
    rewrite
    strengthen
    witness-dcls
    in-package-of))


(defun wcp-witness-rule-e/d-event (rulename tablename enablep world)
  (b* ((al (table-alist tablename world))
       (look (assoc rulename al)))
    (and look
         `((table ,tablename
                  ',rulename ',(update-nth 0 enablep (cdr look)))))))

(defun union-assoc (a b)
  (cond ((atom a) b)
        ((assoc (caar a) b)
         (union-assoc (cdr a) b))
        (t (cons (car a) (union-assoc (cdr a) b)))))

(defun remove-dups-assoc (a)
  (cond ((atom a) nil)
        ((assoc (caar a) (cdr a))
         (remove-dups-assoc (cdr a)))
        (t (cons (car a) (remove-dups-assoc (cdr a))))))

(defun instance-rules-for-examples (example-templates)
  (if (atom example-templates)
      nil
    (append (wcp-template->rulenames (car example-templates))
            (instance-rules-for-examples (cdr example-templates)))))


(mutual-recursion
 (defun witness-expand-ruleset (names world)
   (declare (xargs :mode :program))
   ;; Union together the rules mentioned as well as the rules within the
   ;; rulesets.
   (b* (((mv wcp-witness-rules instance-rules example-templates rest)
         (witness-expand-ruleset-names names world))
        ((mv wcp-witness-rules1 &)
         (look-up-wcp-witness-rules rest (table-alist 'witness-cp-witness-rules world)))
        ((mv example-templates1 &)
         (look-up-wcp-witness-rules rest (table-alist 'witness-cp-example-templates
                                                  world)))
        (example-templates1 (remove-dups-assoc example-templates1))
        ((mv instance-rules1 &)
         (look-up-wcp-witness-rules (instance-rules-for-examples example-templates1)
                                (table-alist 'witness-cp-instance-rules
                                             world)))
        ((mv instance-rules2 &)
         (look-up-wcp-witness-rules rest (table-alist 'witness-cp-instance-rules
                                                  world))))
     (mv (union-assoc (remove-dups-assoc wcp-witness-rules1) wcp-witness-rules)
         (union-assoc (remove-dups-assoc instance-rules1)
                      (union-assoc (remove-dups-assoc instance-rules2)
                                   instance-rules))
         (union-assoc example-templates1 example-templates))))

 (defun witness-expand-ruleset-names (names world)
   (if (atom names)
       (mv nil nil nil nil)
     (b* (((mv wcp-witness-rules instance-rules example-templates rest)
           (witness-expand-ruleset-names (cdr names) world))
          (ruleset-look
           (assoc (car names)
                  (table-alist 'witness-cp-rulesets world)))
          ((when (not ruleset-look))
           (mv wcp-witness-rules instance-rules example-templates
               (cons (car names) rest)))
          ((mv wcp-witness-rules1 instance-rules1 example-templates1)
           (witness-expand-ruleset (cdr ruleset-look) world)))
       (mv (union-assoc wcp-witness-rules1 wcp-witness-rules)
           (union-assoc instance-rules1 instance-rules)
           (union-assoc example-templates1 example-templates)
           rest)))))

(defun witness-e/d-events (names tablename enablep world)
  (if (atom names)
      nil
    (append (wcp-witness-rule-e/d-event (car names) tablename enablep world)
            (witness-e/d-events (cdr names) tablename enablep world))))

(defun witness-e/d-ruleset-fn (names enablep world)
  (declare (xargs :mode :program))
  (b* ((names (if (atom names) (list names) names))
       ((mv w i e) (witness-expand-ruleset names world)))
    `(with-output :off :all :on error
       (progn
         ,@(witness-e/d-events (strip-cars w) 'witness-cp-witness-rules enablep world)
         ,@(witness-e/d-events (strip-cars i) 'witness-cp-instance-rules enablep world)
         . ,(witness-e/d-events (strip-cars e) 'witness-cp-example-templates enablep world)))))




(defmacro witness-enable (&rest names)
  `(make-event (witness-e/d-ruleset-fn ',names t (w state))))

(defmacro witness-disable (&rest names)
  `(make-event (witness-e/d-ruleset-fn ',names nil (w state))))



(defxdoc witness
  :parents (witness-cp)
  :short "Computed hint for calling the witness clause processor"
  :long ":doc-section witness-cp
Witness -- computed-hint that runs witness-cp~/

Usage:
~bv[]
 (witness :ruleset (rule ruleset ...)
          :examples
           ((inst-rulename1 term1 term2 ...)
            (inst-rulename2 term3 ...) ...)
          :generalize t)
~ev[]

 Calls the clause processor WITNESS-CP.  If a ruleset is provided, only those
witness-cp rules will be available; otherwise, all rules that are currently
enabled (~l[witness-enable], ~il[witness-disable]) are used.

The :generalize argument is T by default; if set to NIL, the generalization
step is skipped (~l[witness-cp]).

The :examples argument is empty by default.  Usually, examples are generated by
defexample rules.  However, in some cases the user might like to instantiate
universally-quantified hyps in a particular way on a one-off basis; this may be
done using the :examples field.  Each inst-rulename must be the name of a
definstantiate rule, and the terms following it correspond to that rule's :vars
 (in partiular, the list of terms must be the same length as the :vars of the
rule).~/~/")


(defmacro witness (&key ruleset)
  `(and stable-under-simplificationp
        (b* ((ruleset ',ruleset)
             ((mv w i e)
              (if ruleset
                  (witness-expand-ruleset
                   (if (atom ruleset) (list ruleset) ruleset)
                   world)
                (mv (table-alist 'witness-cp-witness-rules world)
                    (table-alist 'witness-cp-instance-rules
                                 world)
                    (table-alist 'witness-cp-example-templates
                                 world))))
             (hint (wcp-hint-for-clause
                    clause
                    (strip-cdrs w)
                    (strip-cdrs i)
                    (strip-cdrs e) state)))
          `(:clause-processor
            (witness-cp clause ',hint state)))))




