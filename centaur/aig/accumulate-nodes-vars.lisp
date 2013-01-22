
(in-package "ACL2")

(include-book "aig-vars-ext")
(include-book "centaur/misc/alist-equiv" :dir :system)

(local (in-theory (disable sets::double-containment)))

;; In this file, we prove that three ways of computing the set of non-negated
;; nodes in an AIG are equivalent.  We will ultimately use this to prove that
;; accumulate-aig-vars implements aig-vars.


;; First, the straightforward way.
(defun collect-nodes (a)
  (b* (((when (atom a)) (if (booleanp a) nil (list a)))
       ((When (eq (cdr a) nil))
        (collect-nodes (car a))))
    (cons a
          (append (collect-nodes (car a))
                  (collect-nodes (Cdr a))))))

;; Second, with an accumulator that we cons nodes onto after recurring on their
;; subtrees.
(defun accumulate-nodes-post (a lst)
  (b* (((when (atom a)) (if (or (booleanp a)
                                (member a lst))
                            lst
                          (cons a lst)))
       ((when (eq (cdr a) nil))
        (accumulate-nodes-post (car a) lst))
       ((when (member a lst))
        lst)
       (lst
        (accumulate-nodes-post (car a) lst))
       (lst
        (accumulate-nodes-post (cdr a) lst)))
    (cons a lst)))

;; Third, with an accumulator that we cons nodes onto before recurring on their
;; subtrees.
(defun accumulate-nodes-pre (a lst)
  (b* (((when (atom a)) (if (or (booleanp a)
                                (member a lst))
                            lst
                          (cons a lst)))
       ((when (eq (cdr a) nil))
        (accumulate-nodes-pre (car a) lst))
       ((when (member a lst))
        lst)
       (lst (cons a lst))
       (lst
        (accumulate-nodes-pre (car a) lst)))
    (accumulate-nodes-pre (cdr a) lst)))


;; Ultimately, we'll prove both of the accumulator versions set-equivalent to
;; (append (collect-nodes a) lst), under some well-formedness condition
;; pertaining to the initial value of the accumulator.  But each such
;; well-formedness condition will be true of the empty list, so we'll have
;; (accumulate-nodes-{pre,post} a nil) === (collect-nodes a).

;;---------------------------------------------------------------------------
;; ACCUMULATE-NODES-POST proof.

;; The well-formedness condition for the post-order accumulator is that for any
;; element of the list, all subtrees of the element must also be in the list:
(defun-sk subnode-lst-complete (lst)
  (forall (x y)
          ;; If x is an element of lst and y is a node of x,
          ;; then y must be in lst.
          (implies (and (member x lst)
                        (member y (collect-nodes x)))
                   (member y lst))))

;; Trivial rule based on the above
(defthm subnode-lst-complete-rewrite
  (implies (and (subnode-lst-complete lst)
                (member x lst)
                (not (member y lst)))
           (not (member y (collect-nodes x))))
  :hints (("goal" :use subnode-lst-complete-necc)))

(in-theory (disable subnode-lst-complete-necc))

;; This holds of collect-nodes.  This is basically a transitivity property.
(defthm subnode-is-transitive
  (implies (and (member x (collect-nodes y))
                (member y (collect-nodes z)))
           (member x (collect-nodes z)))
  :hints (("goal" :induct (collect-nodes z)))
  :rule-classes ((:rewrite :match-free :all)))

(defthm subnode-lst-complete-of-collect-nodes
  (subnode-lst-complete (collect-nodes a)))

(in-theory (disable subnode-lst-complete))


