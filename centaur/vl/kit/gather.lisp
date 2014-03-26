; VL Verilog Toolkit
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

(in-package "VL")
(include-book "../top")
(include-book "centaur/getopt/top" :dir :system)
(include-book "std/io/read-file-characters" :dir :system)
(include-book "progutils")
(include-book "oslib/catpath" :dir :system)
(local (include-book "../util/arithmetic"))
(local (include-book "../util/osets"))


(defoptions vl-gather-opts
  :parents (vl-gather)
  :short "Options for running @('vl gather')."
  :tag :vl-model-opts

  ((help        booleanp
                :alias #\h
                "Show a brief usage message and exit."
                :rule-classes :type-prescription)

   (readme      booleanp
                "Show a more elaborate README and exit."
                :rule-classes :type-prescription)

   (output      stringp
                :alias #\o
                :argname "FILE"
                "Default is \"vl_gather.v\".  Where to write the collected up
                 modules."
                :default "vl_gather.v"
                :rule-classes :type-prescription)

   (start-files string-listp
                "The list of files to parse. (Not options; this is the rest of
                 the command line, hence :hide t)"
                :hide t)

   (search-path string-listp
                :longname "search"
                :alias #\s
                :argname "DIR"
                "Control the search path for finding modules.  You can give
                 this switch multiple times, to set up multiple search paths in
                 priority order."
                :parser getopt::parse-string
                :merge acl2::rcons)

   (search-exts string-listp
                :longname "searchext"
                :argname "EXT"
                "Control the search extensions for finding modules.  You can
                 give this switch multiple times.  By default we just look for
                 files named \"foo.v\" in the --search directories.  But if you
                 have Verilog files with different extensions, this won't work,
                 so you can add these extensions here.  EXT should not include
                 the period, e.g., use \"--searchext vv\" to consider files
                 like \"foo.vv\", etc."
                :parser getopt::parse-string
                :merge acl2::rcons
                :default '("v"))

   (overrides   string-listp
                :longname "override"
                :argname "DIR"
                "(Advanced) Set up VL override directories.  You can give this
                 switch multiple times.  By default there are no override
                 directories.  See the VL documentation on overrides (under
                 loader) for more information."
                :parser getopt::parse-string
                :merge acl2::rcons)

   (defines     string-listp
                :longname "define"
                :alias #\D
                :argname "VAR"
                "Set up definitions to use before parsing begins.  Equivalent
                 to putting `define VAR 1 at the top of your Verilog file.
                 You can give this option multiple times."
                :parser getopt::parse-string
                :merge acl2::cons)

   (edition     vl-edition-p
                :argname "EDITION"
                "Which edition of the Verilog standard to implement?
                 Default: \"SystemVerilog\" (IEEE 1800-2012).  You can
                 alternately use \"Verilog\" for IEEE 1364-2005, i.e.,
                 Verilog-2005."
                :default :system-verilog-2012)

   (strict      booleanp
                :rule-classes :type-prescription
                "Disable VL extensions to Verilog.")

   (mem         posp
                :alias #\m
                :argname "GB"
                "How much memory to try to use.  Default: 4 GB.  Raising this
                 may improve performance by avoiding garbage collection.  To
                 avoid swapping, keep this below (physical_memory - 2 GB)."
                :default 4
                :rule-classes :type-prescription)
   ))


(defconst *vl-gather-help* (str::cat "
vl gather:  Collect Verilog files into a single file.

Example:  vl gather engine.v wrapper.v core.v \\
              --search ./simlibs \\
              --search ./baselibs \\
              --output all-modules.v

Usage:    vl gather [OPTIONS] file.v [file2.v ...]

Options:" *nls* *nls* *vl-gather-opts-usage* *nls*))


(define vl-module-original-source ((mod     vl-module-p)
                                   (filemap vl-filemap-p))
  :returns (original-source stringp :rule-classes :type-prescription)
  (b* (((vl-module mod) mod)
       (minloc mod.minloc)
       (maxloc mod.maxloc)
       ((vl-location minloc) minloc)
       ((vl-location maxloc) maxloc)
       ((unless (equal minloc.filename maxloc.filename))
        (raise "Expected modules to begin/end in the same file, but ~s0 ~
                starts at ~s1 and ends at ~s2."
               mod.name
               (vl-location-string minloc)
               (vl-location-string maxloc))
        "")
       (file (cdr (hons-assoc-equal minloc.filename filemap)))
       ((unless file)
        (raise "File not found in the file map: ~s0" minloc.filename)
        "")
       (maxloc
        ;; awful hack to get all of "endmodule"
        (change-vl-location maxloc
                            :col (+ maxloc.col (length "endmodule"))))
       (lines (vl-string-between-locs file minloc maxloc))
       ((unless lines)
        (raise "Error extracting module contents for ~s0" mod.name)
        ""))
    (str::cat "// " mod.name " from " minloc.filename ":" (natstr minloc.line)
              *nls* lines)))

(defprojection vl-modulelist-original-sources (x filemap)
  (vl-module-original-source x filemap)
  :guard (and (vl-modulelist-p x)
              (vl-filemap-p filemap))
  ///
  (defthm string-listp-of-vl-modulelist-original-sources
    (string-listp (vl-modulelist-original-sources x filemap))))

(define vl-design-original-source ((x       vl-design-p)
                                   (filemap vl-filemap-p))
  :returns (original-source stringp :rule-classes :type-prescription)
  (b* ((x    (vl-design-fix x))
       (mods (vl-design->mods x)))
    (str::join (vl-modulelist-original-sources mods filemap)
               (implode '(#\Newline #\Newline)))))

(define vl-gather-reorder ((x vl-design-p))
  :returns (new-x vl-design-p)
  (b* ((x    (vl-design-fix x))
       (mods (vl-design->mods x))
       (missing (vl-modulelist-missing mods))
       ((when missing)
        (raise "Error: did not find definitions for ~&0." missing)
        x)
       (mods (cwtime (vl-deporder-sort mods))))
    (change-vl-design x :mods mods)))

(define vl-gather-main ((opts vl-gather-opts-p)
                        &key (state 'state))

  (b* (((vl-gather-opts opts) opts)

       (loadconfig (make-vl-loadconfig
                    :edition       opts.edition
                    :strictp       opts.strict
                    :override-dirs opts.overrides
                    :start-files   opts.start-files
                    :search-path   opts.search-path
                    :search-exts   opts.search-exts
                    :defines       (vl-make-initial-defines opts.defines)
                    :filemapp      t))

       ((mv result state) (vl-load loadconfig))
       ((vl-loadresult result) result)
       (design  (vl-gather-reorder result.design))
       (orig    (vl-design-original-source design result.filemap))
       (- (cw "Writing output file ~x0~%" opts.output))
       (state   (with-ps-file opts.output (vl-print orig)))
       (- (cw "All done gathering files.~%")))
    state))

(defconsts (*vl-gather-readme* state)
  (b* (((mv contents state) (acl2::read-file-characters "gather.readme" state))
       ((when (stringp contents))
        (raise contents)
        (mv "" state)))
    (mv (implode contents) state)))

(define vl-gather ((argv string-listp) &key (state 'state))
  :parents (kit)
  :short "The @('vl gather') command."
  (b* (((mv errmsg opts start-files)
        (parse-vl-gather-opts argv))
       ((when errmsg)
        (die "~@0~%" errmsg)
        state)
       (opts (change-vl-gather-opts opts
                                    :start-files start-files))
       ((vl-gather-opts opts) opts)

       ((when opts.help)
        (vl-cw-ps-seq (vl-print *vl-gather-help*))
        (exit-ok)
        state)

       ((when opts.readme)
        (vl-cw-ps-seq (vl-print *vl-gather-readme*))
        (exit-ok)
        state)

       ((unless (consp opts.start-files))
        (die "No files to process.")
        state)

       (- (cw "VL Gather Configuration:~%"))

       (- (cw " - start files: ~x0~%" opts.start-files))
       (state (must-be-regular-files! opts.start-files))

       (- (cw " - search path: ~x0~%" opts.search-path))
       (state (must-be-directories! opts.search-path))

       (- (and opts.overrides
               (cw " - overrides: ~x0~%" opts.overrides)))
       (state (must-be-directories! opts.overrides))

       (- (and opts.defines (cw "; defines: ~x0~%" opts.defines)))

       (- (cw " - output file: ~x0~%" opts.output))

       (- (cw "; Soft heap size ceiling: ~x0 GB~%" opts.mem))
       (- (acl2::set-max-mem ;; newline to appease cert.pl's scanner
           (* (expt 2 30) opts.mem)))

       (state (vl-gather-main opts)))
    (exit-ok)
    state))


