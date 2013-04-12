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


(in-package "ACL2")

;; This book proves that F-PUT-GLOBAL preserves STATE-P1, allowing it to be
;; used in guard-verified recursive logic-mode functions.

(local
 (progn
   (defthm all-boundp-add-pair
     (implies (all-boundp al1 al2)
              (all-boundp al1 (add-pair kay val al2))))

   (in-theory (disable all-boundp add-pair))

   (in-theory (disable open-channels-p
                       ordered-symbol-alistp
                       plist-worldp
                       symbol-alistp
                       timer-alistp
                       known-package-alistp
                       true-listp
                       32-bit-integer-listp
                       integer-listp
                       file-clock-p
                       readable-files-p
                       written-files-p
                       read-files-p
                       writeable-files-p
                       true-list-listp))))

(defund state-p1-good-worldp (world)
  (and (plist-worldp world)
       (symbol-alistp
        (getprop 'acl2-defaults-table
                 'table-alist
                 nil 'current-acl2-world
                 world))
       (known-package-alistp
        (getprop 'known-package-alist
                 'global-value
                 nil 'current-acl2-world
                 world))))

(defthm state-p1-put-global
  (implies (and (state-p1 state)
                (symbolp key)
                (cond ((eq key 'current-acl2-world) (state-p1-good-worldp val))
                      ((eq key 'timer-alist) (timer-alistp val))
                      (t)))
           (state-p1 (put-global key val state)))
  :hints(("Goal" :in-theory (enable state-p1 state-p1-good-worldp))))

(defthm assoc-equal-add-pair
  (equal (assoc-equal k1 (add-pair k2 v al))
         (if (equal k1 k2)
             (cons k2 v)
           (assoc-equal k1 al)))
  :hints(("Goal" :in-theory (enable add-pair))))

(defthm get-global-of-put-global
  (equal (get-global k1 (put-global k2 val state))
         (if (equal k1 k2)
             val
           (get-global k1 state))))

(defthm boundp-global1-of-put-global
  (equal (boundp-global1 k1 (put-global k2 val state))
         (or (equal k1 k2)
             (boundp-global1 k1 state))))

(in-theory (disable boundp-global1 get-global put-global))

(defthmd not-in-ordered-symbol-alist-when-not-symbol
  (implies (and (ordered-symbol-alistp a)
                (not (symbolp k)))
           (not (assoc k a)))
  :hints(("Goal" :in-theory (enable ordered-symbol-alistp))))

(defthmd not-in-ordered-symbol-alist-when-<-first
  (implies (and (ordered-symbol-alistp a)
                (symbol-< k (caar a)))
           (not (assoc k a)))
  :hints (("goal" :induct (ordered-symbol-alistp a)
           :in-theory (enable not-in-ordered-symbol-alist-when-not-symbol
                              ordered-symbol-alistp))))

(defthm add-pair-same
  (implies (and (ordered-symbol-alistp a)
                (assoc k a))
           (equal (add-pair k (cdr (assoc k a)) a)
                  a))
  :hints(("Goal" :in-theory (enable not-in-ordered-symbol-alist-when-<-first
                                    not-in-ordered-symbol-alist-when-not-symbol
                                    ordered-symbol-alistp
                                    add-pair)
          :induct t)
         (and stable-under-simplificationp
              '(:cases ((symbolp k))))))


(local
 (defthm update-nth-same
   (implies (< (nfix n) (len x))
            (equal (update-nth n (nth n x) x)
                   x))))

(defthm put-global-of-same
  (implies (and (state-p1 state)
                (boundp-global1 k state))
           (equal (put-global k (get-global k state) state)
                  state))
  :hints(("Goal" :in-theory (enable get-global put-global
                                    boundp-global1
                                    state-p1))))

(defconst *basic-well-formed-state*
  (list nil ;; open-input-channels
        nil ;; open-output-channels
        *initial-global-table* ;; global-table
        nil ;; t-stack
        nil ;; 32-bit-integer-stack
        0   ;; big-clock-entry
        nil ;; idates
        nil ;; acl2-oracle
        0   ;; file-clock
        nil ;; readable-files
        nil ;; written-files
        nil ;; read-files
        nil ;; writable-files
        nil ;; list-all-package-names-lst
        nil ;; user-stobj-alist1
        ))

(local (defthm state-p1-of-basic-well-formed-state
         (state-p1 *basic-well-formed-state*)))


;; It might be nice to make this more transparent to the various state
;; accessors so that, e.g.,
;; (get-global x (state-fix state)) = (get-global x state).
;; But that's more complicated since we'd need an appropriate fixing function
;; for each field.
(defund state-fix (state)
  (declare (xargs :stobjs state))
  (mbe :logic (non-exec (if (state-p state)
                            state
                          *basic-well-formed-state*))
       :exec state))

(defthm state-p1-of-state-fix
  (state-p1 (state-fix state))
  :hints(("Goal" :in-theory (enable state-fix))))

(defthm state-fix-when-state-p1
  (implies (state-p1 state)
           (equal (state-fix state)
                  state))
  :hints(("Goal" :in-theory (enable state-fix))))


