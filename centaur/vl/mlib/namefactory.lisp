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
(include-book "../util/namedb")
(include-book "modnamespace")
(local (include-book "../util/arithmetic"))
(local (std::add-default-post-define-hook :fix))

(local (xdoc::set-default-parents vl-namefactory-p))

(define vl-namefactory-namedb-okp ((mod    vl-maybe-module-p)
                                   (namedb vl-namedb-p))
  (or (not mod)
      (not (vl-namedb->names namedb))
      (subsetp-equal (vl-module->modnamespace mod)
                     (vl-namedb-allnames namedb)))
  ///
  (defthm vl-namefactory-namedb-okp-of-nil
    (vl-namefactory-namedb-okp nil namedb))
  (defthm vl-namefactory-namedb-okp-of-vl-empty-namedb
    (vl-namefactory-namedb-okp mod (vl-empty-namedb))
    :hints(("Goal" :in-theory (enable vl-empty-namedb))))
  (local (defthm vl-namedb->names-of-vl-starting-namedb
           (equal (vl-namedb->names (vl-starting-namedb names))
                  (make-lookup-alist (string-list-fix names)))
           :hints(("Goal" :in-theory (enable vl-starting-namedb)))))
  (defthm vl-namefactory-namedb-okp-of-vl-starting-namedb
    (vl-namefactory-namedb-okp mod (vl-starting-namedb (vl-module->modnamespace mod)))))

(define vl-namefactory-namedb-fix ((mod    vl-maybe-module-p)
                                   (namedb vl-namedb-p))
  :guard (vl-namefactory-namedb-okp mod namedb)
  :returns (new-db (and (vl-namedb-p new-db)
                        (vl-namefactory-namedb-okp mod new-db)))
  :inline t
  (mbe :logic
       (b* ((mod    (vl-maybe-module-fix mod))
            (namedb (vl-namedb-fix namedb)))
         (if (vl-namefactory-namedb-okp mod namedb)
             namedb
           (vl-empty-namedb)))
       :exec
       namedb)
  ///
  (defthm vl-namefactory-namedb-fix-when-vl-namefactory-namedb-okp
    (implies (vl-namefactory-namedb-okp mod namedb)
             (equal (vl-namefactory-namedb-fix mod namedb)
                    (vl-namedb-fix namedb)))))

