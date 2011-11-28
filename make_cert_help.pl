#!/usr/bin/env perl

# cert.pl build system
# Copyright (C) 2008-2011 Centaur Technology
#
# Contact:
#   Centaur Technology Formal Verification Group
#   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
#   http://www.centtech.com/
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.  This program is distributed in the hope that it will be useful but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.  You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
#
# Original authors: Sol Swords <sswords@centtech.com>
#                   Jared Davis <jared@centtech.com>
#
# NOTE: This file is not part of the standard ACL2 books build process; it is
# part of an experimental build system.  The ACL2 developers do not maintain
# this file.


# make_cert_help.pl -- this is a companion file that is used by "make_cert".
# It is the core script responsible for certifying a single ACL2 book.

# The code here is largely similar to the %.cert: %.lisp rule from
# Makefile-generic, but with several extensions.  For instance,
#
#   - We try to gracefully NFS lag, and
#   - We can certify certain books with other save-images, using .image files
#   - We support .acl2x files and two-pass certification,
#   - We support adding #PBS directives to limit memory and wall time
#   - We support running ACL2 via an external queuing mechanism.
#
# We only expect to invoke this through make_cert, so it is not especially
# user-friendly.  We rely on several environment variables that are given to us
# by make_cert.  See make_cert for the defaults and meanings of ACL2,
# COMPILE_FLG, and other variables used in this script.

# Usage: make_cert_help.pl TARGET TARGETEXT PASSES
#   - TARGET is like "foo" for "foo.lisp"
#   - TARGETEXT is "cert" or "acl2x"
#   - PASSES is 1 or 2


use warnings;
use strict;
use File::Spec;
use FindBin qw($RealBin);

sub read_whole_file
{
    my $filename = shift;
    open (my $fh, "<", $filename) or die("Can't open $filename: $!\n");
    local $/ = undef;
    my $ret = <$fh>;
    close($fh);
    return $ret;
}

sub read_whole_file_if_exists
{
    my $filename = shift;
    return "" if (! -f $filename);
    return read_whole_file($filename);
}

sub remove_file_if_exists
{
    my $filename = shift;
    if (-f $filename) {
	unlink($filename) or die("Can't remove $filename: $!\n");
    }
}

sub wait_for_nfs
{
    my $filename = shift;
    my $max_lag = shift;
    for(my $i = 0; $i < $max_lag; $i = $i++)
    {
	print "NFS Lag?  Waited $i seconds for $filename...\n";
	sleep(1);
	return 1 if (-f $filename);
    }
    return 0;
}

sub write_whole_file
{
    my $filename = shift;
    my $contents = shift;

    open(my $fd, ">", $filename) or die("Can't open $filename: $!\n");
    print $fd $contents;
    close($fd);
}

sub parse_max_mem_arg
{
    # Try to parse the "..." part of (set-max-mem ...), return #GB needed
    my $arg = shift;
    my $ret = 0;

    if ($arg =~ m/\(\* ([0-9]+) \(expt 2 30\)\)/) {
	# (* n (expt 2 30)) is n gigabytes
	$ret = $1;
    }
    elsif ($arg =~ m/\(\* \(expt 2 30\) ([0-9]+)\)/) {
	# (* (expt 2 30) n) is n gigabytes
	$ret = $1;
    }
    elsif ($arg =~ m/^\(expt 2 ([0-9]+)\)$/) {             # Example: arg is (expt 2 36)
	my $expt  = $1;                               # 36
	my $rexpt = ($expt > 30) ? ($expt - 30) : 0;  # 6  (but at least 0 in general)
	$ret      = 2 ** $rexpt;                      # 64 (e.g., 2^6)
    }
    else {
	print "Warning: skipping unsupported set-max-mem line: $arg\n";
	print "Currently supported forms:\n";
	print "  - (set-max-mem (expt 2 k))\n";
	print "  - (set-max-mem (* n (expt 2 30)))\n";
	print "  - (set-max-mem (* (expt 2 30) n))\n";
    }
    return $ret;
}

sub scan_for_set_max_mem
{
    my $filename = shift;

    open(my $fd, "<", $filename) or die("Can't open $filename: $!\n");
    while(<$fd>) {
	my $line = $_;
	chomp($line);
	if ($line =~ m/^[^;]*\((acl2::)?set-max-mem (.*)\)/)
	{
	    my $gb = parse_max_mem_arg($2);
	    return $gb;
	}
    }

    return 0;
}

