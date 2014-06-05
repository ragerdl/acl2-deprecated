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
(include-book "eqtracep")
(set-verify-guards-eagerness 2)
(set-case-split-limitations nil)
(set-well-founded-relation ord<)
(set-measure-function rank)



(definlined rw.secondary-eqtrace (okp nhyp)
  ;; Generate a secondary eqtrace from an nhyp.  No matter what the nhyp is, we
  ;; are assuming it is false, so we infer nhyp = nil.  We don't bother to do
  ;; this if nhyp is nil, since nil = nil is trivially known.
  (declare (xargs :guard (logic.termp nhyp)))
  (and okp
       (not (equal nhyp ''nil))
       (if (logic.term-< ''nil nhyp)
           (rw.eqtrace 'secondary nil ''nil nhyp nil)
         (rw.eqtrace 'secondary nil nhyp ''nil nil))))

(encapsulate
 ()
 (local (in-theory (e/d (rw.secondary-eqtrace)
                        (forcing-booleanp-of-rw.eqtrace->iffp))))

 (defthm forcing-rw.eqtrace->method-of-rw.secondary-eqtrace
   (implies (force (rw.secondary-eqtrace okp nhyp))
            (equal (rw.eqtrace->method (rw.secondary-eqtrace okp nhyp))
                   'secondary)))

 (defthm forcing-rw.eqtrace->iffp-of-rw.secondary-eqtrace
   (implies (force (rw.secondary-eqtrace okp nhyp))
            (equal (rw.eqtrace->iffp (rw.secondary-eqtrace okp nhyp))
                   nil)))

 (defthm forcing-rw.eqtrace->subtraces-of-rw.secondary-eqtrace
   (implies (force (rw.secondary-eqtrace okp nhyp))
            (equal (rw.eqtrace->subtraces (rw.secondary-eqtrace okp nhyp))
                   nil)))

 (defthm forcing-rw.eqtracep-of-rw.secondary-eqtrace
   (implies (force (and (rw.secondary-eqtrace okp nhyp)
                        (logic.termp nhyp)))
            (equal (rw.eqtracep (rw.secondary-eqtrace okp nhyp))
                   t)))

 (defthm rw.secondary-eqtrace-normalize-okp-1
   (implies (and (rw.secondary-eqtrace okp nhyp)
                 (syntaxp (not (equal okp ''t))))
            (equal (rw.secondary-eqtrace okp nhyp)
                   (rw.secondary-eqtrace t nhyp))))

 (defthm rw.secondary-eqtrace-normalize-okp-2
   (implies (not (rw.secondary-eqtrace t nhyp))
            (equal (rw.secondary-eqtrace okp nhyp)
                   nil)))

 (defthm rw.secondary-eqtrace-normalize-okp-3
   (equal (rw.secondary-eqtrace nil nhyp)
          nil))

 (defthm forcing-rw.eqtrace-atblp-of-rw.secondary-eqtrace
   (implies (force (and (rw.secondary-eqtrace okp nhyp)
                        (logic.term-atblp nhyp atbl)))
            (equal (rw.eqtrace-atblp (rw.secondary-eqtrace okp nhyp) atbl)
                   t))))





(defund rw.find-nhyp-for-secondary-eqtracep (nhyps x)
  ;; Find the first nhyp in a list that would generate this secondary eqtrace.
  (declare (xargs :guard (and (logic.term-listp nhyps)
                              (rw.eqtracep x))))
  (if (consp nhyps)
      (if (equal (rw.secondary-eqtrace t (car nhyps)) x)
          (car nhyps)
        (rw.find-nhyp-for-secondary-eqtracep (cdr nhyps) x))
    nil))

(encapsulate
 ()
 (local (in-theory (enable rw.find-nhyp-for-secondary-eqtracep)))

 (defthm rw.find-nhyp-for-secondary-eqtracep-of-nil
   (equal (rw.find-nhyp-for-secondary-eqtracep nil x)
          nil))

 (defthm forcing-logic.termp-of-rw.find-nhyp-for-secondary-eqtracep
   (implies (force (and (rw.find-nhyp-for-secondary-eqtracep nhyps x)
                        (logic.term-listp nhyps)))
            (equal (logic.termp (rw.find-nhyp-for-secondary-eqtracep nhyps x))
                   t)))

 (defthm forcing-logic.term-atblp-of-rw.find-nhyp-for-secondary-eqtracep
   (implies (force (and (rw.find-nhyp-for-secondary-eqtracep nhyps x)
                        (logic.term-list-atblp nhyps atbl)))
            (equal (logic.term-atblp (rw.find-nhyp-for-secondary-eqtracep nhyps x) atbl)
                   t)))

 (defthm forcing-memberp-of-rw.find-nhyp-for-secondary-eqtracep
   (implies (force (rw.find-nhyp-for-secondary-eqtracep nhyps x))
            (equal (memberp (rw.find-nhyp-for-secondary-eqtracep nhyps x) nhyps)
                   t)))

 (defthm forcing-rw.secondary-eqtrace-of-rw.find-nhyp-for-secondary-eqtracep
   (implies (force (rw.find-nhyp-for-secondary-eqtracep nhyps x))
            (equal (rw.secondary-eqtrace t (rw.find-nhyp-for-secondary-eqtracep nhyps x))
                   x))))





(defund rw.secondary-eqtrace-okp (x box)
  ;; Check if any nhyp in the hypbox would generate this secondary eqtrace.
  (declare (xargs :guard (and (rw.eqtracep x)
                              (rw.hypboxp box))))
  (and (equal (rw.eqtrace->method x) 'secondary)
       (equal (rw.eqtrace->iffp x) nil)
       (if (or (rw.find-nhyp-for-secondary-eqtracep (rw.hypbox->left box) x)
               (rw.find-nhyp-for-secondary-eqtracep (rw.hypbox->right box) x))
           t
         nil)))

(encapsulate
 ()
 (local (in-theory (enable rw.secondary-eqtrace-okp)))

 (defthm booleanp-of-rw.secondary-eqtrace-okp
   (equal (booleanp (rw.secondary-eqtrace-okp x box))
          t))

 (defthmd lemma-1-for-forcing-rw.secondary-eqtrace-okp-rw.secondary-eqtrace
   (implies (and (logic.termp a)
                 (logic.termp b))
            (equal (equal (rw.secondary-eqtrace okp a)
                          (rw.secondary-eqtrace okp b))
                   (if okp
                       (equal a b)
                     t)))
   :hints(("Goal" :in-theory (enable rw.secondary-eqtrace rw.eqtrace))))

 (defthmd lemma-2-for-forcing-rw.secondary-eqtrace-okp-rw.secondary-eqtrace
   (implies (and (logic.termp nhyp)
                 (logic.term-listp nhyps)
                 (memberp nhyp nhyps)
                 (rw.secondary-eqtrace okp nhyp))
            (iff (rw.find-nhyp-for-secondary-eqtracep nhyps (rw.secondary-eqtrace okp nhyp))
                 t))
   :hints(("Goal"
           :in-theory (e/d (rw.find-nhyp-for-secondary-eqtracep)
                           ((:e rw.secondary-eqtrace)))
           :induct (cdr-induction nhyps))))

(defthm forcing-rw.secondary-eqtrace-okp-rw.secondary-eqtrace
   (implies (force (and (rw.secondary-eqtrace okp nhyp)
                        (rw.hypboxp box)
                        (or (memberp nhyp (rw.hypbox->left box))
                            (memberp nhyp (rw.hypbox->right box)))))
            (equal (rw.secondary-eqtrace-okp (rw.secondary-eqtrace okp nhyp) box)
                   t))
   :hints(("Goal"
           :in-theory (e/d (lemma-1-for-forcing-rw.secondary-eqtrace-okp-rw.secondary-eqtrace
                            lemma-2-for-forcing-rw.secondary-eqtrace-okp-rw.secondary-eqtrace)
                           (rw.secondary-eqtrace-normalize-okp-1))
           ))))


