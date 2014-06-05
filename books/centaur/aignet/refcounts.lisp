; AIGNET - And-Inverter Graph Networks -- reference counting
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
; Original author: Sol Swords <sswords@centtech.com>

(in-package "AIGNET")

(include-book "arrays")
(include-book "centaur/misc/iter" :dir :system)
(local (include-book "clause-processors/just-expand" :dir :system))

(local (include-book "arithmetic/top-with-meta" :dir :system))
(local (in-theory (enable* acl2::arith-equiv-forwarding)))

(local (in-theory (disable nth update-nth
                           acl2::nth-with-large-index
                           true-listp-update-nth)))

(defstobj-clone aignet-refcounts u32arr :suffix "-COUNTS")

(defsection aignet-refcounts

  (defiteration aignet-count-refs (aignet-refcounts aignet)
    (declare (xargs :stobjs (aignet-refcounts aignet)
                    :guard (<= (num-nodes aignet) (u32-length aignet-refcounts))
                    :guard-hints ('(:do-not-induct t
                                    :in-theory (enable aignet-idp)))))
    (b* ((id n)
         (aignet-refcounts (set-u32 id 0 aignet-refcounts)))
      (aignet-case
       (id->type id aignet)
       :gate  (b* ((id0 (lit-id (gate-id->fanin0 id aignet)))
                   (id1 (lit-id (gate-id->fanin1 id aignet)))
                   (aignet-refcounts
                    (set-u32 id0 (+ 1 (get-u32 id0 aignet-refcounts))
                                 aignet-refcounts)))
                (set-u32 id1 (+ 1 (get-u32 id1 aignet-refcounts))
                             aignet-refcounts))
       :out (b* ((fid (lit-id (co-id->fanin id aignet))))
              (set-u32 fid (+ 1 (get-u32 fid aignet-refcounts)) aignet-refcounts))
       :in aignet-refcounts
       :const aignet-refcounts))
    :returns aignet-refcounts
    :index n
    :last (num-nodes aignet))

  (in-theory (disable aignet-count-refs))
  (local (in-theory (enable aignet-count-refs)))

  (defthm aignet-refcounts-sizedp-after-aignet-refcounts-iter
    (implies (< (node-count aignet) (len aignet-refcounts))
             (< (node-count aignet)
                (len (aignet-count-refs-iter n aignet-refcounts aignet))))
    :hints((acl2::just-induct-and-expand
            (aignet-count-refs-iter n aignet-refcounts aignet)))
    :rule-classes :linear)

  (defthm aignet-refcounts-sizedp-after-aignet-refcounts
    (implies (< (node-count aignet) (len aignet-refcounts))
             (< (node-count aignet) (len (aignet-count-refs aignet-refcounts aignet))))
    :rule-classes :linear))
