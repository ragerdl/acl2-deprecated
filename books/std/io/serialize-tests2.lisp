; Serializing ACL2 Objects
; Copyright (C) 2009-2012 Centaur Technology
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
(include-book "serialize-tests")

(local (value-triple (cw "Blah is ~x0.~%" "blah")))
(local (value-triple (cw "Blah is also ~x0.~%" (hons-copy "blah"))))

(local (set-slow-alist-action :break))

;; these should not break, foo should still be fast
(value-triple (hons-get '1 *foo*))

(value-triple (hons-get "blah" *foo2*))
(value-triple (hons-get (concatenate 'string "bl" "ah") *foo2*))

(value-triple (hons-get "black" *foo2*))
(value-triple (hons-get (concatenate 'string "bl" "ack") *foo2*))

(value-triple (hons-get "sheep" *foo2*))

(local (set-slow-alist-action :warning))
;; this should complain, bar was never fast
(value-triple (hons-get '1 *bar*))

