; ESIM Symbolic Hardware Simulator
; Copyright (C) 2010-2012 Centaur Technology
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


; stv-decomp-proofs.lisp -- lemmas for proofs about decomposition of STVs
;
; Original authors: Sol Swords <sswords@centtech.com>
;                  Jared Davis <jared@centtech.com>

(in-package "ACL2")

(include-book "stv-run")
(include-book "centaur/bitops/ihsext-basics" :dir :system)
(local (include-book "arithmetic/top-with-meta" :dir :system))
(include-book "centaur/misc/outer-local" :dir :system)


(local (in-theory (disable vl::consp-of-car-when-cons-listp
                           sets::double-containment
                           vl::cons-listp-of-cdr-when-cons-listp
                           4v-sexpr-eval)))

(defthmd lookup-each-of-4v-sexpr-eval-alist
  (implies (hons-subset keys (alist-keys sexpr-alist))
           (equal (vl::look-up-each keys (4v-sexpr-eval-alist sexpr-alist env))
                  (4v-sexpr-eval-list (vl::look-up-each keys sexpr-alist) env)))
  :hints(("Goal" :in-theory (e/d (vl::look-up-each-fast
                                  vl::look-up-each
                                  4v-sexpr-eval-list)
                                 (4v-sexpr-eval)))))

(defthmd assoc-of-stv-assemble-output-alist
  (implies (alistp out-usersyms)
           (equal (assoc k (stv-assemble-output-alist sexpr-alist out-usersyms))
                  (let ((look (assoc k out-usersyms)))
                    (and look
                         (cons k (4v-to-nat (vl::look-up-each (cdr look) sexpr-alist)))))))
  :hints(("Goal" :in-theory (enable stv-assemble-output-alist
                                    hons-assoc-equal))))

(defthmd revappend-open
  (equal (revappend (cons a b) c)
         (revappend b (cons a c))))

(defthm revappend-nil
  (equal (revappend nil b) b))

(defthmd stv-simvar-inputs-to-bits-open
  (equal (stv-simvar-inputs-to-bits (cons (cons name val) alist) in-usersyms)
         (b* ((rest (stv-simvar-inputs-to-bits alist in-usersyms))
              (in-usersyms (make-fast-alist in-usersyms))
              (LOOK (HONS-GET NAME IN-USERSYMS))
              ((UNLESS LOOK)
               REST)
              (VARS (CDR LOOK))
              (NVARS (LEN VARS))
              (VALS
               (COND
                ((EQ VAL *4VX*) (REPLICATE NVARS *4VX*))
                ((AND (NATP VAL) (< VAL (ASH 1 NVARS)))
                 (BOOL-TO-4V-LST (INT-TO-V VAL NVARS)))
                (T (REPLICATE NVARS *4VX*)))))
           (SAFE-PAIRLIS-ONTO-ACC VARS VALS REST)))
  :hints(("Goal" :in-theory (enable stv-simvar-inputs-to-bits))))

(defthm stv-simvar-inputs-to-bits-nil
  (equal (stv-simvar-inputs-to-bits nil in-usersyms)
         nil)
  :hints(("Goal" :in-theory (enable stv-simvar-inputs-to-bits))))

(encapsulate nil
  (local (defthm +-consts
           (implies (syntaxp (and (quotep a) (quotep b)))
                    (equal (+ a b c)
                           (+ (+ a b) c)))))

  (local
   (defun v-to-nat-ind (x n)
     (if (atom x)
         n
       (v-to-nat-ind (cdr x) (logcdr n)))))

  ;; (local (defthm +-1-of-logcons
  ;;          (equal (+ 1 (logcons 0 n))
  ;;                 (logcons 1 n))
  ;;          :hints(("Goal" :in-theory (enable logcons)))))

  ;; (local (defthm *-2-to-logcons
  ;;          (implies (integerp n)
  ;;                   (equal (* 2 n)
  ;;                          (logcons 0 n)))
  ;;          :hints(("Goal" :in-theory (enable logcons)))))

  (defthmd v-to-nat-bound
    (implies (and (syntaxp (quotep n))
                  (integerp n)
                  (<= (ash 1 (len x)) n))
             (< (v-to-nat x) n))
    :hints(("Goal" :in-theory (enable ash** len logcons)
            :induct (v-to-nat-ind x n)
            :expand ((:free (x) (ash 1 (+ 1 x))))))
    :rule-classes :rewrite))

