#!/usr/bin/env perl

######################################################################
## NOTE.  This file is not part of the standard ACL2 books build
## process; it is part of an experimental build system that is not yet
## intended, for example, to be capable of running the whole
## regression.  The ACL2 developers do not maintain this file.
##
## Please contact Sol Swords <sswords@cs.utexas.edu> with any
## questions/comments.
######################################################################

# Copyright 2008 by Sol Swords.



#; This program is free software; you can redistribute it and/or modify
#; it under the terms of the GNU General Public License as published by
#; the Free Software Foundation; either version 2 of the License, or
#; (at your option) any later version.

#; This program is distributed in the hope that it will be useful,
#; but WITHOUT ANY WARRANTY; without even the implied warranty of
#; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#; GNU General Public License for more details.

#; You should have received a copy of the GNU General Public License
#; along with this program; if not, write to the Free Software
#; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.



# This script scans for dependencies of some ACL2 .cert files.
# Run "perl cert.pl -h" for usage.

# This script scans for include-book forms in the .lisp file
# corresponding to each .cert target and recursively maps out the
# dependencies of all files needed.  When it is finished, it writes
# out a file Makefile-tmp which can be used to make all the targets.

# This script assumes that the ACL2 system books directory is where it
# itself is located.  Therefore, if you call this script from a
# different directory, it should still be able to resolve ":dir
# :system" include-books.  It also scans the relevant .acl2 files for
# each book for add-include-book-dir commands.



use strict;
use warnings;
use FindBin qw($RealBin);
use Getopt::Long qw(:config bundling_override);

(do "$RealBin/certlib.pl") or die ("Error loading $RealBin/certlib.pl:\n $!");

my $base_path = 0;

my @targets = ();
my $jobs = 1;
my $no_build = 0;
my $no_makefile = 0;
my $mf_name = "Makefile-tmp";
my @includes = ();
my @include_afters = ();
my $cust_target = 0;
my $make_target = "all";
my $svn_mode = 0;
my $quiet = 0;
my @run_sources = ();
my @make_args = ();

my %certlib_opts = ( "debugging" => 0,
		     "clean_certs" => 0,
		     "print_deps" => 0,
		     "all_deps" => 0 );

$base_path = abs_canonical_path(".");

my $helpstr = '
cert.pl: Automatic dependency analysis for certifying ACL2 books.

Usage:
perl cert.pl <options, targets>

where targets are filenames of ACL2 files or certificates to be built
and options are as follows:

   --help
   -h
           Display this help and exit.

   --jobs <n>
   -j <n>
           Use n processes to build certificates in parallel.

   --all-deps
   -d
           Write out dependency information for all targets
           encountered, including ones which don\'t need updating.

   --clean-certs
   --cc
           Delete each certificate file and corresponding .out and
           .time file encountered in the dependency search.  Warning:
           Unless the "-n"/"--no-build" flag is given, the script will
           then subsequently rebuild these files.

   --no-build
   -n
           Don\'t create a makefile or call make; just run this script
           for "side effects" such as cleaning or generating
           dependency cache files.

   --clean-all
   -c
           Just clean up certificates and dependency cache files,
           don\'t generate new cache files or build certificates.
           Equivalent to "-n -cc -cp".

   -o <makefile-name>
           Determines where to write the dependency information;
           default is Makefile-tmp.

   --verbose-deps
   -v
           Print out dependency information as it\'s discovered.

   --makefile-only
   -m
           Don\'t run make after running the dependency analysis.

   --static-makefile <makefile-name>
   -s <makefile-name>
           Equivalent to -d -m -o <makefile-name>.  Useful for
           building a static makefile for your targets, which will
           suffice for certifying them as long as the dependencies
           between source files don\'t change.

   --include <makefile-name>
   -i <makefile-name>
           Include the specified makefile via an include command in
           the makefile produced.  Multiple -i arguments may be given
           to include multiple makefiles.  The include commands occur
           before the dependencies in the makefile.

   --include-after <makefile-name>
   --ia <makefile-name>
           Include the specified makefile via an include command in
           the makefile produced.  Multiple -ia arguments may be given
           to include multiple makefiles.  The include commands occur
           after the dependencies in the makefile.

   --custom-target <target>
   --ct <target>
           When writing the makefile, instead of creating a phony
           \'all\' target which depends on the certificates of all the
           books, create a list variable CERT_PL_BOOKS containing all
           the target certificates.  Then, if make is to be run, run
           it with the specified target.  This target should be
           created by the user in an include-after file.

   --relative-paths <dir>
   -r <dir>
           Use paths relative to the given directory rather than
           the current directory.

   --debug
           Print reams and reams of debugging info.

   --targets <file>
   -t <file>
           Add as targets the files listed (one per line) in <file>.

   --quiet
   -q
           Don\'t print any asides except for errors and output from
           --source-cmd commands.

   --debug
           Print some debugging info as the program runs.

   --source-cmd <command-str>
           Run the following command on each source file.  The actual
           command line is created by replacing the string {} with the
           target file in the command string.  For example:
               cert.pl top.lisp -n -d --source-cmd "echo {}; wc {}"
           Any number of --source-cmd directives may be given; the
           commands will then be run in the order in which they are given.

   --tags-file <tagfile>
           Create an Emacs tags file containing the tags for all
           source files.  Equivalent to
           --source-cmd "etags -a -o tagfile {}".

   --svn-status
           Traverse the dependency tree and run "svn status" on each
           source file in the tree.  Equivalent to
           --source-cmd "svn status --no-ignore {}".

   --make-args <arg>
           Add command line arguments to make.  Multiple such
           directives may be given.
