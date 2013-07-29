
(in-package "GL")

(include-book "gtypes")
(include-book "bvar-db")
(include-book "param")
(local (include-book "centaur/misc/arith-equivs" :dir :system))

(defsection bfr-vars-bounded
  (defun-sk bfr-vars-bounded (n x)
    (forall m
            (implies (<= (nfix n) (nfix m))
                     (not (bfr-depends-on m x))))
    :rewrite :direct)

  (in-theory (disable bfr-vars-bounded))

  (defthm bfr-vars-bounded-incr
    (implies (and (bfr-vars-bounded m x)
                  (<= (nfix m) (nfix n)))
             (bfr-vars-bounded n x))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause)))))))

  (local (in-theory (enable* acl2::arith-equiv-forwarding)))

  (local (defthm bfr-eval-of-set-non-dep-cong
           (implies (and (not (bfr-depends-on k x))
                         (acl2::nat-equiv k k-equiv))
                    (equal (bfr-eval x (bfr-set-var k-equiv v env))
                           (bfr-eval x env)))))

  (defcong acl2::nat-equiv equal (bfr-depends-on k x) 1
    :hints(("Goal" :cases ((bfr-depends-on k x))
            :in-theory (disable acl2::nat-equiv))
           (and stable-under-simplificationp
                (if (eq (caar clause) 'not)
                    `(:expand (,(cadar clause)))
                  `(:expand (,(cadar (last clause))))))))

  (defcong acl2::nat-equiv equal (bfr-vars-bounded n x) 1
    :hints(("Goal" 
            :use ((:instance bfr-vars-bounded-necc
                   (m (bfr-vars-bounded-witness acl2::n-equiv x)))
                  (:instance bfr-vars-bounded-necc
                   (n acl2::n-equiv)
                   (m (bfr-vars-bounded-witness n x))))
            :in-theory (e/d (bfr-vars-bounded)
                            (bfr-vars-bounded-necc)))))

  (defthm bfr-vars-bounded-of-consts
    (and (bfr-vars-bounded k t)
         (bfr-vars-bounded k nil))
    :hints(("Goal" :in-theory (enable bfr-vars-bounded)))))

(defsection bfr-list-vars-bounded
  (defund bfr-list-vars-bounded (n x)
    (if (atom x)
        t
      (and (bfr-vars-bounded n (car x))
           (bfr-list-vars-bounded n (cdr x)))))

  (local (in-theory (enable bfr-list-vars-bounded)))

  (defthm bfr-list-vars-bounded-incr
    (implies (and (bfr-list-vars-bounded m x)
                  (<= (nfix m) (nfix n)))
             (bfr-list-vars-bounded n x))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause)))))))

  (defcong acl2::nat-equiv equal (bfr-list-vars-bounded n x) 1)

  (defthm bfr-list-vars-bounded-of-cons
    (equal (bfr-list-vars-bounded n (cons x y))
           (and (bfr-vars-bounded n x)
                (bfr-list-vars-bounded n y))))

  (defthm bfr-list-vars-bounded-of-atom
    (implies (not (consp x))
             (equal (bfr-list-vars-bounded n x) t))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))