(defthm len-of-4v-sexpr-eval-list
  (equal (len (4v-sexpr-eval-list x env))
         (len x))
  :hints(("Goal" :in-theory (enable 4v-sexpr-eval-list))))


             
           
             
             
(defthm bool-to-4v-lst-of-bool-from-4v-lst-when-4v-bool-listp
  (implies (4v-bool-listp x)
           (equal (bool-to-4v-lst (bool-from-4v-list x))
                  x)))

(defthmd pairlis$-of-4v-sexpr-eval-list
  (implies (equal (len keys) (len x))
           (equal (pairlis$ keys (4v-sexpr-eval-list x env))
                  (4v-sexpr-eval-alist (pairlis$ keys x) env)))
  :hints(("Goal" :in-theory (e/d (4v-sexpr-eval-list
                                  4v-sexpr-eval-alist
                                  pairlis$)
                                 (4v-sexpr-eval
                                  sexpr-eval-list-norm-env-when-ground-args-p
                                  vl::consp-of-car-when-cons-listp
                                  consp-under-iff-when-true-listp)))))

(local
 (defthm rev-of-4v-sexpr-eval-alist
   (implies (syntaxp (quotep alist))
            (equal (rev (4v-sexpr-eval-alist alist env))
                   (4v-sexpr-eval-alist (rev alist) env)))
   :hints(("Goal" :in-theory (e/d (4v-sexpr-eval-alist rev)
                                  (4v-sexpr-eval))))))

(defthmd revappend-of-4v-sexpr-eval-alist
  (implies (syntaxp (quotep alist))
           (equal (revappend (4v-sexpr-eval-alist alist env) rest)
                  (append (4v-sexpr-eval-alist (revappend alist nil) env)
                          rest)))
  :hints(("Goal" :in-theory (e/d (4v-sexpr-eval-alist
                                  revappend-removal)
                                 (4v-sexpr-eval))
          :use rev-of-4v-sexpr-eval-alist)))

(encapsulate nil
  (local (include-book "arithmetic/top-with-meta" :dir :system))
  (defthmd cdr-of-bool-to-4v-lst
    (implies (posp n)
             (equal (cdr (bool-to-4v-lst (int-to-v a n)))
                    (bool-to-4v-lst (int-to-v (logcdr a) (1- n)))))
    :hints (("goal" :expand ((int-to-v a n)
                             (:free (a b) (bool-to-4v-lst (cons a b)))
                             (logtail 1 a))
             :do-not-induct t)))

  (defthmd car-of-bool-to-4v-lst
    (implies (and (integerp a) (posp n))
             (equal (car (bool-to-4v-lst (int-to-v a n)))
                    (bool-to-4v (logbitp 0 a))))
    :hints (("goal" :expand ((int-to-v a n)
                             (:free (a b) (bool-to-4v-lst (cons a b)))
                             (logtail 1 a))
             :do-not-induct t)))

  (defthmd logcdr-to-logtail
    (equal (logcdr x)
           (logtail 1 x))
    :hints (("goal" :expand ((logtail 1 x))))))

;; (defthm safe-pairlis-onto-acc-of-4v-sexpr-eval-list
;;   (implies (equal (len keys) (len x))
;;            (equal (safe-pairlis-onto-acc keys (4v-sexpr-eval-list x env) acc)
;;                   (append (4v-sexpr-eval-alist (reverse (pairlis$ keys x))
;;                                                env)
;;                           acc)))
;;   :hints (("goal" :induct (pairlis$ keys x)
;;            :in-theory (e/d ((:i pairlis$))
;;                            (4v-sexpr-eval
;;                             consp-under-iff-when-true-listp
;;                             consp-of-car-when-alistp
;;                             append
;;                             rev
;;                             4v-sexpr-eval-alist
;;                             4v-sexpr-eval-list
;;                             sexpr-eval-list-norm-env-when-ground-args-p
;;                             append-when-not-consp))
;;            :expand ((pairlis$ keys x)
;;                     (4v-sexpr-eval-list nil env)
;;                     (4v-sexpr-eval-alist nil env)
;;                     (:free (a b) (4v-sexpr-eval-list (cons a b) env))
;;                     (:free (a b) (4v-sexpr-eval-alist (cons a b) env))
;;                     (:free (a b) (rev (cons a b)))
;;                     (:free (a b c) (append (cons a b) c))))))

