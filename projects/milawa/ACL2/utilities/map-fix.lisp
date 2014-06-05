;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           __    __        __    __                                        ;;
;;          /  \  /  \      (__)  |  |    ____   ___      __    ____         ;;
;;         /    \/    \      __   |  |   / _  |  \  \ __ /  /  / _  |        ;;
;;        /  /\    /\  \    |  |  |  |  / / | |   \  '  '  /  / / | |        ;;
;;       /  /  \__/  \  \   |  |  |  |  \ \_| |    \  /\  /   \ \_| |        ;;
;;      /__/          \__\  |__|  |__|   \____|     \/  \/     \____|        ;;
;; ~ ~~ \  ~ ~  ~_~~ ~/~ /~ | ~|~ | ~| ~ /~_ ~|~ ~  ~\  ~\~ ~  ~ ~  |~~    ~ ;;
;;  ~ ~  \~ \~ / ~\~ / ~/ ~ |~ | ~|  ~ ~/~/ | |~ ~~/ ~\/ ~~ ~ / / | |~   ~   ;;
;; ~ ~  ~ \ ~\/ ~  \~ ~/ ~~ ~__|  |~ ~  ~ \_~  ~  ~  .__~ ~\ ~\ ~_| ~  ~ ~~  ;;
;;  ~~ ~  ~\  ~ /~ ~  ~ ~  ~ __~  |  ~ ~ \~__~| ~/__~   ~\__~ ~~___~| ~ ~    ;;
;; ~  ~~ ~  \~_/  ~_~/ ~ ~ ~(__~ ~|~_| ~  ~  ~~  ~  ~ ~~    ~  ~   ~~  ~  ~  ;;
;;                                                                           ;;
;;            A   R e f l e c t i v e   P r o o f   C h e c k e r            ;;
;;                                                                           ;;
;;       Copyright (C) 2005-2009 by Jared Davis <jared@cs.utexas.edu>        ;;
;;                                                                           ;;
;; This program is free software; you can redistribute it and/or modify it   ;;
;; under the terms of the GNU General Public License as published by the     ;;
;; Free Software Foundation; either version 2 of the License, or (at your    ;;
;; option) any later version.                                                ;;
;;                                                                           ;;
;; This program is distributed in the hope that it will be useful, but       ;;
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABIL-  ;;
;; ITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public      ;;
;; License for more details.                                                 ;;
;;                                                                           ;;
;; You should have received a copy of the GNU General Public License along   ;;
;; with this program (see the file COPYING); if not, write to the Free       ;;
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA    ;;
;; 02110-1301, USA.                                                          ;;
;;                                                                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MILAWA")
(include-book "utilities")
(include-book "cons-listp")
(set-verify-guards-eagerness 2)
(set-case-split-limitations nil)
(set-well-founded-relation ord<)
(set-measure-function rank)

;; NOTE: this isn't actually included in top.lisp yet, because I don't want
;; to wait an hour for everything to recertify.

(defund map-fix (x)
  (declare (xargs :guard t))
  (if (consp x)
      (cons (cons-fix (car x))
            (map-fix (cdr x)))
    nil))

(defthm map-fix-when-not-consp
  (implies (not (consp x))
           (equal (map-fix x)
                  nil))
  :hints(("Goal" :in-theory (enable map-fix))))

(defthm map-fix-of-cons
  (equal (map-fix (cons a x))
         (cons (cons-fix a)
               (map-fix x)))
  :hints(("Goal" :in-theory (enable map-fix))))

(defthm map-fix-under-iff
  (iff (map-fix x)
       (consp x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm consp-of-map-fix
  (equal (consp (map-fix x))
         (consp x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm mapp-of-map-fix
  (equal (mapp (map-fix x))
         t)
  :hints(("Goal" :induct (cdr-induction x))))

(defthm true-listp-of-map-fix
  (equal (true-listp (map-fix x))
         t)
  :hints(("Goal" :induct (cdr-induction x))))

(defthm map-fix-of-list-fix
  (equal (map-fix (list-fix x))
         (map-fix x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm map-fix-of-map-fix
  (equal (map-fix (map-fix x))
         (map-fix x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm map-fix-when-mapp
  (implies (mapp x)
           (equal (map-fix x)
                  (list-fix x)))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm map-fix-of-app
  (equal (map-fix (app x y))
         (app (map-fix x)
              (map-fix y)))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm map-fix-of-rev
  (equal (map-fix (rev x))
         (rev (map-fix x)))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm lookup-of-map-fix
  (equal (lookup a (map-fix x))
         (lookup a x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm domain-of-map-fix
  (equal (domain (map-fix x))
         (domain x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm range-of-map-fix
  (equal (range (map-fix x))
         (range x))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm submapp1-of-map-fix-left
  (equal (submapp1 domain (map-fix x) y)
         (submapp1 domain x y))
  :hints(("Goal" :induct (cdr-induction domain))))

(defthm submapp1-of-map-fix-right
  (equal (submapp1 domain x (map-fix y))
         (submapp1 domain x y))
  :hints(("Goal" :induct (cdr-induction domain))))

(defthm submapp-of-map-fix-left
  (equal (submapp (map-fix x) y)
         (submapp x y))
  :hints(("Goal" :in-theory (enable submapp))))

(defthm submapp-of-map-fix-right
  (equal (submapp (map-fix x) y)
         (submapp x y))
  :hints(("Goal" :in-theory (enable submapp))))

(defthm cons-listp-of-map-fix
  (equal (cons-listp (map-fix x))
         t)
  :hints(("Goal" :induct (cdr-induction x))))

(defthm memberp-of-map-fix-when-memberp
  (implies (memberp a x)
           (equal (memberp a (map-fix x))
                  (consp a)))
  :hints(("Goal" :induct (cdr-induction x))))

(defthm subsetp-of-map-fix-when-subsetp
  (implies (subsetp x y)
           (equal (subsetp x (map-fix y))
                  (cons-listp x)))
  :hints(("Goal" :induct (cdr-induction x))))