;; To prove our desired result, we really actually need a mutual induction with
;; another theorem, that accumulate-nodes-post preserves subnode-lst-complete
;; of the accumulator.  This mutual-recursion defines the induction scheme:
(mutual-recursion
 (defun-nx accumulate-nodes-post-member-ind (a lst x)
   ;; Each call of this function instantiates the following induction hyp:
   ;; (implies (subnode-lst-complete lst)
   ;;          (let ((lst2 (accumulate-nodes-post a lst)))
   ;;            (iff (member x lst2)
   ;;                 (or (member x lst)
   ;;                     (member x (collect-nodes a))))))
   (declare (ignorable x)
            (xargs :measure (* 2 (acl2-count a))))
   (b* (((when (atom a)) lst)
        ((when (eq (cdr a) nil))
         (accumulate-nodes-post-member-ind (car a) lst x))
        ((when (member a lst)) lst)
        (lst2 (accumulate-nodes-post (car a) lst)))
     (list (accumulate-nodes-post-member-ind (car a) lst x)
           (accumulate-nodes-post-member-ind (cdr a) lst2 x)
           (accumulate-nodes-post-complete-ind (car a) lst))))

 (defun-nx accumulate-nodes-post-complete-ind (a lst)
   ;; Each call of this function instantiates the following induction hyp:
   ;; (implies (subnode-lst-complete lst)
   ;;          (let ((lst2 (accumulate-nodes-post a lst)))
   ;;            (subnode-lst-complete lst2)))
   (declare (xargs :measure (+ 1 (* 2 (acl2-count a)))))
   (mv-let (ax ay)
     (subnode-lst-complete-witness (accumulate-nodes-post a lst))
     (list (accumulate-nodes-post-member-ind a lst ax)
           (accumulate-nodes-post-member-ind a lst ay)))))

(flag::make-flag accumulate-nodes-post-flg accumulate-nodes-post-member-ind)

;; The mutually inductive theorems:
(defthm-accumulate-nodes-post-flg
  (defthm member-of-accumulate-nodes-post
    (implies (subnode-lst-complete lst)
             (let ((lst2 (accumulate-nodes-post a lst)))
               (iff (member x lst2)
                    (or (member x lst)
                        (member x (collect-nodes a))))))
    :flag accumulate-nodes-post-member-ind)

  (defthm accumulate-nodes-post-complete
    (implies (subnode-lst-complete lst)
             (let ((lst2 (accumulate-nodes-post a lst)))
               (subnode-lst-complete lst2)))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause))))))
    :flag accumulate-nodes-post-complete-ind))

;; The empty list is complete:
(defthm subnode-lst-complete-of-empty
  (subnode-lst-complete nil)
  :hints (("goal" :in-theory (enable subnode-lst-complete))))


(defthm accumulate-nodes-post-under-set-equivp
  (implies (subnode-lst-complete lst)
           (set-equivp (accumulate-nodes-post a lst)
                       (append (collect-nodes a) lst)))
  :hints ((set-reasoning)))

(defthm accumulate-nodes-post-reduces-to-collect-nodes
  (set-equivp (accumulate-nodes-post a nil)
              (collect-nodes a)))

(in-theory (disable accumulate-nodes-post))



;;---------------------------------------------------------------------------
;; ACCUMULATE-NODES-PRE proof.

;; The well-formedness condition for the pre-order accumulator is a little
;; harder -- when run on a, the accumulator must be complete for subnodes of
;; a.  That is, if x is a subnode of a, and x is in the accumulator, then any
;; subnode of x must also be in the accumulator.

;; This is just like subnode-lst-complete, but restricts x to be a subnode of a.
(defun-sk subnode-lst-complete-for-subnodes (a lst)
  (forall (x y)
          (implies (and (member x (collect-nodes a))
                        (member x lst)
                        (member y (collect-nodes x)))
                   (member y lst))))

(defthm subnode-lst-complete-for-subnodes-rewrite
  (implies (and (subnode-lst-complete-for-subnodes a lst)
                (member x (collect-nodes a))
                (member x lst)
                (not (member y lst)))
           (not (member y (collect-nodes x))))
  :hints (("goal" :use subnode-lst-complete-for-subnodes-necc)))

(in-theory (disable subnode-lst-complete-for-subnodes-necc))


;; Holds of collect-nodes:
(defthm subnode-lst-complete-for-subnodes-of-collect-nodes
  (subnode-lst-complete-for-subnodes b (collect-nodes a)))

(in-theory (disable subnode-lst-complete-for-subnodes))


