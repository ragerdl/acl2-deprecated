; VL Verilog Toolkit
; Copyright (C) 2008-2014 Centaur Technology
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
; Original author: Jared Davis <jared@centtech.com>

(in-package "VL")
(include-book "latchcode")
(include-book "../../mlib/filter")
(local (include-book "../../util/arithmetic"))

(defxdoc latchsynth
  :parents (always-top)
  :short "Main transform for synthesizing simple latch-like @('always') blocks
into instances of primitive latch modules."

  :long "<p>This is a sort of back-end transform that does the final conversion
of already-simplified @('always') statements into latches.  This is quite
similar to how the @(see occform) transform converts Verilog expressions into
explicit instances of generated modules, except that here we are converting
@('always') statements into instances of latch modules.</p>

<p>Notes:</p>

<ul>

<li>We support only a very small set of @('always') statements here; see @(see
latchcode).  Typically you will want to run other statement-simplifying
transformations first to get them into this form; see @(see always-top).</li>

<li>We expect expressions to be sized so that we can tell which sizes of latch
modules to introduce.</li>

<li>We expect modules to be free of @('initial') statements, otherwise we could
produce invalid modules when we convert registers into nets.</li>

<li>This is a best-effort style transform which will leave unsupported
@('always') blocks alone.  We usually follow up with @(see elimalways) to throw
out (with fatal warnings) modules whose @('always') blocks were not
supported.</li>

</ul>")

(local (xdoc::set-default-parents synthalways))

(define vl-module-latchsynth
  :short "Synthesize simple latch-like @('always') blocks in a module."
  ((x         vl-module-p)
   (careful-p booleanp "be careful when processing latches?")
   vecp)
  :returns (mv (new-x   vl-module-p     :hyp :fguard)
               (addmods vl-modulelist-p :hyp :fguard))
  (b* (((vl-module x) x)

       ((when (vl-module->hands-offp x))
        ;; Don't mess with it.
        (mv x nil))

       ((unless (consp x.alwayses))
        ;; Optimization: nothing to do, so do nothing.
        (mv x nil))

       ((when (consp x.taskdecls))
        ;; For now, just don't try to support modules with tasks.  If we want
        ;; to support this, we need to at least be able to figure out if the
        ;; tasks are writing to the registers that we're synthesizing, etc.
        (b* ((warnings (warn :type :vl-latchsynth-fail
                             :msg "~m0 has tasks, so we are not going to try ~
                                   to synthesize its always blocks."
                             :args (list x.name)
                             :acc x.warnings)))
          (mv (change-vl-module x :warnings warnings)
              nil)))

       ((when (consp x.initials))
        ;; BOZO it seems hard to support modules with initial statements.  See
        ;; the edgesynth transform for comments.
        (b* ((warnings
              (warn :type :vl-latchsynth-fail
                    :msg "~m0 has initial statements so we aren't going to ~
                          try to synthesize its always blocks.  Note: usually ~
                          eliminitial should be run before edgesynth, in ~
                          which case you should not see this warning."
                    :args (list x.name)
                    :acc x.warnings)))
          (mv (change-vl-module x :warnings warnings)
              nil)))

       (delta      (vl-starting-delta x))
       (delta      (change-vl-delta delta
                                    ;; We'll strictly add netdecls, modinsts,
                                    ;; and assigns, so pre-populate them.
                                    :netdecls x.netdecls
                                    :modinsts x.modinsts
                                    :assigns  x.assigns))
       (scary-regs (vl-always-scary-regs x.alwayses))
       (cvtregs    nil)

       ((mv new-alwayses cvtregs delta)
        (vl-latchcode-synth-alwayses x.alwayses scary-regs x.regdecls
                                     cvtregs delta careful-p vecp))

       ((vl-delta delta) (vl-free-delta delta))

       ((mv regdecls-to-convert new-regdecls)
        ;; We already know all of the cvtregs are among the regdecls and have
        ;; no arrdims.  So, we can just freely convert look them up and convert
        ;; them here.
        (vl-filter-regdecls cvtregs x.regdecls))

       (new-netdecls (append (vl-always-convert-regs regdecls-to-convert)
                             delta.netdecls))

       (new-x (change-vl-module x
                                :netdecls new-netdecls
                                :regdecls new-regdecls
                                :assigns  delta.assigns
                                :modinsts delta.modinsts
                                :alwayses new-alwayses
                                :warnings delta.warnings)))
    (mv new-x delta.addmods)))

(define vl-modulelist-latchsynth-aux ((x vl-modulelist-p)
                                      (careful-p booleanp)
                                      vecp)
  :returns (mv (new-x vl-modulelist-p   :hyp :fguard)
               (addmods vl-modulelist-p :hyp :fguard))
  (b* (((when (atom x))
        (mv nil nil))
       ((mv car addmods1) (vl-module-latchsynth (car x) careful-p vecp))
       ((mv cdr addmods2) (vl-modulelist-latchsynth-aux (cdr x) careful-p vecp)))
    (mv (cons car cdr)
        (append-without-guard addmods1 addmods2))))

(define vl-modulelist-latchsynth
  :short "Synthesize latch-like @('always') blocks in a module list, perhaps
          adding some new, supporting modules."
  ((x vl-modulelist-p)
   (careful-p booleanp)
   vecp)
  :returns (new-x :hyp :fguard
                  (and (vl-modulelist-p new-x)
                       (no-duplicatesp-equal (vl-modulelist->names new-x))))
  (b* ((dupes (duplicated-members (vl-modulelist->names x)))
       ((when dupes)
        (raise "Module names must be unique, but found multiple definitions ~
                of ~&0." dupes))
       ((mv new-x addmods) (vl-modulelist-latchsynth-aux x careful-p vecp))
       (all-mods (union (mergesort new-x) (mergesort addmods)))
       (dupes    (duplicated-members (vl-modulelist->names all-mods)))
       ((when dupes)
        (raise "Latchsynth caused a name collision: ~&0." dupes)))
    all-mods))

(define vl-design-latchsynth
  :short "Top-level @(see latchsynth) transform."
  ((x vl-design-p) &key ((careful-p booleanp) 't) vecp)
  :returns (new-x vl-design-p)
  (b* ((x         (vl-design-fix x))
       (careful-p (if careful-p t nil))
       ((vl-design x) x))
    (change-vl-design x :mods (vl-modulelist-latchsynth x.mods careful-p vecp))))


