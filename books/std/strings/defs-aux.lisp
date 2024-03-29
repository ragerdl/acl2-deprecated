; ACL2 String Library
; Copyright (C) 2009-2013 Centaur Technology
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

; defs-aux.lisp - Helper file for defs.lisp and defs-program.lisp.

(in-package "STR")

(defconst *str-library-basic-defs*
  '(acl2::rest-n
    acl2::replicate-fn
    replicate
    prefixp
    listpos
    acl2::revappend-without-guard
    sublistp
    rev
    ;; coerce.lisp
    acl2::explode$inline
    explode
    acl2::implode$inline
    implode
    ;; Including this type-prescription rule improves the type-prescriptions of
    ;; some subsequent functions such as upcase-string.
    acl2::return-type-of-implode$inline

    ;; eqv.lisp
    charlisteqv
    charlisteqv-is-an-equivalence

    ;; cat.lisp
    fast-string-append
    fast-string-append-lst
    fast-concatenate
    cat
    append-chars-aux
    append-chars$inline
    append-chars
    revappend-chars-aux
    revappend-chars$inline
    revappend-chars
    prefix-strings
    rchars-to-string
    join-aux
    join
    join$inline

    ;; char-case.lisp
    little-a
    little-z
    big-a
    big-z
    case-delta
    up-alpha-p$inline
    up-alpha-p
    down-alpha-p$inline
    down-alpha-p
    upcase-char$inline
    upcase-char
    downcase-char$inline
    downcase-char
    make-upcase-first-strtbl
    *upcase-first-strtbl*
    upcase-char-str$inline
    upcase-char-str
    make-downcase-first-strtbl
    *downcase-first-strtbl*
    downcase-char-str$inline
    downcase-char-str

    ;; case-conversion.lisp
    charlist-has-some-down-alpha-p
    upcase-charlist-aux
    upcase-charlist
    charlist-has-some-up-alpha-p
    downcase-charlist-aux
    downcase-charlist
    string-has-some-down-alpha-p
    upcase-string-aux
    upcase-string
    string-has-some-up-alpha-p
    downcase-string-aux
    downcase-string
    upcase-string-list-aux
    upcase-string-list
    downcase-string-list-aux
    downcase-string-list
    upcase-first-charlist
    upcase-first
    downcase-first-charlist
    downcase-first

    ;; ieqv.lisp
    ichareqv$inline
    ichareqv
    ichareqv-is-an-equivalence
    icharlisteqv
    icharlisteqv-is-an-equivalence
    istreqv-aux
    istreqv$inline
    istreqv
    istreqv-is-an-equivalence

    ;; decimal.lisp
    digitp
    digitp$inline
    nonzero-digitp$inline
    nonzero-digitp
    digit-val
    digit-val$inline
    digit-listp
    digit-list-value1
    digit-list-value
    digit-list-value$inline
    skip-leading-digits
    take-leading-digits
    digit-string-p-aux
    digit-string-p
    digit-string-p$inline
    basic-natchars
    natchars-aux
    natchars$inline
    natchars
    revappend-natchars-aux
    revappend-natchars
    natstr
    natstr$inline
    natstr-list
    natsize-slow
    natsize-fast
    natsize
    natsize$inline
    parse-nat-from-charlist
    parse-nat-from-string
    strval

    ;; binary.lisp
    bit-digitp
    bit-digitp$inline
    bit-digit-listp
    bit-digit-val
    bit-digit-val$inline
    bit-digit-list-value1
    bit-digit-list-value
    bit-digit-list-value$inline
    skip-leading-bit-digits
    take-leading-bit-digits
    bit-digit-string-p-aux
    bit-digit-string-p
    bit-digit-string-p$inline
    basic-natchars2
    natchars2-aux
    natchars2
    natchars2$inline
    revappend-natchars2-aux
    revappend-natchars2
    natstr2
    natstr2$inline
    natstr2-list
    natsize2
    natsize2$inline
    parse-bits-from-charlist
    parse-bits-from-string
    strval2

    ;; hex.lisp
    hex-digitp
    hex-digitp$inline
    hex-digit-listp
    hex-digit-val
    hex-digit-val$inline
    hex-digit-list-value1
    hex-digit-list-value
    hex-digit-list-value$inline
    skip-leading-hex-digits
    take-leading-hex-digits
    hex-digit-string-p-aux
    hex-digit-string-p
    hex-digit-string-p$inline
    hex-digit-to-char
    hex-digit-to-char$inline
    basic-natchars16
    natchars16-aux
    natchars16
    natchars16$inline
    revappend-natchars16-aux
    revappend-natchars16
    natstr16
    natstr16$inline
    natstr16-list
    natsize16-aux
    natsize16
    natsize16$inline
    parse-hex-from-charlist
    parse-hex-from-string
    strval16

    ;; firstn-chars.lisp
    firstn-chars-aux
    firstn-chars
    append-firstn-chars

    ;; html-encode.lisp
    html-space
    html-newline
    html-less
    html-greater
    html-amp
    html-quote
    repeated-revappend
    distance-to-tab$inline
    distance-to-tab
    html-encode-chars-aux
    html-encode-string-aux
    html-encode-string

    ;; iless.lisp
    ichar<$inline
    ichar<
    icharlist<
    istr<-aux
    istr<$inline
    istr<

    ;; iprefixp.lisp
    iprefixp

    ;; istrprefixp.lisp
    istrprefixp-impl
    istrprefixp$inline
    istrprefixp

    ;; istrpos.lisp
    istrpos-impl
    istrpos$inline
    istrpos

    ;; isubstrp.lisp
    isubstrp$inline
    isubstrp
    collect-strs-with-isubstr
    collect-syms-with-isubstr
    ;; isort.lisp
    acl2::mergesort-fixnum-threshold
    istr-list-p
    istr-merge-tr
    istr-mergesort-fixnum
    istr-mergesort-integers
    istr-sort
    istrsort

    ;; pad.lisp
    rpadchars
    rpadstr
    lpadchars
    lpadstr
    trim-aux
    trim-bag
    trim

    ;; prefix-lines.lisp
    prefix-lines-aux
    prefix-lines

    ;; strline.lisp
    charpos-aux
    go-to-line
    strline
    strlines

    ;; strnatless.lisp
    parse-nat-from-charlist
    parse-nat-from-string
    charlistnat<
    strnat<-aux
    strnat<$inline
    strnat<

    ;; strprefixp.lisp
    strprefixp-impl
    strprefixp$inline
    strprefixp

    ;; strpos.lisp
    strpos-fast
    strpos$inline
    strpos

    ;; strrpos.lisp
    strrpos-fast
    strrpos$inline
    strrpos

    ;; strsplit.lisp
    split-list-1
    split-list*
    character-list-listp
    coerce-list-to-strings
    strsplit

    ;; strsubst.lisp
    strsubst-aux
    strsubst
    strsubst-list

    ;; strtok.lisp
    strtok-aux
    strtok$inline
    strtok

    ;; substrp
    substrp$inline
    substrp

    ;; strsuffixp
    strsuffixp$inline
    strsuffixp

    ;; symbols.lisp
    symbol-list-names
    intern-list-fn
    intern-list))