sub scan_for_set_max_time
{
    my $filename = shift;

    open(my $fd, "<", $filename) or die("Can't open $filename: $!\n");
    while(<$fd>) {
	my $line = $_;
	chomp($line);
	if ($line =~ m/^[^;]*\((acl2::)?set-max-time (.*)\)/)
	{
	    my $minutes = $2;
	    return $minutes;
	}
    }
    return 0;
}

(my $TARGET, my $TARGETEXT, my $PASSES) = @ARGV;
my $INHIBIT     = $ENV{"INHIBIT"} || "";
my $HEADER      = $ENV{"OUTFILE_HEADER"} || "";
my $MAX_NFS_LAG = $ENV{"MAX_NFS_LAG"} || 100;
my $DEBUG       = $ENV{"ACL2_BOOKS_DEBUG"} ? 1 : 0;
my $FLAGS       = ($PASSES == "2") ? $ENV{"COMPILE_FLG_TWOPASS"} : $ENV{"COMPILE_FLG"};
my $TIME_CERT   = $ENV{"TIME_CERT"} ? 1 : 0;
my $STARTJOB    = $ENV{"STARTJOB"} || "";
my $ON_FAILURE_CMD = $ENV{"ON_FAILURE_CMD"} || "";
my $ACL2           = $ENV{"ACL2"};
# Figure out what ACL2 points to before we switch directories.

my $default_acl2 = `which $ACL2 2>/dev/null`;
if (($? >> 8) != 0) {
    print "Error: failed to find \$ACL2 ($ACL2) in the PATH.\n";
    exit(1);
}

if ($DEBUG)
{
    print "-- Starting up make_cert_help.pl in debug mode.\n";
    print "-- TARGET       = $TARGET\n";
    print "-- TARGETEXT    = $TARGETEXT\n";
    print "-- PASSES       = $PASSES\n";
    print "-- INHIBIT      = $INHIBIT\n";
    print "-- MAX_NFS_LAG  = $MAX_NFS_LAG\n";
    print "-- FLAGS        = $FLAGS\n";
    print "-- HEADER       = $HEADER\n";
    print "-- Default ACL2 = $default_acl2\n" if $DEBUG;
}

my $full_file = File::Spec->rel2abs($TARGET);
(my $vol, my $dir, my $file) = File::Spec->splitpath($full_file);
my $goal = "$file.$TARGETEXT";
print "Making $goal on `date`\n";

my $fulldir = File::Spec->canonpath(File::Spec->catpath($vol, $dir, ""));
print "-- Entering directory $fulldir\n" if $DEBUG;
chdir($fulldir) || die("Error switching to $fulldir: $!\n");

# Override ACL2 per the image file, as appropriate.
my $acl2 = read_whole_file_if_exists("$file.image");
$acl2 = read_whole_file_if_exists("cert.image") if !$acl2;
$acl2 = $default_acl2 if !$acl2;
chomp($acl2);
$ENV{"ACL2"} = $acl2;
print "-- Image to use = $acl2\n" if $DEBUG;
die("Can't determine which ACL2 to use.") if !$acl2;



my $timefile = "$file.time";
my $outfile = "$file.out";
if ($TARGETEXT eq "acl2x")
{
    $timefile = "$file.acl2x.time";
    $outfile = "$file.acl2x.out";
}

print "-- Removing files to be generated.\n" if $DEBUG;

remove_file_if_exists($goal);
remove_file_if_exists($timefile);
remove_file_if_exists($outfile);

write_whole_file($outfile, $HEADER);

# ------------ TEMPORARY LISP FILE FOR ACL2 INSTRUCTIONS ----------------------

my $rnd = int(rand(2**30));
my $tmpbase = "workxxx.$goal.$rnd";
my $lisptmp = "$tmpbase.lisp";
print "-- Temporary lisp file: $lisptmp\n" if $DEBUG;

my $instrs = "";

# I think this strange :q/lp dance is needed for lispworks or something?
$instrs .= "(acl2::value :q)\n";
$instrs .= "(in-package \"ACL2\")\n";
$instrs .= "(acl2::lp)\n\n";

$instrs .= "(set-write-acl2x t state)\n" if ($TARGETEXT eq "acl2x");
$instrs .= "$INHIBIT\n" if ($INHIBIT);

$instrs .= "\n";