;; As with accumulate-nodes-post, we need a mutual induction with another
;; theorem -- that accumulate-nodes-pre preserves
;; subnode-lst-complete-for-subnodes.  The form of this second theorem is a
;; little different this time -- we prove that the property is preserved for
;; any node b as long as it also initially holds for the node a on which
;; accumulate-nodes-pre is run.
(mutual-recursion
 (defun-nx accumulate-nodes-pre-member-ind (a lst x)
   ;; Each call of this function instantiates the following induction hyp:
   ;; (implies (subnode-lst-complete-for-subnodes a lst)
   ;;          (let ((lst2 (accumulate-nodes-pre a lst)))
   ;;            (iff (member x lst2)
   ;;                 (or (member x lst)
   ;;                     (member x (collect-nodes a))))))
   (declare (ignorable x)
            (xargs :measure (* 2 (acl2-count a))))
   (b* (((when (atom a)) lst)
        ((when (eq (cdr a) nil))
         (accumulate-nodes-pre-member-ind (car a) lst x))
        ((when (member a lst)) lst)
        (lst2 (cons a lst))
        (lst3 (accumulate-nodes-pre (car a) lst2)))
     (list (accumulate-nodes-pre-member-ind (car a) lst2 x)
           (accumulate-nodes-pre-member-ind (cdr a) lst3 x)
           (accumulate-nodes-pre-complete-ind (car a) (cdr a) lst2))))

 (defun-nx accumulate-nodes-pre-complete-ind (a b lst)
   ;; Each call of this function instantiates the following induction hyp:
   ;; (implies (and (subnode-lst-complete-for-subnodes a lst)
   ;;               (subnode-lst-complete-for-subnodes b lst))
   ;;          (let ((lst2 (accumulate-nodes-pre a lst)))
   ;;            (subnode-lst-complete-for-subnodes b lst2)))
   (declare (xargs :measure (+ 1 (* 2 (acl2-count a)))))
   (mv-let (ax ay)
     (subnode-lst-complete-for-subnodes-witness b (accumulate-nodes-pre a lst))
     (list (accumulate-nodes-pre-member-ind a lst ax)
           (accumulate-nodes-pre-member-ind a lst ay)))))

(flag::make-flag accumulate-nodes-pre-flg accumulate-nodes-pre-member-ind)

(defthm subnode-lst-complete-for-subnodes-of-car-a
  (implies (subnode-lst-complete-for-subnodes a lst)
           (subnode-lst-complete-for-subnodes (car a) lst))
  :hints (("goal" :expand ((subnode-lst-complete-for-subnodes (car a) lst))
           :use ((:instance
                  subnode-lst-complete-for-subnodes-necc
                  (x (mv-nth 0 (subnode-lst-complete-for-subnodes-witness
                                (car a) lst)))
                  (y (mv-nth 1 (subnode-lst-complete-for-subnodes-witness
                                (car a) lst)))))
           :in-theory (disable subnode-lst-complete-for-subnodes-rewrite))))

(defthm subnode-lst-complete-for-subnodes-of-cdr-a
  (implies (subnode-lst-complete-for-subnodes a lst)
           (subnode-lst-complete-for-subnodes (cdr a) lst))
  :hints (("goal" :expand ((subnode-lst-complete-for-subnodes (cdr a) lst))
           :use ((:instance
                  subnode-lst-complete-for-subnodes-necc
                  (x (mv-nth 0 (subnode-lst-complete-for-subnodes-witness
                                (cdr a) lst)))
                  (y (mv-nth 1 (subnode-lst-complete-for-subnodes-witness
                                (cdr a) lst)))))
           :in-theory (disable subnode-lst-complete-for-subnodes-rewrite))))