(defsection pbfr-vars-bounded

  (defun-sk pbfr-vars-bounded (n p x)
    (forall m
            (implies (<= (nfix n) (nfix m))
                     (not (pbfr-depends-on m p x))))
    :rewrite :direct)

  (in-theory (disable pbfr-vars-bounded))

  (defthm pbfr-vars-bounded-incr
    (implies (and (pbfr-vars-bounded m p x)
                  (<= (nfix m) (nfix n)))
             (pbfr-vars-bounded n p x))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause)))))))

  (local (in-theory (enable* acl2::arith-equiv-forwarding)))

  (local (defthm pbfr-eval-of-set-non-dep-cong
           (implies (and (not (pbfr-depends-on k p x))
                         (acl2::nat-equiv k k-equiv)
                         (bfr-eval p env)
                         (bfr-eval p (bfr-set-var k-equiv v env)))
                    (equal (bfr-eval x (bfr-param-env p (bfr-set-var k-equiv v env)))
                           (bfr-eval x (bfr-param-env p env))))))

  (defcong acl2::nat-equiv equal (pbfr-depends-on k p x) 1
    :hints(("Goal" :cases ((pbfr-depends-on k p x))
            :in-theory (disable acl2::nat-equiv))
           (and stable-under-simplificationp
                (if (eq (caar clause) 'not)
                    `(:expand (,(cadar clause)))
                  `(:expand (,(cadar (last clause))))))))

  (defcong acl2::nat-equiv equal (pbfr-vars-bounded n p x) 1
    :hints(("Goal" 
            :use ((:instance pbfr-vars-bounded-necc
                   (m (pbfr-vars-bounded-witness acl2::n-equiv p x)))
                  (:instance pbfr-vars-bounded-necc
                   (n acl2::n-equiv)
                   (m (pbfr-vars-bounded-witness n p x))))
            :in-theory (e/d (pbfr-vars-bounded)
                            (pbfr-vars-bounded-necc)))))

  (defthm pbfr-vars-bounded-of-consts
    (and (pbfr-vars-bounded k p t)
         (pbfr-vars-bounded k p nil))
    :hints(("Goal" :in-theory (enable pbfr-vars-bounded))))

  (defthm bfr-param-env-t
    (equal (bfr-param-env t env)
           env)
    :hints(("Goal" :in-theory (enable bfr-param-env bfr-lookup))))

  (defthm bfr-unparam-env-t
    (equal (bfr-unparam-env t env) env)
    :hints(("Goal" :in-theory (enable bfr-unparam-env))))


  (defthm pbfr-depends-on-t
    (implies (not (pbfr-depends-on k t x))
             (not (bfr-depends-on k x)))
    :hints (("goal" :expand ((bfr-depends-on k x))
             :use ((:instance pbfr-depends-on-suff
                    (p t)
                    (v (mv-nth 1 (bfr-depends-on-witness k x)))
                    (env (mv-nth 0 (bfr-depends-on-witness k x)))))
             :in-theory (disable pbfr-depends-on-suff))))

  (defthm pbfr-depends-on-of-bfr-to-param-space
    (implies (not (pbfr-depends-on k t x))
             (not (pbfr-depends-on k p (bfr-to-param-space p x))))
    :hints (("goal" :expand ((pbfr-depends-on k p (bfr-to-param-space p x)))
             :use ((:instance pbfr-depends-on-suff
                    (p t)
                    (env (mv-nth 0 (pbfr-depends-on-witness k p (bfr-to-param-space p x))))
                    (v (mv-nth 1 (pbfr-depends-on-witness k p (bfr-to-param-space p x))))))
             :in-theory (disable pbfr-depends-on-suff
                                 pbfr-eval-of-set-non-dep))))

  (defthm pbfr-vars-bounded-t
    (implies (pbfr-vars-bounded k t x)
             (bfr-vars-bounded k x))
    :hints (("goal" :expand ((bfr-vars-bounded k x))
             :use ((:instance pbfr-vars-bounded-necc
                    (n k)
                    (p t) (m (bfr-vars-bounded-witness k x))))
             :in-theory (disable pbfr-vars-bounded-necc))))

  (defthm pbfr-vars-bounded-of-bfr-to-param-space
    (implies (pbfr-vars-bounded k t x)
             (pbfr-vars-bounded k p (bfr-to-param-space p x)))
    :hints (("goal" :expand ((pbfr-vars-bounded k p (bfr-to-param-space p x)))))))

(defsection pbfr-list-depends-on
  (local (in-theory (enable pbfr-list-depends-on)))

  (defthm pbfr-list-depends-on-of-cons
    (equal (pbfr-list-depends-on k p (cons x y))
           (or (pbfr-depends-on k p x)
               (pbfr-list-depends-on k p y))))

  (defthm pbfr-list-depends-on-of-atom
    (implies (not (consp x))
             (equal (pbfr-list-depends-on k p x)
                    nil))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))


