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


; follow-backwards.lisp -- tracing wires back to their "true" drivers
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "ACL2")
(include-book "esim-paths")
(local (include-book "esim-sexpr-support-thms"))

(defsection find-driving-occ

  (defund find-driving-occ (wire occs)
    (declare (xargs :guard t))
    (cond ((atom occs)
           nil)
          ((member-of-pat-flatten wire (gpl :o (car occs)))
           (car occs))
          (t
           (find-driving-occ wire (cdr occs)))))

  (local (in-theory (enable find-driving-occ)))

  (defthm member-of-find-driving-occ
    (implies (find-driving-occ wire occs)
             (member-equal (find-driving-occ wire occs) occs)))

  (defthm good-esim-occp-of-find-driving-occ
    (implies (good-esim-occsp occs)
             (equal (good-esim-occp (find-driving-occ wire occs))
                    (if (find-driving-occ wire occs)
                        t
                      nil)))))


(defsection follow-path-backwards
  :parents (mod-internal-paths)
  :short "@(call follow-path-backwards) can follow an ESIM path linearly
backwards (that is, through module boundaries, identity assignments,
buffers, and inverters) to its source."

  :long "<p><b>Signature:</b> @(call follow-path-backwards) returns <tt>(mv
new-path inverted-p)</tt>.</p>

<p>The given <tt>path</tt> should be a valid ESIM path into <tt>mod</tt>, which
should be a good ESIM module.  The path does NOT need to be canonical.</p>

<p>We follow path \"backwards\" to try to find out where it originates from.
For instance, suppose we started wtih a Verilog module like:</p>

<code>
module mymod (...) ;
   wire a = b;
   wire b = ~c;
   not(c, d);
   and(d, e, f);
   ...
endmodule
</code>

<p>Then, if we try to follow backwards starting from the initial path
<tt>a</tt>, we will walk through <tt>b</tt> and <tt>c</tt> until we reach
<tt>d</tt>.  We can't walk past <tt>d</tt> because it is driven by an AND
gate, and we only walk through buffers, inverters, and plain assignments.</p>

<p>The <tt>new-path</tt> we obtain is not necessarily canonical, but it should
always point to somewhere within <tt>mod</tt>.  The \"best\" we can do is to
follow a path all the way back to an input of <tt>mod</tt>.  But often the
resulting path may end up pointing somewhere into a submodule, e.g., suppose we
have:</p>

<code>
module sub (o1, o2, a, b) ;
  assign o1 = a | b;
  assign o2 = a &amp; b;
endmodule

module top (...) ;
  wire w1, w2;
  wire conjoin;
  wire disjoin;
  sub mysub (disjoin, conjoin, w1, w2);
  ...
endmodule
</code>

<p>Then if we start by following path <tt>disjoin</tt> in top, we will end up
with a new path that is <tt>(mysub . o1)</tt>.</p>