(defthm subnode-lst-complete-for-subnodes-cons-non-subnode
  (implies (and (subnode-lst-complete-for-subnodes a lst)
                (not (member k (collect-nodes a))))
           (subnode-lst-complete-for-subnodes a (cons k lst)))
  :hints ((and stable-under-simplificationp
               `(:expand (,(car (last clause)))))))

(defthm subnodes-smaller-or-equal
  (implies (and (<= (acl2-count x) (acl2-count y))
                (not (equal x y)))
           (not (member y (collect-nodes x)))))

(defthm a-is-not-a-subnode-of-car-a
  (not (member a (collect-nodes (car a)))))

(defthm a-is-not-a-subnode-of-cdr-a
  (not (member a (collect-nodes (cdr a)))))

(in-theory (disable subnodes-smaller-or-equal))

(defthm subnode-of-and-node-when-in-lst
  (implies (and (subnode-lst-complete-for-subnodes a lst)
                (consp a) (cdr a)
                (member a lst)
                (not (member x lst)))
           (not (member x (collect-nodes a))))
  :hints (("goal" 
           :use ((:instance
                  subnode-lst-complete-for-subnodes-necc
                  (x a)
                  (y x)))
           :in-theory (disable subnode-lst-complete-for-subnodes-rewrite))))
  

;; The mutually inductive theorems:
(defthm-accumulate-nodes-pre-flg
  (defthm member-of-accumulate-nodes-pre
    (implies (subnode-lst-complete-for-subnodes a lst)
             (let ((lst2 (accumulate-nodes-pre a lst)))
               (iff (member x lst2)
                    (or (member x lst)
                        (member x (collect-nodes a))))))
    :flag accumulate-nodes-pre-member-ind)

  (defthm accumulate-nodes-pre-complete
    (implies (and (subnode-lst-complete-for-subnodes a lst)
                  (subnode-lst-complete-for-subnodes b lst))
             (let ((lst2 (accumulate-nodes-pre a lst)))
               (subnode-lst-complete-for-subnodes b lst2)))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause))))))
    :flag accumulate-nodes-pre-complete-ind))



;; The empty list is complete:
(defthm subnode-lst-complete-for-subnodes-of-empty
  (subnode-lst-complete-for-subnodes a nil)
  :hints (("goal" :in-theory (enable subnode-lst-complete-for-subnodes))))


(defthm accumulate-nodes-pre-under-set-equivp
  (implies (subnode-lst-complete-for-subnodes a lst)
           (set-equivp (accumulate-nodes-pre a lst)
                       (append (collect-nodes a) lst)))
  :hints ((set-reasoning)))

(defthm accumulate-nodes-pre-reduces-to-collect-nodes
  (set-equivp (accumulate-nodes-pre a nil)
              (collect-nodes a)))

(in-theory (disable accumulate-nodes-pre))





;;---------------------------------------------------------------------------
;; ACCUMULATE-AIG-VARS proof.

;; We now prove that the nodetable of accumulate-aig-vars is just
;; accumulate-nodes-pre.

(defthm accumulate-aig-vars-nodetable-is-accumulate-nodes-pre
  (equal (alist-keys (mv-nth 0 (accumulate-aig-vars a nodetable acc)))
         (accumulate-nodes-pre a (alist-keys nodetable)))
  :hints(("Goal" :in-theory (enable accumulate-nodes-pre
                                    accumulate-aig-vars))))

(defthm lookup-in-nodetable-is-subnode
  (implies (subnode-lst-complete-for-subnodes a (alist-keys nodetable))
           (iff (hons-assoc-equal x (mv-nth 0 (accumulate-aig-vars a nodetable acc)))
                (or (member x (collect-nodes a))
                    (hons-assoc-equal x nodetable))))
  :hints (("goal" :use accumulate-aig-vars-nodetable-is-accumulate-nodes-pre
           :in-theory (e/d (hons-assoc-equal-iff-member-alist-keys)
                           (alist-keys-member-hons-assoc-equal
                            accumulate-aig-vars-nodetable-is-accumulate-nodes-pre)))))

;; For the vars part, we need another invariant:  that the variable accumulator
;; contains all the variables present in subtrees of x in the nodetable.

(defun-sk var-lst-complete-for-subnodes (a nodes vars)
  (forall (v n)
          (implies (and (member n (collect-nodes a))
                        (member n nodes)
                        (member v (aig-vars n)))
                   (member v vars))))

;; Lemmas about var-lst-complete-for-subnodes
(in-theory (disable var-lst-complete-for-subnodes
                    var-lst-complete-for-subnodes-necc))

(defthm var-lst-complete-for-subnodes-rw
  (implies (and (var-lst-complete-for-subnodes a nodes vars)
                (member n (collect-nodes a))
                (member n nodes)
                (not (member v vars)))
           (not (member v (aig-vars n))))
  :hints (("goal" :use var-lst-complete-for-subnodes-necc))
  :rule-classes ((:rewrite :match-free :all)))

(defcong set-equivp equal (var-lst-complete-for-subnodes a nodes vars) 2
  :hints (("goal" :cases ((var-lst-complete-for-subnodes a nodes vars)))
          (and stable-under-simplificationp
               (append
                (if (eq (caar clause) 'not)
                    `(:expand (,(car (last clause))))
                  `(:expand (,(car clause))))))))

(defcong set-equivp equal (var-lst-complete-for-subnodes a nodes vars) 3
  :hints (("goal" :cases ((var-lst-complete-for-subnodes a nodes vars)))
          (and stable-under-simplificationp
               (append
                (if (eq (caar clause) 'not)
                    `(:expand (,(car (last clause))))
                  `(:expand (,(car clause))))))))

(in-theory (disable var-lst-complete-for-subnodes-rw))

(defthm var-lst-complete-for-subnodes-of-car-a
  (implies (var-lst-complete-for-subnodes a nodes vars)
           (var-lst-complete-for-subnodes (car a) nodes vars))
  :hints (("goal" :expand ((var-lst-complete-for-subnodes (car a) nodes vars))
           :use ((:instance
                  var-lst-complete-for-subnodes-necc
                  (v (mv-nth 0 (var-lst-complete-for-subnodes-witness
                                (car a) nodes vars)))
                  (n (mv-nth 1 (var-lst-complete-for-subnodes-witness
                                (car a) nodes vars))))))))

(defthm var-lst-complete-for-subnodes-of-cdr-a
  (implies (var-lst-complete-for-subnodes a nodes vars)
           (var-lst-complete-for-subnodes (cdr a) nodes vars))
  :hints (("goal" :expand ((var-lst-complete-for-subnodes (cdr a) nodes vars))
           :use ((:instance
                  var-lst-complete-for-subnodes-necc
                  (v (mv-nth 0 (var-lst-complete-for-subnodes-witness
                                (cdr a) nodes vars)))
                  (n (mv-nth 1 (var-lst-complete-for-subnodes-witness
                                (cdr a) nodes vars))))))))

(defthm var-lst-complete-for-subnodes-cons-non-subnode
  (implies (and (var-lst-complete-for-subnodes a nodes vars)
                (not (member k (collect-nodes a))))
           (var-lst-complete-for-subnodes a (cons k nodes) vars))
  :hints ((and stable-under-simplificationp
               `(:expand (,(car (last clause)))
                 :use ((:instance var-lst-complete-for-subnodes-necc
                        (v (mv-nth 0 (var-lst-complete-for-subnodes-witness
                                      a (cons k nodes) vars)))
                        (n (mv-nth 1 (var-lst-complete-for-subnodes-witness
                                      a (cons k nodes) vars)))))
                 :do-not-induct t))))