(defsection pbfr-list-vars-bounded
  (defund pbfr-list-vars-bounded (n p x)
    (if (atom x)
        t
      (and (pbfr-vars-bounded n p (car x))
           (pbfr-list-vars-bounded n p (cdr x)))))

  (defun pbfr-list-vars-bounded-witness (n p x)
    (if (atom x)
        nil
      (or (and (not (pbfr-vars-bounded n p (car x)))
               (nfix (pbfr-vars-bounded-witness n p (car x))))
          (pbfr-list-vars-bounded-witness n p (cdr x)))))

  (local (in-theory (enable pbfr-list-vars-bounded)))



  (defthm pbfr-list-vars-bounded-implies-not-depends-on
    (implies (and (pbfr-list-vars-bounded n p x)
                  (<= (nfix n) (nfix m)))
             (not (pbfr-list-depends-on m p x)))
    :hints(("Goal" :in-theory (enable pbfr-list-depends-on))))

  (defthm pbfr-list-vars-bounded-incr
    (implies (and (pbfr-list-vars-bounded m p x)
                  (<= (nfix m) (nfix n)))
             (pbfr-list-vars-bounded n p x))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause)))))))

  (defcong acl2::nat-equiv equal (pbfr-list-vars-bounded n p x) 1)

  (defthmd pbfr-list-vars-bounded-in-terms-of-witness
    (implies (acl2::rewriting-positive-literal
              `(pbfr-list-vars-bounded ,n ,p ,x))
             (equal (pbfr-list-vars-bounded n p x)
                    (let ((m (pbfr-list-vars-bounded-witness n p x)))
                      (or (< (nfix m) (nfix n))
                          (not (pbfr-list-depends-on m p x))))))
    :hints(("Goal" :in-theory (enable pbfr-list-depends-on)
            :induct t)
           (and stable-under-simplificationp
                '(:expand ((pbfr-vars-bounded n p (car x))
                           (:free (n) (pbfr-list-depends-on n p x)))))))

  (defthmd pbfr-list-vars-bounded-witness-under-iff
    (iff (pbfr-list-vars-bounded-witness n p x)
         (not (pbfr-list-vars-bounded n p x))))

  (defthm pbfr-list-vars-bounded-of-cons
    (equal (pbfr-list-vars-bounded n p (cons x y))
           (and (pbfr-vars-bounded n p x)
                (pbfr-list-vars-bounded n p y))))

  (defthm pbfr-list-vars-bounded-of-atom
    (implies (not (consp x))
             (equal (pbfr-list-vars-bounded n p x) t))
    :rule-classes ((:rewrite :backchain-limit-lst 0)))

  (defthm pbfr-list-vars-bounded-t
    (implies (pbfr-list-vars-bounded k t x)
             (bfr-list-vars-bounded k x)))

  (defthm pbfr-list-vars-bounded-of-bfr-to-param-space
    (implies (pbfr-list-vars-bounded k t x)
             (pbfr-list-vars-bounded k p (bfr-list-to-param-space p x)))
    :hints(("Goal" :in-theory (enable bfr-list-to-param-space)))))






(defsection gobj-alist-depends-on

  (defun gobj-alist-depends-on (k p x)
    (if (atom x)
        nil
      (or (and (consp (car x))
               (gobj-depends-on k p (cdar x)))
          (gobj-alist-depends-on k p (cdr x)))))


  (defthm gobj-alist-depends-on-of-pairlis$
    (implies (not (gobj-list-depends-on k p x))
             (not (gobj-alist-depends-on k p (pairlis$ keys x)))))

  (defthm gobj-depends-on-of-alist-lookup
    (implies (not (gobj-alist-depends-on k p alist))
             (not (gobj-depends-on k p (cdr (hons-assoc-equal x alist)))))))



(defsection gobj-vars-bounded

  (mutual-recursion
   (defun gobj-vars-bounded (k p x)
     (if (atom x)
         t
       (pattern-match x
         ((g-boolean b) (pbfr-vars-bounded k p b))
         ((g-number n)
          (b* (((mv rn rd in id) (break-g-number n)))
            (and (pbfr-list-vars-bounded k p rn)
                 (pbfr-list-vars-bounded k p rd)
                 (pbfr-list-vars-bounded k p in)
                 (pbfr-list-vars-bounded k p id))))
         ((g-ite test then else)
          (and (gobj-vars-bounded k p test)
               (gobj-vars-bounded k p then)
               (gobj-vars-bounded k p else)))
         ((g-concrete &) t)
         ((g-var &) t)
         ((g-apply & args) (gobj-list-vars-bounded k p args))
         (& (and (gobj-vars-bounded k p (car x))
                 (gobj-vars-bounded k p (cdr x)))))))
   (defun gobj-list-vars-bounded (k p x)
     (if (atom x)
         t
       (and (gobj-vars-bounded k p (car x))
            (gobj-list-vars-bounded k p (cdr x))))))

  (mutual-recursion
   (defun gobj-vars-bounded-witness (k p x)
     (if (atom x)
         nil
       (pattern-match x
         ((g-boolean b) (and (not (pbfr-vars-bounded k p b))
                             (nfix (pbfr-vars-bounded-witness k p b))))
         ((g-number n)
          (b* (((mv rn rd in id) (break-g-number n)))
            (or (pbfr-list-vars-bounded-witness k p rn)
                (pbfr-list-vars-bounded-witness k p rd)
                (pbfr-list-vars-bounded-witness k p in)
                (pbfr-list-vars-bounded-witness k p id))))
         ((g-ite test then else)
          (or (gobj-vars-bounded-witness k p test)
              (gobj-vars-bounded-witness k p then)
              (gobj-vars-bounded-witness k p else)))
         ((g-concrete &) nil)
         ((g-var &) nil)
         ((g-apply & args) (gobj-list-vars-bounded-witness k p args))
         (& (or (gobj-vars-bounded-witness k p (car x))
                (gobj-vars-bounded-witness k p (cdr x)))))))
   (defun gobj-list-vars-bounded-witness (k p x)
     (if (atom x)
         nil
       (or (gobj-vars-bounded-witness k p (car x))
           (gobj-list-vars-bounded-witness k p (cdr x))))))

  (in-theory (disable gobj-vars-bounded gobj-list-vars-bounded))
  (local (in-theory (enable gobj-vars-bounded gobj-list-vars-bounded)))

  (defthm-gobj-flag
    (defthm gobj-vars-bounded-implies-not-depends-on
      (implies (and (gobj-vars-bounded k p x)
                    (<= (nfix k) (nfix n)))
               (not (gobj-depends-on n p x)))
      :flag gobj)
    (defthm gobj-list-vars-bounded-implies-not-depends-on
      (implies (and (gobj-list-vars-bounded k p x)
                    (<= (nfix k) (nfix n)))
               (not (gobj-list-depends-on n p x)))
      :flag list))


  (defthm-gobj-flag
    (defthm gobj-vars-bounded-incr
      (implies (and (gobj-vars-bounded k p x)
                    (<= (nfix k) (nfix n)))
               (gobj-vars-bounded n p x))
      :flag gobj)
    (defthm gobj-list-vars-bounded-incr
      (implies (and (gobj-list-vars-bounded k p x)
                    (<= (nfix k) (nfix n)))
               (gobj-list-vars-bounded n p x))
      :flag list))

  (defthm-gobj-flag
    (defthm gobj-vars-bounded-witness-under-iff
      (iff (gobj-vars-bounded-witness k p x)
           (not (gobj-vars-bounded k p x)))
      :hints('(:in-theory (enable pbfr-list-vars-bounded-witness-under-iff)))
      :flag gobj)
    (defthm gobj-list-vars-bounded-witness-under-iff
      (iff (gobj-list-vars-bounded-witness k p x)
           (not (gobj-list-vars-bounded k p x)))
      :flag list))

  (defthm-gobj-flag
    (defthm gobj-vars-bounded-in-terms-of-witness
      (implies (acl2::rewriting-positive-literal
                `(gobj-vars-bounded ,k ,p ,x))
               (equal (gobj-vars-bounded k p x)
                      (let ((n (gobj-vars-bounded-witness k p x)))
                        (or (< (nfix n) (nfix k))
                            (not (gobj-depends-on n p x))))))
      :hints ('(:expand ((gobj-vars-bounded k p x)
                         (gobj-vars-bounded-witness k p x)))
              (and stable-under-simplificationp
                   `(:expand ((PBFR-VARS-BOUNDED K P (G-BOOLEAN->BOOL X))))))
      :flag gobj)
    (defthm gobj-list-vars-bounded-in-terms-of-witness
      (implies (acl2::rewriting-positive-literal
                `(gobj-list-vars-bounded ,k ,p ,x))
               (equal (gobj-list-vars-bounded k p x)
                      (let ((n (gobj-list-vars-bounded-witness k p x)))
                        (or (< (nfix n) (nfix k))
                            (not (gobj-list-depends-on n p x))))))
      :flag list)
    :hints (("goal" :in-theory (e/d (pbfr-list-vars-bounded-in-terms-of-witness
                                     pbfr-list-vars-bounded-witness-under-iff)
                                    (gobj-vars-bounded gobj-vars-bounded-witness)))))

  (in-theory (disable gobj-vars-bounded-in-terms-of-witness
                      gobj-list-vars-bounded-in-terms-of-witness))

  (defthm gobj-list-vars-bounded-of-g-apply->args
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-apply))
             (gobj-list-vars-bounded k p (g-apply->args x))))

  (defthm gobj-vars-bounded-of-g-ite->test
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-ite))
             (gobj-vars-bounded k p (g-ite->test x))))

  (defthm gobj-vars-bounded-of-g-ite->then
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-ite))
             (gobj-vars-bounded k p (g-ite->then x))))

  (defthm gobj-vars-bounded-of-g-ite->else
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-ite))
             (gobj-vars-bounded k p (g-ite->else x))))

  (defthm gobj-vars-bounded-car-of-gobj-list
    (implies (gobj-list-vars-bounded k p x)
             (gobj-vars-bounded k p (car x))))

  (defthm gobj-list-vars-bounded-cdr-of-gobj-list
    (implies (gobj-list-vars-bounded k p x)
             (gobj-list-vars-bounded k p (cdr x))))

  (defthm gobj-list-vars-bounded-of-cons
    (equal (gobj-list-vars-bounded k p (cons a b))
           (and (gobj-vars-bounded k p a)
                (gobj-list-vars-bounded k p b))))

  (defthm gobj-list-vars-bounded-of-atom
    (implies (not (consp x))
             (equal (gobj-list-vars-bounded k p x) t))
    :rule-classes ((:rewrite :backchain-limit-lst 0)))

  (defthm gobj-vars-bounded-car-of-gobj
    (implies (and (gobj-vars-bounded k p x)
                  (NOT (EQUAL (TAG X) :G-CONCRETE))
                  (NOT (EQUAL (TAG X) :G-BOOLEAN))
                  (NOT (EQUAL (TAG X) :G-NUMBER))
                  (NOT (EQUAL (TAG X) :G-ITE))
                  (NOT (EQUAL (TAG X) :G-VAR))
                  (NOT (EQUAL (TAG X) :G-APPLY)))
             (gobj-vars-bounded k p (car x))))

  (defthm gobj-vars-bounded-cdr-of-gobj
    (implies (and (gobj-vars-bounded k p x)
                  (NOT (EQUAL (TAG X) :G-CONCRETE))
                  (NOT (EQUAL (TAG X) :G-BOOLEAN))
                  (NOT (EQUAL (TAG X) :G-NUMBER))
                  (NOT (EQUAL (TAG X) :G-ITE))
                  (NOT (EQUAL (TAG X) :G-VAR))
                  (NOT (EQUAL (TAG X) :G-APPLY)))
             (gobj-vars-bounded k p (cdr x))))

  (defthm gobj-vars-bounded-of-g-boolean->bool
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-boolean))
             (pbfr-vars-bounded k p (g-boolean->bool x))))

  (defthm gobj-vars-bounded-of-g-number->num-0
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-number))
             (pbfr-list-vars-bounded k p (mv-nth 0 (break-g-number (g-number->num x))))))

  (defthm gobj-vars-bounded-of-g-number->num-1
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-number))
             (pbfr-list-vars-bounded k p (mv-nth 1 (break-g-number (g-number->num x))))))

  (defthm gobj-vars-bounded-of-g-number->num-2
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-number))
             (pbfr-list-vars-bounded k p (mv-nth 2 (break-g-number (g-number->num x))))))

  (defthm gobj-vars-bounded-of-g-number->num-3
    (implies (and (gobj-vars-bounded k p x)
                  (eq (tag x) :g-number))
             (pbfr-list-vars-bounded k p (mv-nth 3 (break-g-number (g-number->num x))))))

  (defthm-gobj-flag
    (defthm generic-geval-of-set-var-when-gobj-vars-bounded
      (implies (and (gobj-vars-bounded m p x)
                    (<= (nfix m) (nfix k))
                    (bfr-eval p env)
                    (bfr-eval p (bfr-set-var k v env)))
               (equal (generic-geval x (cons (bfr-param-env p (bfr-set-var k v env))
                                             var-env))
                      (generic-geval x (cons (bfr-param-env p env)
                                             var-env))))
      :hints ('(:expand ((:free (env) (:with generic-geval (generic-geval x env))))))
      :flag gobj)
    (defthm generic-geval-list-of-set-var-when-gobj-vars-bounded
      (implies (and (gobj-list-vars-bounded m p x)
                    (<= (nfix m) (nfix k))
                    (bfr-eval p env)
                    (bfr-eval p (bfr-set-var k v env)))
               (equal (generic-geval-list x (cons (bfr-param-env p (bfr-set-var k v env))
                                                  var-env))
                      (generic-geval-list x (cons (bfr-param-env p env)
                                                  var-env))))
      :hints ('(:expand ((:free (env) (generic-geval-list x env)))))
      :flag list))

  (defthm gobj-vars-bounded-of-atom
    (implies (not (consp x))
             (gobj-vars-bounded k p x))
    :rule-classes ((:rewrite :backchain-limit-lst 0)))

  (defthm gobj-vars-bounded-of-gl-cons
    (equal (gobj-vars-bounded k p (gl-cons a b))
           (and (gobj-vars-bounded k p a)
                (gobj-vars-bounded k p b)))
    :hints(("Goal" :in-theory (enable gl-cons g-keyword-symbolp))))

  (defthm gobj-vars-bounded-of-cons
    (implies (not (g-keyword-symbolp x))
             (equal (gobj-vars-bounded k p (cons x y))
                    (and (gobj-vars-bounded k p x)
                         (gobj-vars-bounded k p y))))
    :hints(("Goal" :in-theory (enable g-keyword-symbolp))))

  

  (defthm gobj-vars-bounded-of-g-apply
    (equal (gobj-vars-bounded k p (g-apply fn args))
           (gobj-list-vars-bounded k p args)))

  (defthm gobj-vars-bounded-of-g-ite
    (equal (gobj-vars-bounded k p (g-ite test then else))
           (and (gobj-vars-bounded k p test)
                (gobj-vars-bounded k p then)
                (gobj-vars-bounded k p else))))

  (defthm gobj-vars-bounded-of-g-number
    (equal (gobj-vars-bounded k p (g-number num))
           (b* (((mv rn rd in id) (break-g-number num)))
             (and (pbfr-list-vars-bounded k p rn)
                  (pbfr-list-vars-bounded k p rd)
                  (pbfr-list-vars-bounded k p in)
                  (pbfr-list-vars-bounded k p id)))))

  (defthm gobj-vars-bounded-of-g-boolean
    (equal (gobj-vars-bounded k p (g-boolean bool))
           (pbfr-vars-bounded k p bool)))

  (defthm gobj-vars-bounded-of-g-concrete
    (equal (gobj-vars-bounded k p (g-concrete val)) t))

  (defthm gobj-vars-bounded-of-g-var
    (equal (gobj-vars-bounded k p (g-var val)) t))

  
  (defthm gobj-vars-bounded-when-g-concrete
    (implies (equal (tag x) :g-concrete)
             (equal (gobj-vars-bounded k p x) t))
    :hints (("goal" :expand ((gobj-vars-bounded k p x))))
    :rule-classes ((:rewrite :backchain-limit-lst 0)))

  (defthm gobj-vars-bounded-when-g-var
    (implies (equal (tag x) :g-var)
             (equal (gobj-vars-bounded k p x) t))
    :hints (("goal" :expand ((gobj-vars-bounded k p x))))
    :rule-classes ((:rewrite :backchain-limit-lst 0))))

(defsection gobj-vars-bounded-of-gobj-to-param-space
  
  (defthmd pbfr-list-vars-bounded-of-boolean-list
    (implies (boolean-listp x)
             (pbfr-list-vars-bounded k p x))
    :hints(("Goal" :in-theory (enable bfr-list-vars-bounded boolean-listp))))

  (local (in-theory (enable pbfr-list-vars-bounded-of-boolean-list)))

  (local (defthm boolean-listp-i2v
           (boolean-listp (i2v n))
           :hints(("Goal" :in-theory (e/d (bfr-scons) (logcar logcdr))))))

  (local (defthm boolean-listp-n2v
           (boolean-listp (n2v n))
           :hints(("Goal" :in-theory (e/d (bfr-ucons) (logcar logcdr))))))

  (defthm gobj-vars-bounded-of-mk-g-number
    (implies (and (pbfr-list-vars-bounded k p rn)
                  (pbfr-list-vars-bounded k p rd)
                  (pbfr-list-vars-bounded k p in)
                  (pbfr-list-vars-bounded k p id))
             (gobj-vars-bounded k p (mk-g-number rn rd in id)))
    :hints(("Goal" :in-theory (e/d (mk-g-number-fn)
                                   (i2v n2v
                                        equal-of-booleans-rewrite
                                        sets::double-containment)))))

  (defthm-gobj-flag
    (defthm gobj-vars-bounded-of-gobj-to-param-space
      (implies (gobj-vars-bounded k t x)
               (gobj-vars-bounded
                k p (gobj-to-param-space x p)))
      :hints ('(:expand ((gobj-to-param-space x p)
                         (gobj-vars-bounded k t x))
                :in-theory (enable mk-g-ite
                                   mk-g-boolean
                                   ; mk-g-number
                                   gnumber-to-param-space)))
      :flag gobj)
    (defthm gobj-list-vars-bounded-of-gobj-list-to-param-space
      (implies (gobj-list-vars-bounded k t x)
               (gobj-list-vars-bounded
                k p (gobj-list-to-param-space x p)))
      :hints ('(:expand ((gobj-list-to-param-space x p))))
      :flag list)))