(defthmd append-of-4v-sexpr-eval-alist
  (equal (append (4v-sexpr-eval-alist a env)
                 (4v-sexpr-eval-alist b env))
         (4v-sexpr-eval-alist (append a b) env)))

;; (defthm cdr-of-4v-sexpr-eval-list-of-cons
;;   (equal (cdr (4v-sexpr-eval-list (cons a b) env))
;;          (4v-sexpr-eval-list b env)))

;; (defthm car-of-4v-sexpr-eval-list-of-cons
;;   (equal (car (4v-sexpr-eval-list (cons a b) env))
;;          (4v-sexpr-eval a env)))


;; alist is something consed or appended together; looks for either a final cdr
;; or appended element that is a 4v-sexpr-eval-alist and returns its
;; sexpr-alist and environment.
(defun find-composition-in-alist (alist)
  (b* (((when (atom alist)) nil)
       ((when (eq (car alist) '4v-sexpr-eval-alist))
        `((sexpr-alist . ,(cadr alist))
          (env . ,(caddr alist))))
       ((when (eq (car alist) 'binary-append))
        (b* ((arg1 (cadr alist))
             ((when (eq (car arg1) '4v-sexpr-eval-alist))
              `((sexpr-alist . ,(cadr arg1))
                (env . ,(caddr arg1)))))
          (find-composition-in-alist (caddr alist))))
       ((when (eq (car alist) 'cons))
        (find-composition-in-alist (caddr alist))))
    nil))
    

(defun 4v-sexpr-restrict-list-fast (sexprs sexpr-alist)
  (with-fast-alist sexpr-alist
    (4v-sexpr-restrict-list sexprs sexpr-alist)))

(defthmd 4v-sexpr-eval-list-of-composition
  (implies (and (bind-free (find-composition-in-alist alist) (sexpr-alist env))
                (force (4v-env-equiv alist
                                     (append (4v-sexpr-eval-alist sexpr-alist env)
                                             env))))
           (equal (4v-sexpr-eval-list sexprs alist)
                  (4v-sexpr-eval-list
                   (4v-sexpr-restrict-list-fast sexprs sexpr-alist)
                   env))))

(defun 4v-alist-extract-fast (keys al)
  (with-fast-alist al
    (4v-alist-extract keys al)))

(local
 (encapsulate nil
   (local (in-theory (disable 4v-sexpr-apply
                              4v-sexpr-eval
                              4v-sexpr-eval-list
                              4v-unfloat
                              sets::union
                              sets::subset
                              consp-under-iff-when-true-listp
                              subsetp-trans2
                              subsetp-when-atom-right
                              4v-alists-agree
                              sexpr-eval-list-norm-env-when-ground-args-p
                              4v-sexpr-vars
                              4v-sexpr-vars-list)))
   (defthm-4v-sexpr-flag
     (defthm 4v-sexpr-eval-of-alist-extract
       (implies (hons-subset (4v-sexpr-vars x) vars)
                (equal (4v-sexpr-eval x (4v-alist-extract vars env))
                       (4v-sexpr-eval x env)))
       :hints ('(:expand ((:free (env) (4v-sexpr-eval x env))
                          (4v-sexpr-vars x))))
       :flag sexpr)
     (defthm 4v-sexpr-eval-list-of-alist-extract
       (implies (hons-subset (4v-sexpr-vars-list x) vars)
                (equal (4v-sexpr-eval-list x (4v-alist-extract vars env))
                       (4v-sexpr-eval-list x env)))
       :hints ('(:expand ((:free (env) (4v-sexpr-eval-list x env))
                          (4v-sexpr-vars-list x))))
       :flag sexpr-list))))