(defthm var-lst-complete-for-var
  (implies (and (var-lst-complete-for-subnodes a nodes vars)
                (not (consp a))
                a
                (not (equal a t))
                (member a nodes))
           (member a vars))
  :hints (("goal" :use ((:instance var-lst-complete-for-subnodes-necc
                         (n a) (v a)))))
  :rule-classes ((:rewrite :match-free :all)))

(defthm var-lst-complete-for-and
  (implies (and (var-lst-complete-for-subnodes a nodes vars)
                (consp a)
                (cdr a)
                (member a nodes)
                (not (member v vars)))
           (not (member v (aig-vars a))))
  :hints (("goal" :use ((:instance var-lst-complete-for-subnodes-necc
                         (n a)))))
  :rule-classes ((:rewrite :match-free :all)))


;; Similar to the proof about accumulate-nodes-pre.  The first mutually
;; inductive theorem says that a variable gets accumulated into vars iff it is a
;; member of aig-vars.  The second says that accumulate-aig-vars preserves the
;; var-lst-complete-for-subnodes property for arbitrary node b, as long
;; as it holds for node a that accumulate-aig-vars is running on.
(mutual-recursion
 (defun-nx accumulate-aig-vars-member-ind (a nodetable vars x)
   (declare (ignorable x)
            (xargs :measure (* 2 (acl2-count a))))
   (b* (((when (atom a)) vars)
        ((when (eq (cdr a) nil))
         (accumulate-aig-vars-member-ind (car a) nodetable vars x))
        ((when (hons-get a nodetable)) vars)
        (nodetable1 (hons-acons a t nodetable))
        ((mv nodetable2 vars2)
         (accumulate-aig-vars (car a) nodetable1 vars)))
     (list (accumulate-aig-vars-member-ind (car a) nodetable1 vars x)
           (accumulate-aig-vars-member-ind (cdr a) nodetable2 vars2 x)
           (accumulate-aig-vars-complete-ind (car a) (cdr a) nodetable1
                                             vars))))
 (defun-nx accumulate-aig-vars-complete-ind (a b nodetable vars)
   (declare (xargs :measure (+ 1 (* 2 (acl2-count a)))))
   (b* (((mv ?nodetable1 vars1)
         (accumulate-aig-vars a nodetable vars))
        (nodetable-keys (append (alist-keys nodetable)
                                (collect-nodes a)))
        ((mv v ?n)
         (var-lst-complete-for-subnodes-witness
          b nodetable-keys vars1)))
     (accumulate-aig-vars-member-ind a nodetable vars v))))

