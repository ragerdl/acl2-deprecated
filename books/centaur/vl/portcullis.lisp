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

(in-package "VL")

; This is an empty book which is included in cert.acl2 in order to consolidate
; all of our portcullis commands into a single, usually-redundant include-book
; command.  This simply improves the efficiency of our build process.

(include-book "tools/safe-case" :dir :system)
(include-book "xdoc/top" :dir :system)
(include-book "tools/rulesets" :dir :system)

(defmacro VL::case (&rest args)
  `(ACL2::safe-case . ,args))

(defmacro VL::concatenate (&rest args)
  `(STR::fast-concatenate . ,args))

(defmacro VL::enable (&rest args)
  `(ACL2::enable* . ,args))

(defmacro VL::disable (&rest args)
  `(ACL2::disable* . ,args))

(defmacro VL::e/d (&rest args)
  `(ACL2::e/d* . ,args))