# Get the certification instructions from foo.acl2 or cert.acl2, if either
# exists, or make a generic certify-book command.
if (-f "$file.acl2") {
    $instrs .= "; instructions from $file.acl2:\n";
    $instrs .= read_whole_file("$file.acl2");
    $instrs .= "\n";
}
elsif (-f "cert.acl2") {
    $instrs .= "; instructions from cert.acl2:\n";
    $instrs .= read_whole_file("cert.acl2");
    $instrs .= "\n; certify-book command added automatically:\n";
    $instrs .= "(time\$ #!ACL2 (certify-book \"$file\" ? $FLAGS))\n\n";
}
else {
    $instrs .= "; certify-book generated automatically:\n";
    $instrs .= "(time\$ #!ACL2 (certify-book \"$file\" ? $FLAGS))\n\n";
}


# Special hack so that ACL2 exits with 43 on success, or 0 on failure, so we
# can avoid looking at the file system in case of NFS lag.  See make_cert.lsp
# for details.  BOZO right now we're not doing any exit code magic for .acl2x
# files.  It'd be nice to fix that.
if ($TARGETEXT ne "acl2x") {
    $instrs .= "; exit code hack\n";
    $instrs .= "(acl2::ld \"make_cert.lsp\" :dir :system)\n";
    $instrs .= "(acl2::horrible-include-book-exit \"$file\" acl2::state)\n";
}

if ($DEBUG) {
    print "-- ACL2 Instructions ----------------------------------\n";
    print "$instrs\n";
    print "-------------------------------------------------------\n\n";
}

write_whole_file($lisptmp, $instrs);



# ------------ TEMPORARY SHELL SCRIPT FOR RUNNING ACL2 ------------------------

my $shtmp = "$tmpbase.sh";
my $shinsts = "#!/bin/sh\n\n";

# If we find a set-max-mem line, add 3 gigs of padding for the stacks and to
# allow the lisp to have some room to go over.  Default to 6 gigs.
my $max_mem = scan_for_set_max_mem("$file.lisp");
$max_mem = $max_mem ? ($max_mem + 3) : 6;

# If we find a set-max-time line, honor it directly; otherwise default to
# 240 minutes.
my $max_time = scan_for_set_max_time("$file.lisp") || 240;

print "-- Resource limits: $max_mem gigabytes, $max_time minutes.\n\n" if $DEBUG;

$shinsts .= "#PBS -l pmem=${max_mem}gb\n";
$shinsts .= "#PBS -l walltime=${max_time}:00\n\n";

if ($TIME_CERT) {
    $shinsts .= "(time (($acl2 < $lisptmp 2>&1) >> $outfile)) 2> $timefile\n";
}
else {
    $shinsts .= "($acl2 < $lisptmp 2>&1) >> $outfile\n";
}

if ($DEBUG) {
    print "-- Wrapper Script -------------------------------------\n";
    print "$shinsts\n";
    print "-------------------------------------------------------\n\n";
}

write_whole_file($shtmp, $shinsts);


# Run it!  ------------------------------------------------

system("$STARTJOB $shtmp");
my $status = $? >> 8;

unlink($lisptmp);
unlink($shtmp);



# Success or Failure Detection -------------------------------

my $success = 0;

if (-f $goal) {
    $success = 1;
    print "-- Immediate success detected\n" if $DEBUG;
}
elsif ($TARGETEXT ne "acl2x" && $status == 43) {
    # The exit code indicates that the file certified successfully, so why
    # doesn't it exist?  Maybe there's NFS lag.  Let's try waiting to see if
    # the file will show up.
    $success = wait_for_nfs($goal, $MAX_NFS_LAG);
    print "-- After waiting for NFS, success is $success\n" if $DEBUG;
}

if (!$success) {
    my $taskname = ($TARGETEXT eq "acl2x") ? "ACL2X GENERATION" : "CERTIFICATION";
    print "**$taskname FAILED** for $dir/$file.lisp\n\n";
    system("tail -300 $outfile | sed 's/^/   | /'");
    print "\n\n";

    if ($ON_FAILURE_CMD) {
	system($ON_FAILURE_CMD);
    }

    print "**CERTIFICATION FAILED** for $dir/$file.lisp\n\n";
    exit(1);
}

print "-- Final result appears to be success.\n" if $DEBUG;

# Else, we made it!
system("ls -l $goal");
exit(0);