(defthmd equal-of-4v-to-nat-sexpr-eval-lists
  (implies (and (equal xr (sexpr-rewrite-default-list x))
                (equal xr (sexpr-rewrite-default-list y))
                (equal vars (4v-sexpr-vars-1pass-list xr))
                (4v-env-equiv (4v-alist-extract vars env1)
                              (4v-alist-extract vars env2)))
           (equal (equal (4v-to-nat (4v-sexpr-eval-list x env1))
                         (4v-to-nat (4v-sexpr-eval-list y env2)))
                  t))
  :hints (("goal" :use ((:instance sexpr-rewrite-list-correct
                         (rewrites *sexpr-rewrites*) (x x))
                        (:instance sexpr-rewrite-list-correct
                         (rewrites *sexpr-rewrites*) (x y))
                        (:instance 4v-sexpr-eval-list-of-alist-extract
                         (x (sexpr-rewrite-default-list x))
                         (env env1)
                         (vars (4v-sexpr-vars-list (sexpr-rewrite-default-list x))))
                        (:instance 4v-sexpr-eval-list-of-alist-extract
                         (x (sexpr-rewrite-default-list x))
                         (env env2)
                         (vars (4v-sexpr-vars-list (sexpr-rewrite-default-list x)))))
           :in-theory (e/d () (sexpr-rewrite-list-correct)))))

(defthmd 4v-env-equiv-by-witness
  (implies (syntaxp (or (rewriting-positive-literal-fn
                         `(4v-env-equiv ,x ,y) mfc state)
                        (rewriting-positive-literal-fn
                         `(4v-env-equiv ,y ,x) mfc state)))
           (equal (4v-env-equiv x y)
                  (let ((w (4v-env-equiv-witness x y)))
                    (equal (4v-lookup w x)
                           (4v-lookup w y)))))
  :hints(("Goal" :in-theory (enable 4v-env-equiv))))

(defthmd 4v-lookup-rw
  (equal (4v-lookup k env)
         (4v-fix (cdr (hons-assoc-equal k env)))))




;; (in-theory (e/d (stv-run-fn
;;                  (boothmul-decomp)
;;                  (boothmul-direct))
;;                 (4v-sexpr-eval-alist
;;                  4v-sexpr-eval-list
;;                  4v-sexpr-eval
;;                  4v-sexpr-eval-list-with-redundant-cons
;;                  stv-assemble-output-alist
;;                  4v-to-nat)))



    
  