(flag::make-flag accumulate-aig-vars-flg accumulate-aig-vars-member-ind)


(in-theory (enable var-lst-complete-for-subnodes-rw))

(local (in-theory (e/d (hons-assoc-equal-iff-member-alist-keys)
                       (alist-keys-member-hons-assoc-equal))))

(defthm variable-of-subnode-trans
  (implies (and (member v (aig-vars n))
                (member n (collect-nodes a)))
           (member v (aig-vars a)))
  :rule-classes ((:rewrite :match-free :all)))



(defthm-accumulate-aig-vars-flg
  (defthm member-of-accumulate-aig-vars
    (implies (and (var-lst-complete-for-subnodes a (alist-keys nodetable) vars)
                  (subnode-lst-complete-for-subnodes a (alist-keys nodetable)))
             (let ((vars2 (mv-nth 1 (accumulate-aig-vars a nodetable vars))))
               (iff (member x vars2)
                    (or (member x (aig-vars a))
                        (member x vars)))))
    ;; :hints ((and stable-under-simplificationp
    ;;              '(:expand ((accumulate-aig-vars a nodetable vars)))))
    :flag accumulate-aig-vars-member-ind)
  (defthm accumulate-aig-vars-preserves-complete
    (implies (and (var-lst-complete-for-subnodes b (alist-keys nodetable) vars)
                  (var-lst-complete-for-subnodes a (alist-keys nodetable) vars)
                  (subnode-lst-complete-for-subnodes a (alist-keys nodetable)))
             (mv-let (nodetable2 vars2)
               (accumulate-aig-vars a nodetable vars)
               (var-lst-complete-for-subnodes b (alist-keys nodetable2) vars2)))
    :hints ((and stable-under-simplificationp
                 `(:expand (,(car (last clause))))))
    :flag accumulate-aig-vars-complete-ind))



;; The empty subnode list makes any var list complete:
(defthm var-lst-complete-for-subnodes-of-empty
  (var-lst-complete-for-subnodes a nil vars)
  :hints (("goal" :in-theory (enable var-lst-complete-for-subnodes))))


(defthm accumulate-aig-vars-under-set-equivp
  (implies (and (var-lst-complete-for-subnodes a (alist-keys nodetable) vars)
                (subnode-lst-complete-for-subnodes a (alist-keys nodetable)))
           (set-equivp (mv-nth 1 (accumulate-aig-vars a nodetable vars))
                       (append (aig-vars a) vars)))
  :hints ((set-reasoning)))

(defthm accumulate-aig-vars-reduces-to-aig-vars
  (set-equivp (mv-nth 1 (accumulate-aig-vars a nil nil))
              (aig-vars a)))

(in-theory (disable accumulate-aig-vars))


;;---------------------------------------------------------------------------
;; ACCUMULATE-AIG-VARS is duplicate-free proof.

;; Invariant for this is just that the variables are duplicate-free, and any
;; variable present is present in the nodetable.

(defthm accumulate-aig-vars-duplicate-free
  (implies (and (no-duplicatesp vars)
                (subsetp-equal vars (alist-keys nodetable)))
           (b* (((mv nodetable vars)
                 (accumulate-aig-vars a nodetable vars)))
             (and (no-duplicatesp vars)
                  (subsetp-equal vars (alist-keys nodetable)))))
  :hints(("Goal" :in-theory (enable accumulate-aig-vars)
          :induct t)
         (set-reasoning)))



