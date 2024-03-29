; profile.lisp
; Copyright (C) 2013, Regents of the University of Texas

; This version of ACL2 is a descendent of ACL2 Version 1.9, Copyright
; (C) 1997 Computational Logic, Inc.  See the documentation topic NOTE-2-0.

; This program is free software; you can redistribute it and/or modify
; it under the terms of the LICENSE file distributed with ACL2.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; LICENSE for more details.

; This file was originally part of the HONS version of ACL2.  The original
; version of ACL2(h) was contributed by Bob Boyer and Warren A. Hunt, Jr.  The
; design of this system of Hash CONS, function memoization, and fast
; association lists (applicative hash tables) was initially implemented by
; Boyer and Hunt.

(in-package "ACL2")
(include-book "tools/include-raw" :dir :system)
; cert_param: (hons-only)

; [Jared]: I pulled PROFILE-ACL2, PROFILE-ALL, and PROFILE-FILE, and related
; functionality out of ACL2(h) and into this ttag-based book.  They are not
; core memoize functionality.

; WARNING: We rarely use these features.  It is somewhat likely that this code
; may stop working.

(defttag :profile)
(include-raw "output-raw.lsp")
(include-raw "profile-raw.lsp")

