; XDOC Documentation System for ACL2
; Copyright (C) 2009-2011 Centaur Technology
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

; names.lisp
;
; This file defines XDOC functions for displaying symbol names and generating
; file names for symbols.  Normally you should not need to include this file
; directly, but it may be useful if you are writing macros to directly generate
; XDOC topics.

(in-package "XDOC")
(include-book "std/strings/defs" :dir :system)
(program)


; ----------------- File Name Generation ------------------------

; Symbol names need to be escaped for many file systems to deal with them.  We
; replace colons with two underscores, and funny characters become _[code],
; somewhat like url encoding.

(defun funny-char-code (x acc)
  (declare (type character x))
  (b* ((code  (char-code x))
       (high  (ash code -4))
       (low   (logand code #xF)))
    (list* (digit-to-char high)
           (digit-to-char low)
           acc)))

(defun file-name-mangle-aux (x n xl acc)
  (declare (type string x))
  (b* (((when (= n xl))
        acc)
       (char (char x n))
       ((when (or (and (char<= #\a char) (char<= char #\z))
                  (and (char<= #\A char) (char<= char #\Z))
                  (and (char<= #\0 char) (char<= char #\9))
                  (eql char #\-)
                  (eql char #\.)))
        (file-name-mangle-aux x (+ n 1) xl (cons char acc)))
       ((when (eql char #\:))
        (file-name-mangle-aux x (+ n 1) xl (list* #\_ #\_ acc))))
    (file-name-mangle-aux x (+ n 1) xl (funny-char-code char (cons #\_ acc)))))

(defun file-name-mangle (x acc)

; Our "standard" for generating safe file names from symbols.  The mangled
; characters are accumulated onto acc in reverse order.  We always use the full
; package and the symbol name when creating file names.

  (declare (type symbol x))
  (b* ((str (str::cat (symbol-package-name x) "::" (symbol-name x))))
    (file-name-mangle-aux str 0 (length str) acc)))

(defun url (x)

; Simplest way to get the URL for a topic.  Give it the symbol, it gives you
; the URL.  Meant for use in macros that generate documentation.  See also
; XDOC::SEE, defined below.

  (declare (type symbol x))
  (str::rchars-to-string (file-name-mangle x nil)))


; ----------------- Displaying Symbols --------------------------

; We imagine the reader of the documentation wants to view the world from some
; BASE-PKG (which we pass around as a symbol).  When he reads about a symbol
; that is in this package, he doesn't want to see the PKG:: prefix.  But when
; he reads about symbols from other packages, he needs to see the prefix.

(defun in-package-p (sym base-pkg)

; We don't just ask if the symbol-package-names of sym and base-pkg are equal,
; because this would fail to account for things like COMMON-LISP::car versus
; ACL2::foo.

  (equal (intern-in-package-of-symbol (symbol-name sym) base-pkg)
         sym))

(defun simple-html-encode-chars (x acc)

; X is a character list that we copy into acc (in reverse order), except that
; we escape any HTML entities like < into the &lt; format.

  (b* (((when (atom x))
        acc)
       (acc (case (car x)
              (#\< (list* #\; #\t #\l #\& acc))         ;; "&lt;" (in reverse)
              (#\> (list* #\; #\t #\g #\& acc))         ;; "&gt;"
              (#\& (list* #\; #\p #\m #\a #\& acc))     ;; "&amp;"
              (#\" (list* #\; #\t #\o #\u #\q #\& acc)) ;; "&quot;"
              (t   (cons (car x) acc)))))
    (simple-html-encode-chars (cdr x) acc)))

#||
(reverse (implode (simple-html-encode-chars '(#\a #\< #\b) nil)))
(reverse (implode (simple-html-encode-chars '(#\a #\> #\b) nil)))
(reverse (implode (simple-html-encode-chars '(#\a #\& #\b) nil)))
(reverse (implode (simple-html-encode-chars '(#\a #\" #\b) nil)))
||#

(defun sneaky-downcase (x)
  (b* ((down (str::downcase-string x)))
    (str::strsubst "acl2" "ACL2" down)))

;(sneaky-downcase "SILLY-ACL2-TUTORIAL")


(defun name-low (name)
  (declare (type string name))
  (b* ((has-lowercase-p (str::string-has-some-down-alpha-p name 0 (length name)))
       (name-low        (if has-lowercase-p
                            ;; They had to go out of their way to type this
                            ;; name, using something like |foo| instead of FOO.
                            ;; So let's not forcibly downcase things, in case
                            ;; they want mixed case for some reason.
                            name
                          (sneaky-downcase name))))
    name-low))


(defun see (x)

; Simplest way to get a <see...> link that leads to a symbol.  Give it the
; symbol, it gives you <see topic='<url>'>name</see>, where name is properly
; lower-cased, etc. Meant for use in macros that generate documentation. See
; also XDOC::URL, above.

  (declare (type symbol x))
  (b* ((acc nil)
       (acc (str::revappend-chars "<see topic=\"" acc))
       (acc (file-name-mangle x acc))
       (acc (str::revappend-chars "\">" acc))
       (acc (str::revappend-chars (name-low (symbol-name x)) acc))
       (acc (str::revappend-chars "</see>" acc)))
    (str::rchars-to-string acc)))

; Added by Matt K., the following is a hook to allow symbols to be printed with
; respect to the ACL2 package.  This is useful for creating the file
; system/doc/rendered-doc-combined.lisp.
(encapsulate
 ()
 (logic)

 (defstub base-pkg-display-override (base-pkg) t)

 (defun base-pkg-display-override-default (base-pkg)
   (declare (xargs :mode :logic :guard t))
   base-pkg)

 (defattach base-pkg-display-override base-pkg-display-override-default))

; Added by Matt K., the following can be used for allowing symbols to be
; printed in a way that is likely to avoid the need for escaping with |...|.
; This is useful for creating the file system/doc/rendered-doc-combined.lisp.
(encapsulate
 ()
 (logic)

 (encapsulate
  (((rendered-name *) => * :formals (name) :guard (stringp name)))
  (local (defun rendered-name (x) x)))

 (defun rendered-name-default (name)
   (declare (xargs :mode :logic :guard (stringp name)))
   name)

 (defattach rendered-name rendered-name-default))

(defun sym-mangle (x base-pkg acc)

; This is our "standard" for displaying symbols in HTML (in lowercase).  We
; write the package part only if it is not the same as the base package.
; Characters to print are accumulated onto acc in reverse order.  BOZO think
; about adding keyword support?

  (b* ((base-pkg (base-pkg-display-override base-pkg))
       (name-low (name-low (rendered-name (symbol-name x))))
       (acc (if (in-package-p x base-pkg)
                acc
              (let ((pkg-low (name-low (symbol-package-name x))))
                (list* #\: #\:
                       (simple-html-encode-chars (explode pkg-low) acc))))))
    (simple-html-encode-chars (explode name-low) acc)))

(defun sym-mangle-cap (x base-pkg acc)

; Same as sym-mangle, but upper-case the first letter.

  (b* ((base-pkg (base-pkg-display-override base-pkg))
       (name-low (name-low (rendered-name (symbol-name x))))
       ((when (in-package-p x base-pkg))
        (let* ((name-cap (str::upcase-first name-low)))
          (simple-html-encode-chars (explode name-cap) acc)))
       (pkg-low (name-low (symbol-package-name x)))
       (pkg-cap (str::upcase-first pkg-low))
       (acc (list* #\: #\: (simple-html-encode-chars (explode pkg-cap) acc))))
    (simple-html-encode-chars (explode name-low) acc)))

; (reverse (implode (sym-mangle 'acl2 'acl2::foo nil)))
; (reverse (implode (sym-mangle 'acl2-tutorial 'acl2::foo nil)))


