; VL Verilog Toolkit
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
; Original author: Jared Davis <jared@centtech.com>

(in-package "ACL2")

(include-book "std/portcullis" :dir :system)
(include-book "oslib/portcullis" :dir :system)
(include-book "centaur/bridge/portcullis" :dir :system)
(include-book "centaur/getopt/portcullis" :dir :system)
(include-book "centaur/nrev/portcullis" :dir :system)
(include-book "centaur/fty/portcullis" :dir :system)

(defmacro multi-union-eq (x y &rest rst)
  (xxxjoin 'union-eq (list* x y rst)))

(defpkg "VL"
  (set-difference-eq
   ;; Things to add:
   (multi-union-eq
    std::*std-exports*
    getopt::*getopt-exports*
    set::*sets-exports*
    nrev::*nrev-exports*
    acl2::*acl2-exports*
    acl2::*common-lisp-symbols-from-main-lisp-package*
    ;; Things we want to "export"
    '(defmodules)
    ;; Things we want to "import"
    '(assert!
      b*
      fun
      local-stobjs
      append-without-guard
      flatten
      strip-cadrs
      simpler-take
      repeat
      replicate
      first-n
      rest-n
      list-fix
      list-equiv
      same-lengthp
      rev
      revappend-without-guard
      unexplode-nonnegative-integer
      base10-digit-char-listp
      prefixp
      set-equiv
      set-reasoning
      lnfix
      lifix
      lbfix
      maybe-natp
      maybe-natp-fix
      maybe-stringp
      maybe-posp
      maybe-integerp
      never-memoize
      char-fix
      chareqv
      str-fix
      str::string-list-fix
      streqv
      pos-fix
      acl2::print-base-p

      std::mksym
      std::mksym-package-symbol
      std::extract-keyword-from-args
      std::throw-away-keyword-parts
      std::defoption

      fty::defprod
      fty::deftypes
      fty::deftagsum
      fty::deffixtype
      fty::deffixequiv
      fty::deffixequiv-mutual
      true-p
      true-fix
      true-equiv

      value
      file-measure
      two-nats-measure
      add-untranslate-pattern
      conjoin
      conjoin2
      disjoin
      disjoin2
      access
      rewrite-rule
      augment-theory
      find-rules-of-rune
      signed-byte-p
      unsigned-byte-p
      cwtime
      xf-cwtime
      defxdoc
      undocumented
      progn$

      make-fal
      make-fast-alist
      with-fast-alist
      with-fast
      with-stolen

      run-when
      run-if
      run-unless
      assocs

      defconsts
      definline
      definlined

      seq
      seq-backtrack
      seqw
      seqw-backtrack
      cw-obj
      return-raw

      uniquep
      duplicity
      duplicated-members
      <<-sort
      hons-duplicated-members

      sneaky-load
      sneaky-push
      sneaky-save

      cw-unformatted

      alists-agree
      alist-keys
      alist-vals
      alist-equiv
      sub-alistp
      hons-rassoc-equal
      append-alist-keys
      append-alist-keys-exec
      append-alist-vals
      append-alist-vals-exec

      autohide
      autohide-delete
      autohide-clear
      autohide-summary
      autohide-cp
      authoide-hint

      def-ruleset
      def-ruleset!
      add-to-ruleset
      add-to-ruleset!
      get-ruleset
      ruleset-theory

      make-fast-alist
      with-fast-alist
      with-fast
      with-fast-alists

      vcd-dump

      gpl
      pat->al
      pat->fal
      al->pat
      data-for-patternp
      similar-patternsp
      pat-flatten
      pat-flatten1
      collect-signal-list
      good-esim-primitivep
      good-esim-modulep
      good-esim-occp
      good-esim-occsp
      bad-esim-modulep
      bad-esim-occp
      bad-esim-occsp

      str::cat
      str::natstr
      str::implode
      str::explode

      ;; To make VL::VL show up as just VL in the ACL2 package, e.g., to
      ;; make the XDOC index prettier.
      vl
      hardware-verification
      esim

      ;; acl2-customization file stuff
      why
      with-redef



      ))

   ;; Things to remove:
   '(true-list-listp
     substitute
     union
     delete
     case
     include-book
     formatter
     formatter-p
     format
     concatenate
     enable
     disable
     e/d
     warn
     nat-listp ; included 12/4/2012 by Matt K., for addition to *acl2-exports*
     )))

(assign acl2::verbose-theory-warning nil)

; It's too frustrating NOT to have this be part of package.lsp

(defmacro VL::include-book (&rest args)
  `(ACL2::include-book ,@args :ttags :all))