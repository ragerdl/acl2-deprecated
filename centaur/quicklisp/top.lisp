; Quicklisp setup for Centaur books
; Copyright (C) 2008-2013 Centaur Technology
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
(include-book "tools/include-raw" :dir :system)
; (depends-on "inst/setup.lisp")

(defsection quicklisp
  :parents (acl2::interfacing-tools)
  :short "An ACL2 wrapper for the <a
href='http://www.quicklisp.org'>Quicklisp</a> system for installing Lisp
libraries."

  :long "<h3>About Quicklisp</h3>

<p>Quicklisp is a Common Lisp equivalent to tools like <a
href='http://www.cpan.org/'>CPAN</a> for <a
href='http://www.perl.org/'>Perl</a>, or <a
href='http://rubygems.org/'>RubyGems</a> for <a
href='http://www.ruby-lang.org/'>Ruby</a>.  It lets you to easily install and
load the latest versions of Common Lisp libraries (and their dependencies).</p>

<p>If you don't know much about Quicklisp and are wanting to find out about the
available libraries, the following may be useful:</p>

<ul>

<li><a href='http://www.cliki.net/'>CLiki</a> is a Common Lisp wiki.  See
especially the page about <a
href='http://www.cliki.net/Current%20recommended%20libraries'>recommended
libraries</a>.</li>

<li><a href='http://quickdocs.org/'>Quickdocs</a> purports to provide
documentation for all of the libraries in Quicklisp.</li>

</ul>


<h3>The ACL2 Quicklisp Book</h3>

<p>To make it easy to use Quicklisp from ACL2, we have wrapper book, which of
course requires a <see topic='@(url defttag)'>trust tag</see>:</p>

@({
    (include-book \"centaur/quicklisp/top\" :dir :system)
})

<p><b>NOTE:</b> this book isn't automatically certified when you just run
@('make') in the acl2-books directory.  You have to explicitly tell @('make')
that you want to use Quicklisp&mdash;e.g.,</p>

@({
    cd [...]/acl2-sources/books
    make USE_QUICKLISP=1
})

<p>The Quicklisp book really is just a way to get Quicklisp itself loaded into
an ACL2 session.  It doesn't load anything libraries.</p>


<h3>Practical Howto</h3>

<p>So how do you actually use the Quicklisp book to gain access to a Common
Lisp library?  For instance, say we want to make use of the <a
href='http://common-lisp.net/project/cl-json/'>CL-JSON</a> library.</p>

<p>Normally you would do something like this:</p>

@({
    ; ** my-book.lisp
    (in-package \"MY-PKG\")

    ; ** Load Quicklisp, tell cert.pl this book needs Quicklisp support
    (include-book \"centaur/quicklisp/top\" :dir :system)
    ;; cert_param: (uses-quicklisp)

    ; ** [OPTIONAL] develop a logical story so you can use the
    ; ** library from proper ACL2 functions...
    (defun foo (x y z)
      (declare (xargs :guard ...))
      (progn$
       (er hard? 'foo \"Raw lisp definition not installed?\")
       (logical-story-of-foo x y z)))

    ; ** Add a ttag since we're going to use include-raw
    (defttag :my-book)

    ; ** Tell cert.pl that we're going to be loading raw Lisp code
    ;; (depends-on \"my-book-raw.lsp\")

    ; ** Actually include the raw Lisp code for our book
    (include-raw \"my-book-raw.lsp\"
                 :do-not-compile t
                 :host-readtable t)
})

<p>You usually need to use the @(':host-readtable') option because real Common
Lisp libraries will use things (packages, floats, etc.) that ACL2's reader will
reject.  You usually need to use @(':do-not-compile') because BOZO why?  I
don't know, but it never *!@$! works if you try to compile it.</p>

<p>The corresponding raw file, then would look something like this:</p>

@({
    ; ** my-book-raw.lsp
    (in-package \"MY-PKG\")

    ; ** Tell Quicklisp we want to use the CL-JSON library
    (ql:quickload \"cl-json\")

    ; ** Redefine our interface functions, freely using cl-json
    ; ** functionality
    (defun foo (x y z)
      ...)
})")

(defttag :quicklisp)

(value-triple (cw "~%~%~
***********************************************************************~%~
*****                                                             *****~%~
*****                  IF YOUR BUILD FAILS                        *****~%~
*****                                                             *****~%~
***** The include-raw form here can fail if you try to certify    *****~%~
***** this book without first getting quicklisp installed.  You   *****~%~
***** need to run 'make' first.                                   *****~%~
*****                                                             *****~%~
***** See books/centaur/README.html for detailed directions for   *****~%~
***** properly building the Centaur books.                        *****~%~
*****                                                             *****~%~
***********************************************************************~%~
~%"))

(include-raw "inst/setup.lisp"
             :do-not-compile t
             :host-readtable t)