(defprod vl-namefactory
  :tag :vl-namefactory
  :layout :tree
  ((mod    vl-maybe-module-p)
   (namedb vl-namedb-p :reqfix (vl-namefactory-namedb-fix mod namedb)))
  :require (vl-namefactory-namedb-okp mod namedb)
  :parents (mlib)
  :short "Produces fresh names for a module."

  :long "<p>A <b>name factory</b> allows you to easily and efficiently generate
good, fresh names that are not being used elsewhere in a Verilog module.  They
combine a name database (which is a general mechanism for generating fresh
names; see @(see vl-namedb-p) for details) with a Verilog module in order to
avoid computing the module's namespace until a name is actually needed.  This
optimization often saves a lot of consing.</p>

<h3>Using Name Factories</h3>

<p>Typically, given some module @('mod'), the user begins by constructing a
name factory using @('(vl-starting-namefactory mod)').  Note that it is quite
cheap to construct a name factory in this way; all expense is delayed until the
first use of the factory.  It is also possible to create a name factory without
a module using @(see vl-empty-namefactory), which is occasionally useful when
generating new modules.</p>

<p>Once constructed, name factories must be used in a single-threaded
discipline.  That is, the functions for generating names actually return
@('(mv fresh-name factory-prime)'), and to ensure that a sequence of
generated names are unique, one must always use the most recently returned
factory to generate subsequent names.</p>

<p>Two functions are provided for generating names:</p>

<p>@('(vl-namefactory-indexed-name prefix nf)') produces a name that looks like
@('prefix_n'), where @('n') is the smallest positive natural number @('n') such
that the name @('prefix_n') is not in use.</p>

<p>@('(vl-namefactory-plain-name name nf)') attempts to return @('name')
verbatim.  When this is not possible, a name of the form @('name_n'), a note
will be printed to standard output and instead we will produce a name with
@('vl-namefactory-indexed-name').</p>

<p>We use these functions for different purposes.  We think that @(see
vl-namefactory-indexed-name) should be used for \"throwaway\" names that don't
need to be reliable or understandable, such as the names of temporary wires to
be generated for split-up expressions.  Meanwhile, @(see
vl-namefactory-plain-name) should be used for splitting up instance names or in
any other cases where a reliable name is desired.</p>

<p>Because name factories make use of fast alists, they should be destroyed
with @('(vl-free-namefactory nf)') when you are done using them.</p>


<h3>Freshness Guarantee</h3>

<p>To establish that name factories generate only fresh names, we introduce the
function @('(vl-namefactory-allnames nf)').  This function returns a list of
all names that the name factory currently considers to be in use.  We
prove:</p>

<ul>

<li>The @('allnames') of the empty name factory is empty.</li>

<li>Every name in the @(see vl-module->modnamespace) of @('mod') is among the
@('allnames') of the initial name factory produced by
@('(vl-starting-namefactory mod).')</li>

<li>The @('fresh-name')s returned by @(see vl-namefactory-indexed-name) or
@(see vl-namefactory-plain-name) are not members of the @('allnames') of the
input factory.</li>

<li>The @('allnames') of the resulting @('factory-prime') include exactly the
@('allnames') of the input @('factory'), along with the generated
@('fresh-name').</li>

</ul>

<p>Together, these theorems ensure that, when properly used, the name factory
will only give you fresh names.</p>


<h3>Motivation and History</h3>

<p>Name generation is a surprisingly important and difficult problem.  It needs
to be very efficient: we have sometimes found that tens of thousands of fresh
names are needed, e.g., in @(see split).  Toward this goal, our original
approach was as follows:</p>

<ul>

<li>Our generated names always looked like @('_gen_1'), @('_gen_2'), etc.</li>

<li>When the first name was needed, a transform would examine the module's
namespace for the largest @('n') such that @('_gen_n') was already in use.  The
name @('_gen_{n+1}') would then be used as the first new name.</li>

<li>Subsequently, any number of fresh names could then be generated by simply
increasing the index.  That is, the second name fresh name would be
@('_gen_{n+2}'), the third @('_gen_{n+3}'), and so on.</li>

</ul>

<p>This scheme was highly efficient because the module's namespace only needed
to be consulted when generating the first wire's name.  This meant that for
large modules, generating thousands of names was not very expensive.  It also
meant that if no fresh names were needed, then the module's namespace was never
even computed.</p>

<p>But a problem with this scheme is that the generated names are not very good
or predictable.  This was particularly problematic when instance arrays
like:</p>

@({
basic_flop data [(width - 1):0] (q, ph1, d);
})

<p>would be transformed into something like:</p>

@({
basic_flop _gen_19 (q[0], ph1, d[0]);
basic_flop _gen_18 (q[1], ph1, d[1]);
basic_flop _gen_17 (q[2], ph1, d[2]);
})

<p>that is, here the instance name @('data') has been entirely lost and
replaced with a bunch of unrelated, stupid names that might easily change when
the module is translated in the future.</p>

<p>Name factories basically extend this scheme to allow much better names to be
generated, while still being quite efficient.</p>


<h3>Implementation</h3>

<p>A name factory has two fields:</p>

<ul>

<li>@('mod'), the module that we are generating names for, or @('nil') if there
is no such module (e.g., for empty name factories).</li>

<li>@('namedb') is an ordinary @(see vl-namedb-p) that we use to generate fresh
names.</li>

</ul>

<p>The invariant we maintain is that either the namedb is empty, or every name
in the @(see vl-module->modnamespace) of @('mod') must be bound in it.</p>")

(defthm subsetp-equal-of-modnamespace-when-vl-namefactory-p
  (implies (and (vl-namedb->names (vl-namefactory->namedb x))
                (vl-namefactory->mod x))
           (subsetp-equal (vl-module->modnamespace (vl-namefactory->mod x))
                          (vl-namedb-allnames (vl-namefactory->namedb x))))
  :hints(("Goal"
          :in-theory (e/d (vl-namefactory-namedb-okp)
                          (vl-namefactory-requirements))
          :use ((:instance vl-namefactory-requirements)))))




(define vl-namefactory-maybe-initialize
  :short "Make sure that the modnamespace is computed, or generate it if it isn't
  available already."
  ((factory vl-namefactory-p))
  :returns (new-factory vl-namefactory-p)
  :long "<p>We could do this as part of @(see vl-starting-namefactory) instead,
  but this allows us to make @('vl-starting-namefactory') very cheap and; avoid
  computing the modnamespace if it isn't used.</p>"
  :guard-hints (("goal" :in-theory (enable vl-namedb-allnames)))
  (if (vl-namedb->names (vl-namefactory->namedb factory))
      (vl-namefactory-fix factory)
    (let* ((mod   (vl-namefactory->mod factory))
           (modns (and mod (vl-module->modnamespace mod))))
      (change-vl-namefactory factory :namedb (vl-starting-namedb modns))))
  ///
  (defthm vl-namefactory->mod-of-vl-namefactory-maybe-initialize
    (equal (vl-namefactory->mod (vl-namefactory-maybe-initialize factory))
           (vl-namefactory->mod factory)))

  (defthm subsetp-equal-of-modnamespace-and-vl-namefactory-maybe-initialize
    (implies (vl-namefactory->mod factory)
             (subsetp-equal
              (vl-module->modnamespace (vl-namefactory->mod factory))
              (vl-namedb-allnames (vl-namefactory->namedb
                                   (vl-namefactory-maybe-initialize factory)))))
    :rule-classes ((:rewrite)
                   (:forward-chaining :trigger-terms
                    ((vl-namefactory-maybe-initialize factory)))))

  (defthm vl-namefactory-maybe-initialize-when-already-has-names
    (implies (vl-namedb->names (vl-namefactory->namedb factory))
             (equal (vl-namefactory-maybe-initialize factory)
                    (vl-namefactory-fix factory)))))


(define vl-namefactory-allnames
  :short "@(call vl-namefactory-p) returns a list of all names that are
considered to be used by the name factory."
  ((factory vl-namefactory-p))
  :returns (names string-listp)
  :long "<p>This function is not particularly efficient, and probably should
not ordinarily be executed in real programs.  Its main purpose is to establish
the freshness guarantee for name factories, described in @(see
vl-namefactory-p).</p>"
  :verify-guards nil
  :prepwork ((local (in-theory (enable vl-namefactory-namedb-okp))))
  (mbe :logic
       (vl-namedb-allnames
        (vl-namefactory->namedb
         (vl-namefactory-maybe-initialize
          factory)))
       :exec
       (let ((mod    (vl-namefactory->mod factory))
             (namedb (vl-namefactory->namedb factory)))
         (cond ((vl-namedb->names namedb)
                (vl-namedb-allnames namedb))
               (mod
                (vl-module->modnamespace mod))
               (t
                nil))))
  ///
  (local (in-theory (enable vl-starting-namedb
                            vl-namedb-allnames
                            vl-namefactory-namedb-okp
                            vl-namefactory-maybe-initialize
                            )))

  (verify-guards vl-namefactory-allnames)

  (defthm vl-namefactory-allnames-of-vl-namefactory-maybe-initialize
    (equal (vl-namefactory-allnames (vl-namefactory-maybe-initialize factory))
           (vl-namefactory-allnames factory))))


(define vl-starting-namefactory
  :short "@(call vl-starting-namefactory) creates a name factory for a module."
  ((mod vl-module-p))
  :returns (nf vl-namefactory-p)
  :long "<p>This function is very cheap to call because the real work of
initializing the name factory is deferred to its first use.  See @(see
vl-namefactory-p) for all name factory documentation.</p>"
  :prepwork ((local (in-theory (enable vl-namefactory-namedb-okp))))
  (make-vl-namefactory :mod (vl-module-fix mod) :namedb (vl-empty-namedb))
  ///
  (defthm vl-namefactory-allnames-of-vl-starting-namefactory
    (equal (vl-namefactory-allnames (vl-starting-namefactory mod))
           (vl-module->modnamespace mod))
    :hints(("Goal" :in-theory (e/d (vl-namefactory-allnames
                                    vl-starting-namedb
                                    vl-namedb-allnames
                                    vl-namefactory-maybe-initialize
                                    vl-empty-namedb))))))


(define vl-empty-namefactory ()
  :short "@(call vl-empty-namefactory) creates an empty name factory without
a module."
  :returns (nf vl-namefactory-p)
  :long "<p>Usually you should use @(see vl-starting-namefactory) instead;
@('vl-starting-namefactory') automatically regards all of the names in the
module as used, whereas @('vl-empty-namefactory') regards no names as used.</p>

<p>On the other hand, @('vl-empty-namefactory') may be useful when you are
generating modules from scratch and, hence, don't have a module to give to
@('vl-starting-namefactory') yet.</p>"

  (make-vl-namefactory :mod nil :namedb (vl-empty-namedb))
  ///
  (in-theory (disable (:executable-counterpart vl-empty-namefactory)))
  (local (in-theory (enable vl-empty-namedb)))

  (defthm vl-namefactory-allnames-of-vl-empty-namefactory
    (equal (vl-namefactory-allnames (vl-empty-namefactory))
           nil)))



(define vl-namefactory-indexed-name
  :short "@(call vl-namefactory-indexed-name) constructs a fresh name that
looks like @('prefix_n') for some natural number @('n'), and returns @('(mv
fresh-name factory-prime)')."
  ((prefix stringp)
   (factory vl-namefactory-p))
  :returns (mv (fresh-name stringp :rule-classes :type-prescription)
               (new-factory vl-namefactory-p))
  (b* ((factory (vl-namefactory-maybe-initialize factory))
       ((mv newname db-prime)
        (vl-namedb-indexed-name prefix (vl-namefactory->namedb factory)))
       (factory (change-vl-namefactory factory :namedb db-prime)))
    (mv newname factory))

  :prepwork ((local (in-theory (enable vl-namefactory-allnames
                                       vl-namefactory-namedb-okp))))
  ///

  (defthm vl-namefactory-allnames-of-vl-namefactory-indexed-name
    (b* (((mv fresh-name new-factory)
          (vl-namefactory-indexed-name prefix factory)))
      (equal (vl-namefactory-allnames new-factory)
             (cons fresh-name (vl-namefactory-allnames factory)))))

  (defthm vl-namefactory-indexed-name-is-fresh
    (b* (((mv fresh-name ?new-factory)
          (vl-namefactory-indexed-name prefix factory)))
      (not (member-equal fresh-name (vl-namefactory-allnames factory))))))



(define vl-namefactory-plain-name
  :short "@(call vl-namefactory-plain-name) returns @('(mv fresh-name
factory-prime)').  When possible, @('fresh-name') is just @('name').  When this
is not possible, a note is printed and @('fresh-name') looks like @('name_n')
instead."
  ((name    stringp)
   (factory vl-namefactory-p))
  :returns (mv (fresh-name stringp :rule-classes :type-prescription)
               (new-factory vl-namefactory-p))
  (b* ((factory (vl-namefactory-maybe-initialize factory))
       ((mv newname db-prime)
        (vl-namedb-plain-name name (vl-namefactory->namedb factory)))
       (factory (change-vl-namefactory factory :namedb db-prime)))
    (mv newname factory))

  :prepwork ((local (in-theory (enable vl-namefactory-namedb-okp
                                       vl-namefactory-allnames))))

  ///
  (defthm vl-namefactory-allnames-of-vl-namefactory-plain-name
    (b* (((mv fresh-name new-factory)
          (vl-namefactory-plain-name name factory)))
      (equal (vl-namefactory-allnames new-factory)
             (cons fresh-name (vl-namefactory-allnames factory)))))

  (defthm vl-namefactory-plain-name-is-fresh
    (b* (((mv fresh-name ?new-factory)
          (vl-namefactory-plain-name name factory)))
      (not (member-equal fresh-name (vl-namefactory-allnames factory))))))