(defsection gobj-alist-vars-bounded
  (defund gobj-alist-vars-bounded (k p x)
    (if (atom x)
        t
      (and (or (atom (car x))
               (gobj-vars-bounded k p (cdar x)))
           (gobj-alist-vars-bounded k p (cdr x)))))

  (defund gobj-alist-vars-bounded-witness (k p x)
    (if (atom x)
        nil
      (or (and (consp (car x))
               (gobj-vars-bounded-witness k p (cdar x)))
          (gobj-alist-vars-bounded-witness k p (cdr x)))))

  (local (in-theory (enable gobj-alist-vars-bounded
                            gobj-alist-vars-bounded-witness)))

  (defthm gobj-alist-vars-bounded-implies-not-depends-on
    (implies (and (gobj-alist-vars-bounded k p x)
                  (<= (nfix k) (nfix n)))
             (not (gobj-alist-depends-on n p x)))
    :hints(("Goal" :in-theory (enable gobj-alist-depends-on))))

  (defthm gobj-alist-vars-bounded-of-pairlis$
    (implies (gobj-list-vars-bounded k p x)
             (gobj-alist-vars-bounded k p (pairlis$ keys x))))

  (defthm gobj-vars-bounded-of-alist-lookup
    (implies (gobj-alist-vars-bounded k p alist)
             (gobj-vars-bounded k p (cdr (hons-assoc-equal x alist)))))

  (defthm gobj-alist-vars-bounded-incr
    (implies (and (gobj-alist-vars-bounded m p x)
                  (<= (nfix m) (nfix n)))
             (gobj-alist-vars-bounded n p x))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause)))))))

  (defthm gobj-alist-vars-bounded-witness-under-iff
    (iff (gobj-alist-vars-bounded-witness k p x)
         (not (gobj-alist-vars-bounded k p x))))

  (defthmd gobj-alist-vars-bounded-in-terms-of-witness
    (implies (acl2::rewriting-positive-literal
              `(gobj-alist-vars-bounded ,k ,p ,x))
             (equal (gobj-alist-vars-bounded k p x)
                    (let ((n (gobj-alist-vars-bounded-witness k p x)))
                      (or (< (nfix n) (nfix k))
                          (not (gobj-alist-depends-on n p x))))))
    :hints(("Goal" :in-theory (enable gobj-alist-depends-on
                                      gobj-vars-bounded-in-terms-of-witness))))

  (defthm gobj-alist-vars-bounded-of-cons
    (equal (gobj-alist-vars-bounded k p (cons a b))
           (and (or (atom a)
                    (gobj-vars-bounded k p (cdr a)))
                (gobj-alist-vars-bounded k p b))))

  (defthm gobj-alist-vars-bounded-of-atom
    (implies (not (consp x))
             (equal (gobj-alist-vars-bounded k p x) t))
    :rule-classes ((:rewrite :backchain-limit-lst 0)))

  (defthm gobj-alist-vars-bounded-of-gobj-alist-to-param-space
    (implies (gobj-alist-vars-bounded k t x)
             (gobj-alist-vars-bounded
              k p (gobj-alist-to-param-space x p)))))


(defsection bvar-db-orderedp

  (defun-sk bvar-db-orderedp (p bvar-db)
    (forall n
            (implies (and (natp n)
                          (<= (base-bvar$a bvar-db) n)
                          (< n (next-bvar$a bvar-db)))
                     (gobj-vars-bounded n p (get-bvar->term$a n bvar-db))))
    :rewrite :direct)

  (in-theory (disable bvar-db-orderedp))

  (defthm gobj-vars-bounded-of-get-bvar->term-when-bvar-db-orderedp
    (implies (and (bvar-db-orderedp p bvar-db)
                  (<= (base-bvar$a bvar-db) (nfix m))
                  (<= (nfix m) (nfix n))
                  (< (nfix m) (next-bvar$a bvar-db)))
             (gobj-vars-bounded n p (get-bvar->term$a m bvar-db)))
    :hints (("goal" :use ((:instance bvar-db-orderedp-necc
                           (n (nfix m))))
             :in-theory (disable bvar-db-orderedp-necc))))

  (defthm bvar-db-orderedp-of-parametrize-bvar-db
    (implies (bvar-db-orderedp t bvar-db)
             (bvar-db-orderedp p (parametrize-bvar-db p bvar-db bvar-db1)))
    :hints (("goal" :expand ((bvar-db-orderedp p (parametrize-bvar-db p bvar-db nil)))
             :in-theory (disable parametrize-bvar-db))))

  (defthm bvar-db-orderedp-of-init-bvar-db
    (bvar-db-orderedp p (init-bvar-db$a base bvar-db))
    :hints(("Goal" :in-theory (enable bvar-db-orderedp)))))

