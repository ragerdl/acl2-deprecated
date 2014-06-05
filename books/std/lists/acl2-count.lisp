; acl2-count of lists
;
; These theorems are proved so often that I don't think there's any sense
; copyrighting them.

; Not sure if it's best to put theorems about acl2-count of other list-related
; stuff here or in the books for the various list functions, e.g., there's some
; stuff about acl2-count of nthcdr in the nthcdr book.  For now here are some
; lemmas about car and cdr that are all over the place.

; It looks like there aren't any exact name clashes -- some overlap in
; centaur/vl/util/arithmetic, but in the VL package.

(in-package "ACL2")

(defthm acl2-count-of-car
  (and (implies (consp x)
                (< (acl2-count (car x))
                   (acl2-count x)))
       (<= (acl2-count (car x))
           (acl2-count x)))
  :hints(("Goal" :in-theory (enable acl2-count)))
  :rule-classes :linear)

(defthm acl2-count-of-cdr
  (and (implies (consp x)
                (< (acl2-count (cdr x))
                   (acl2-count x)))
       (<= (acl2-count (cdr x))
           (acl2-count x)))
  :hints(("Goal" :in-theory (enable acl2-count)))
  :rule-classes :linear)

(defthm acl2-count-of-consp-positive
  (implies (consp x)
           (< 0 (acl2-count x)))
  :rule-classes (:type-prescription :linear))

(defthm acl2-count-of-cons
  (> (acl2-count (cons a b))
     (+ (acl2-count a) (acl2-count b)))
  :rule-classes :linear)