(define vl-free-namefactory ((factory vl-namefactory-p))
  :returns nil
  :short "@(call vl-free-namefactory) frees the fast alists associated with a
name factory and returns @('nil')."

  :long "<p>The name factory should never be used after this function is
called, since doing so will result in fast-alist discipline failures.</p>

<p>Note that we leave this function enabled.</p>"
  :enabled t
  :hooks nil

  (progn$ (vl-free-namedb (vl-namefactory->namedb factory))
          nil))


(define vl-namefactory-plain-names
  :short "Generate a list of fresh names, using particular, preferred names if
  possible."
  ((names   string-listp "The names you would ideally like to use.")
   (factory vl-namefactory-p))
  :returns (mv (fresh-names string-listp
                            "Fresh names that you may use.  When possible,
                             these are just @('names').  If this is not
                             possible due to name collisions, then some of the
                             @('fresh_names') may have additional indexes as in
                             @(see vl-namefactory-indexed-name) and some notes
                             may be printed.")
               (new-factory vl-namefactory-p
                            "Updated name factory where the @('fresh-names')
                             are marked as used."))
  (b* (((when (atom names))
        (mv nil (vl-namefactory-fix factory)))
       ((mv name factory)
        (vl-namefactory-plain-name (car names) factory))
       ((mv rest factory)
        (vl-namefactory-plain-names (cdr names) factory)))
    (mv (cons name rest) factory))
  ///
  (defthm len-vl-namefactory-plain-names
    (equal (len (mv-nth 0 (vl-namefactory-plain-names names factory)))
           (len names)))

  (defthm true-listp-vl-namefactory-plain-names
    (true-listp (mv-nth 0 (vl-namefactory-plain-names names factory)))
    :rule-classes :type-prescription)

  (defthm vl-namefactory-plain-names-are-fresh
    (implies (member-equal name (vl-namefactory-allnames factory))
             (b* (((mv fresh-names ?new-factory)
                   (vl-namefactory-plain-names names factory)))
               (not (member name fresh-names))))))