';

GetOptions ("help|h"               => sub { print $helpstr; exit 0 ; },
	    "jobs|j=i"             => \$jobs,
	    "clean-certs|cc"       => \$certlib_opts{"clean_certs"},
	    "no-build|n"           => \$no_makefile,
	    "clean-all|c"          => sub {$no_makefile = 1;
					   $certlib_opts{"clean_certs"} = 1;},
	    "verbose-deps|v"       => \$certlib_opts{"print_deps"},
	    "makefile-only|m"      => \$no_build,
	    "o=s"                  => \$mf_name,
	    "all-deps|d"           => \$certlib_opts{"all_deps"},
	    "static-makefile|s=s"  => sub {shift;
					   $mf_name = shift;
					   $certlib_opts{"all_deps"} = 1;
					   $no_build = 1;},
	    "include|i=s"          => sub {shift;
					   push(@includes, shift);},
	    "include-after|ia=s"     => sub {shift;
					     push(@include_afters,
						  shift);},
	    "custom-target|ct=s"   => sub {$cust_target=1;
					   shift;
					   $make_target=shift;},
	    "relative-paths|r=s"   => sub {shift;
					   $base_path =
					       abs_canonical_path(shift);},
	    "svn-status"           => sub {push (@run_sources,
						 sub { my $target = shift;
						       print `svn status --no-ignore $target`;
						   })},
	    "tags-file=s"          => sub { shift;
					    my $tagfile = shift;
					    push (@run_sources,
						  sub { my $target = shift;
							print `etags -a -o $tagfile $target`;})},
	    "source-cmd=s"         => sub { shift;
					    my $cmd = shift;
					    push (@run_sources,
						  sub { my $target = shift;
							my $line = $cmd;
							$line =~ s/{}/$target/g;
							print `$line`;})},
	    "quiet|q"              => \$quiet,
	    "make-args=s"          => \@make_args,
	    "targets|t=s"          => sub {
		shift;
		my $fname=shift;
		open (my $tfile, $fname);
		while (my $the_line = <$tfile>) {
		    push (@targets, substr($the_line, 0, -1));
		}},
	    "debug"                => \$certlib_opts{"debugging"}
	    );

certlib_set_opts(\%certlib_opts);

print "System dir is " . $RealBin . "\n" unless $quiet;

push(@targets, @ARGV);

my %seen = ( );

# BOZO: This is crude.  Think of a better way to specify arguments to
# Make on the command line and pass them along.
@make_args = split(/\s*(\'[^\']*\'|\"[^\"]*\"|\S*)/,join(" ", @make_args));

foreach my $target (@targets) {
    $target = canonical_path($target);
    $target =~ s/\.lisp$/.cert/;
    add_deps($target, \%seen, \@run_sources);
}

unless ($no_makefile) {
    my $acl2 = $ENV{"ACL2"};
    unless ($acl2) {
	## die "Error: Shell variable ACL2 should be set for this to work correctly.\n";
	print "ACL2 defaults to acl2\n" unless $quiet;
	$acl2 = "acl2";
    }
    # Build the makefile and run make.
    open (my $mf, ">", $mf_name) or die "Failed to open output file $mf_name\n";
    print $mf '
ACL2 := ' . $acl2 . '
include ' . rel_path($RealBin, "make_cert") . '

';
    foreach my $incl (@includes) {
	print $mf '
include ' . $incl . '
';
    }
    
    if ($cust_target) {
	print $mf "CERT_PL_BOOKS := \n";
    } else {
	print $mf '.PHONY: all
all:
';
    }

    while ((my $key, my $value) = each %seen) {
	if ($value) { 
	    if ($cust_target) {
		print $mf "CERT_PL_BOOKS := \$(CERT_PL_BOOKS) $key\n";
	    } else {
		print $mf "all : $key\n";
	    }
	    my @the_deps = @{$value};
	    foreach my $dep (@the_deps) {
		print $mf "$key : $dep\n";
	    }
	}
    }

    foreach my $incl (@include_afters) {
	print $mf '
include ' . $incl . '
';
    }

    close($mf);
    
    unless ($no_build) {
	exec { "make" } ("make", "-j", $jobs, "-f", $mf_name, @make_args, $make_target);
    }
}