<p>The <tt>inverted-p</tt> output says whether we've gone through an odd number
of inverters.</p>"

  (defund follow-path-backwards-aux
    (path ; path we're currently trying to follow
     mod  ; E module that the path starts from
     invp ; have we gone through an odd number of inverters?
     steps ; counter to ensure termination
     )
    "Returns (MV PATH' INVP')"
    (declare (xargs :guard (and (natp steps)
                                (good-esim-modulep mod))
                    :measure (nfix steps)
                    :verify-guards nil))
    (b* (;; (- (cw "following ~x0 in ~x1~%" path (gpl :n mod)))

         ((when (zp steps))
          (er hard? 'follow-path-backwards-aux
              "Trying to resolve path ~x0 in module ~x1, but we ran out of ~
               steps.  Are we looping?  Giving up." path (gpl :n mod))
          (mv path invp))

         ((when (gpl :x mod))
          ;; Found a primitive.  If it drives OUT in a simple enough way, we
          ;; can resolve it.
          (b* ((sexpr (cdr (hons-assoc-equal path (gpl :out (gpl :x mod)))))

               ((when (and (atom sexpr)
                           (member-of-pat-flatten sexpr (gpl :i mod))))
                ;; OUT := IN --> new path is IN, invp remains the same
                (mv sexpr invp))

               ((when (and (consp sexpr)
                           (eq (first sexpr) 'acl2::buf)
                           (consp (cdr sexpr))
                           (atom (second sexpr))
                           (member-of-pat-flatten (second sexpr) (gpl :i mod))))
                ;; OUT := (BUF IN) --> new path is IN, invp remains the same
                (mv (second sexpr) invp))

               ((when (and (consp sexpr)
                           (eq (first sexpr) 'acl2::not)
                           (consp (cdr sexpr))
                           (atom (second sexpr))
                           (member-of-pat-flatten (second sexpr) (gpl :i mod))))
                ;; OUT := (NOT IN) --> new path is IN, with ~invp
                (mv (second sexpr) (not invp))))

            ;; OUT := something else, too hard, stop here.
            (mv path invp)))

         ((when (consp path))
          (b* (((cons head tail) path)
               (occ (cdr (hons-get head (make-fast-alist (occmap mod)))))
               ((unless occ)
                (er hard? 'follow-path-backwards-aux
                    "Trying to resolve path ~x0 in module ~x1, but there is ~
                     no occurrence named ~x2." path (gpl :n mod) head)
                (mv path invp))

               ;; Follow the tail into the submodule.
               (submod         (gpl :op occ))
               (sub-ins        (gpl :i submod))
               ((mv path invp) (follow-path-backwards-aux tail submod invp (- steps 1)))
               ((unless (and (atom path)
                             (member-of-pat-flatten path sub-ins)))
                ;; Well, that's as far as we can go.
                (mv (cons head path) invp))
               ;; Awesome -- made it to an input of the submod, so we can look
               ;; up the connected actual (from this mod) and keep following it.
               (actual (cdr (assoc-pat->al path sub-ins (gpl :i occ)))))
            (follow-path-backwards-aux actual mod invp (- steps 1))))

         ((when (member-of-pat-flatten path (gpl :i mod)))
          ;; Made it all the way back to an input of this module.  That's as
          ;; far back as we can go, so we're done!
          (mv path invp))


         ;; Non-primitive: dive down into the submodule that drives it.
         (occ            (find-driving-occ path (gpl :occs mod)))
         ((unless occ)
          (er hard? 'follow-path-backwards-aux
              "Trying to follow wire ~x0 in module ~x1, but there is no ~
               occurrence that drives this wire!" path (gpl :n mod))
          (mv path invp))

         (instname       (gpl :u occ))
         (submod         (gpl :op occ))
         (sub-ins        (gpl :i submod))
         (sub-formal     (cdr (assoc-pat->al path (gpl :o occ) (gpl :o submod))))
         ((mv path invp) (follow-path-backwards-aux sub-formal submod invp (- steps 1)))

         ((unless (and (atom path)
                       (member-of-pat-flatten path sub-ins)))
          ;; Well, that's as far as we can go.
          (mv (cons instname path) invp))

         ;; Awesome -- made it to an input of the submod, so we can look up the
         ;; connected actual (from this mod) and keep following it.
         (actual (cdr (assoc-pat->al path sub-ins (gpl :i occ)))))
      (follow-path-backwards-aux actual mod invp (- steps 1))))

  (local (in-theory (enable follow-path-backwards-aux)))

  (local (defthm data-for-patternp-of-outputs-when-good-esim-occp-other-direction
           (implies (good-esim-occp occ)
                    (data-for-patternp (gpl :o occ)
                                       (gpl :o (gpl :op occ))))))

  (verify-guards follow-path-backwards-aux)

  (defund follow-path-backwards (path mod)
    "Returns (MV NEW-PATH INVP)"
    (declare (xargs :guard (good-esim-modulep mod)))
    ;; A million steps should probably be plenty
    (follow-path-backwards-aux path mod nil #u1_000_000)))