;; (implies 
;;          (b* ( ;; Run the decomposed circuit to get the partial products
;;               (in-alist1  (boothmul-decomp-autoins))
;;               (out-alist1 (stv-run (boothmul-decomp) in-alist1))

;;               ;; Grab the resulting partial products out.
;;               ((assocs pp0 pp1 pp2 pp3 pp4 pp5 pp6 pp7) out-alist1)

;;               ;; Run the decomposed circuit again, sticking the partial
;;               ;; products back in on the inputs.  (This is a rather subtle use
;;               ;; of the autoins macro, which uses the bindings for pp0...pp7
;;               ;; above.)
;;               (in-alist2 (boothmul-decomp-autoins))
;;               (out-alist2 (stv-run (boothmul-decomp) in-alist2))

;;               ;; Separately, run the original circuit.
;;               (orig-in-alist  (boothmul-direct-autoins))
;;               (orig-out-alist (stv-run (boothmul-direct) orig-in-alist)))

;;            (equal
;;             ;; The final answer from running the decomposed circuit the second
;;             ;; time, after feeding its partial products back into itself.
;;             (cdr (assoc 'o out-alist2))

;;             ;; The answer from running the original circuit.
;;             (cdr (assoc 'o orig-out-alist)))))


(defevaluator stv-decomp-ev stv-decomp-ev-lst
  ((if a b c)
   (cons a b)
   (car a)
   (cdr a)
   (binary-append a b)
   (4v-env-equiv a b)
   (4v-alist-extract vars b)
   (4v-sexpr-eval-alist a env)
   (4v-sexpr-eval a env)))

(local
 (define stv-decomp-process-alist-quote (x)
   :returns (al pseudo-term-val-alistp)
   (if (atom x)
       nil
     (if (consp (car x))
         (cons (cons (caar x)
                     (kwote (cdar x)))
               (stv-decomp-process-alist-quote (cdr X)))
       (stv-decomp-process-alist-quote (cdr x))))
   ///
   (outer-local
    (defthm stv-decomp-process-alist-lookup-exists
      (iff (hons-assoc-equal k (stv-decomp-process-alist-quote x))
           (hons-assoc-equal k x))))
   (outer-local
    (defthm stv-decomp-process-alist-quote-correct
      (equal (stv-decomp-ev (cdr (hons-assoc-equal k (stv-decomp-process-alist-quote x))) env)
             (cdr (hons-assoc-equal k x)))))))
(finish-with-outer-local)

(local
 (define stv-decomp-process-alist-pair-term ((x pseudo-termp))
   :returns (mv err (consp t) key (val pseudo-termp :hyp :guard))
   (b* (((when (atom x)) (mv (msg "failed to process: ~x0" x)
                             nil nil nil))
        ((when (eq (car x) 'quote))
         (b* ((val (cadr x))
              (consp (consp val)))
           (mbe :logic (mv nil consp (car val) (kwote (cdr val)))
                :exec (mv nil consp
                          (and consp (car val))
                          (kwote (and consp (cdr val)))))))
        ((unless (eq (car x) 'cons))
         (mv (msg "failed to process: ~x0" x) nil nil nil))
        ((list car cdr) (cdr x))
        ((unless (quotep car))
         (mv (msg "failed to process: ~x0" x) nil nil nil)))
     (mv nil t (unquote car) cdr))
   ///
   (outer-local
    (defthm stv-decomp-process-alist-pair-term-correct
      (b* (((mv err consp key val)
            (stv-decomp-process-alist-pair-term x)))
        (implies (not err)
                 (and (implies (bind-free '((env . env)) (env))
                               (and (equal consp
                                           (consp (stv-decomp-ev x env)))
                                    (equal key
                                           (car (stv-decomp-ev x env)))))
                      (equal (stv-decomp-ev val env)
                             (cdr (stv-decomp-ev x env))))))))))
(finish-with-outer-local)

(local
 (define stv-decomp-process-sexpr-eval (alist envterm)
   :returns (res pseudo-term-val-alistp :hyp (pseudo-termp envterm))
   (b* (((when (atom alist)) nil)
        ((when (atom (car alist)))
         (stv-decomp-process-sexpr-eval (cdr alist) envterm))
        ((cons key sexpr) (car alist)))
     (cons (cons key `(4v-sexpr-eval (quote ,sexpr) ,envterm))
           (stv-decomp-process-sexpr-eval (cdr alist) envterm)))
   ///
   (outer-local
    (defthm stv-decomp-process-sexpr-eval-lookup-under-iff
      (b* ((res (stv-decomp-process-sexpr-eval alist envterm)))
        (iff (hons-assoc-equal key res)
             (hons-assoc-equal key alist)))))

   (outer-local
    (defthm stv-decomp-process-sexpr-eval-lookup-correct
      (b* ((res (stv-decomp-process-sexpr-eval alist envterm)))
        (implies (hons-assoc-equal key alist)
                 (equal (stv-decomp-ev (cdr (hons-assoc-equal key res)) env)
                        (4v-sexpr-eval (cdr (hons-assoc-equal key alist))
                                       (stv-decomp-ev envterm env)))))))

   (outer-local
    (defthm stv-decomp-process-sexpr-eval-lookup-none
      (b* ((res (stv-decomp-process-sexpr-eval alist envterm)))
        (implies (not (hons-assoc-equal key alist))
                 (equal (hons-assoc-equal key res) nil)))))))
(finish-with-outer-local)
       

(local
 (define stv-decomp-alist-extract (vars al)
   :returns (al1 pseudo-term-val-alistp :hyp (pseudo-term-val-alistp al))
   :prepwork ((local (defthm pseudo-termp-lookup-in-pseudo-term-val-alistp
                       (implies (and (pseudo-term-val-alistp x)
                                     (hons-assoc-equal k x))
                                (pseudo-termp (cdr (hons-assoc-equal k x))))
                       :hints(("Goal" :in-theory (e/d (pseudo-term-val-alistp)
                                                      (pseudo-termp)))))))
   
   (b* (((when (atom vars)) nil)
        (look (hons-get (car vars) al))
        (rest (stv-decomp-alist-extract (cdr vars) al)))
     (cons (cons (car vars) (if look (cdr look) ''x))
           rest))
   ///
   (outer-local
    (defthm stv-decomp-alist-extract-lookup-under-iff
      (iff (hons-assoc-equal key (stv-decomp-alist-extract vars al))
           (member key vars))))
   
   (outer-local
    (defthm stv-decomp-alist-extract-correct
      (equal (4v-fix (stv-decomp-ev
                      (cdr (hons-assoc-equal key (stv-decomp-alist-extract vars al)))
                      env))
             (if (member key vars)
                 (4v-fix (stv-decomp-ev
                          (cdr (hons-assoc-equal key al))
                          env))
               'x))))))
(finish-with-outer-local)
                    

(local (defthm pseudo-term-val-alistp-of-append
         (implies (and (pseudo-term-val-alistp a)
                       (pseudo-term-val-alistp b))
                  (pseudo-term-val-alistp (append a b)))))
  

(local
 (define stv-decomp-process-alist-term ((x pseudo-termp))
   :returns (mv err (al pseudo-term-val-alistp :hyp :guard))
   :verify-guards nil
   :prepwork ((local (defthm pseudo-term-val-alistp-of-acons
                       (equal (pseudo-term-val-alistp (cons (cons key val) rest))
                              (and (pseudo-termp val)
                                   (pseudo-term-val-alistp rest)))))
              (local (in-theory (disable consp-of-car-when-alistp
                                         pseudo-term-val-alistp))))
   (b* (((when (atom x)) (mv (msg "Couldn't process: ~x0" x) nil))
        ((when (eq (car x) 'quote))
         (mv nil (stv-decomp-process-alist-quote (cadr x))))
        ((when (eq (car x) 'binary-append))
         (b* (((mv err a1) (stv-decomp-process-alist-term (cadr x)))
              ((when err) (mv err nil))
              ((mv err a2) (stv-decomp-process-alist-term (caddr x)))
              ((when err) (mv err nil)))
           (mv nil (append a1 a2))))
        ((when (eq (car x) '4v-sexpr-eval-alist))
         (b* (((list sexpr-al env) (cdr x))
              ((unless (quotep sexpr-al))
               (mv (msg "Couldn't process: ~x0" x) nil)))
           (mv nil (stv-decomp-process-sexpr-eval (unquote sexpr-al) env))))
        ((when (eq (car x) '4v-alist-extract))
         (b* (((list vars x1) (cdr x))
              ((unless (quotep vars))
               (mv (msg "Couldn't process ~x0" x) nil))
              ((mv err x1-al) (stv-decomp-process-alist-term x1))
              ((when err) (mv err nil)))
           (mv err (with-fast-alist x1-al
                     (stv-decomp-alist-extract (unquote vars) x1-al)))))
        ((unless (eq (car x) 'cons))
         (mv (msg "Couldn't process: ~x0" x) nil))
        ((list first rest) (cdr x))
        ((mv err consp key val) (stv-decomp-process-alist-pair-term first))
        ((when err) (mv err nil))
        ((mv err rest) (stv-decomp-process-alist-term rest))
        ((when err) (mv err nil)))
     (mv nil (if consp
                 (cons (cons key val) rest)
               rest)))
   ///
   (outer-local
    (defthm true-listp-stv-decomp-process-alist-term
      (true-listp (mv-nth 1 (stv-decomp-process-alist-term x)))
      :rule-classes :type-prescription))

   (verify-guards stv-decomp-process-alist-term)

   (outer-local
    (defthm stv-decomp-process-alist-term-lookup-under-iff
      (b* (((mv err res) (stv-decomp-process-alist-term x)))
        (implies (not err)
                 (iff (hons-assoc-equal k (stv-decomp-ev x env))
                      (hons-assoc-equal k res))))))

   (outer-local
    (defthm stv-decomp-process-alist-term-lookup-correct
      (b* (((mv err res) (stv-decomp-process-alist-term x)))
        (implies (not err)
                 (equal (4v-fix (cdr (hons-assoc-equal k (stv-decomp-ev x env))))
                        (4v-fix (stv-decomp-ev (cdr (hons-assoc-equal k res)) env)))))
      :hints (("goal" :induct (stv-decomp-process-alist-term x)))))

   (outer-local
    (defthm alist-equiv-of-stv-decomp-implies-4v-env-equiv
      (b* (((mv aerr a-al) (stv-decomp-process-alist-term a))
           ((mv berr b-al) (stv-decomp-process-alist-term b)))
        (implies (and (not aerr) (not berr)
                      (alist-equiv a-al b-al))
                 (equal (4v-env-equiv (stv-decomp-ev a env)
                                      (stv-decomp-ev b env))
                        t)))
      :hints ((and stable-under-simplificationp
                   '(:in-theory (enable 4v-env-equiv-by-witness)
                     :do-not-induct t)))))))
(finish-with-outer-local)

(define stv-decomp-4v-env-equiv-meta ((x pseudo-termp))
  (b* (((unless (and (consp x) (eq (car x) '4v-env-equiv)))
        (er hard? 'stv-decomp-4v-env-equiv-meta "Bad term: ~x0" x)
        x)
       ((list a b) (cdr x))
       ((mv err a-al) (stv-decomp-process-alist-term a))
       ((when err)
        (er hard? 'stv-decomp-process-alist-term "~@0" err)
        x)
       ((mv err b-al) (stv-decomp-process-alist-term b))
       ((when err)
        (er hard? 'stv-decomp-process-alist-term "~@0" err)
        x)
       ((when (alist-equiv a-al b-al))
        ''t))
    (er hard? 'stv-decomp-4v-env-equiv-meta "Not equivalent")
    x)
  ///
  (defthmd stv-decomp-4v-env-equiv-meta-rule
    (equal (stv-decomp-ev x env)
           (stv-decomp-ev (stv-decomp-4v-env-equiv-meta x) env))
    :rule-classes ((:meta :trigger-fns (4v-env-equiv)))))


(def-ruleset stv-decomp-rules
  '(stv-run-fn
    stv-run-make-eval-env
    stv-run-collect-eval-signals
    car-cons cdr-cons
    make-fast-alist
    4v-sexpr-simp-and-eval-alist
    safe-pairlis-onto-acc
    natp-compound-recognizer
    lookup-each-of-4v-sexpr-eval-alist
    assoc-of-stv-assemble-output-alist
    ;; pairlis$-of-cons
    ;; pairlis$-when-atom
    revappend-open
    revappend-nil
    stv-simvar-inputs-to-bits-open
    stv-simvar-inputs-to-bits-nil
    v-to-nat-bound
    len-of-4v-sexpr-eval-list
    len-bool-from-4v-list
    bool-to-4v-lst-of-bool-from-4v-lst-when-4v-bool-listp
    pairlis$-of-4v-sexpr-eval-list
    revappend-of-4v-sexpr-eval-alist
    cdr-of-bool-to-4v-lst
    car-of-bool-to-4v-lst
    logcdr-to-logtail
    logtail-of-logtail
    logbitp-of-logtail
    append-of-4v-sexpr-eval-alist
    4v-sexpr-eval-list-of-composition
    equal-of-4v-to-nat-sexpr-eval-lists
    4v-lookup-rw
    (:t logtail)
    (:t 4v-sexpr-eval-list)
    (:t v-to-nat)
    stv-decomp-4v-env-equiv-meta-rule
    4v-to-nat-to-v-to-nat
    natp-4v-to-nat
    int-to-v-v-to-nat
    boolean-listp-bool-from-4v-list
    eq eql
    (:t 4v-sexpr-eval-alist)
    append-to-nil))

(defmacro stv-decomp-theory ()
  '(union-theories (get-ruleset 'stv-decomp-rules world)
                   (executable-counterpart-theory :here)))
    
