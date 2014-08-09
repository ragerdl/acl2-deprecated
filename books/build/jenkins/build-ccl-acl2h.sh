#!/bin/sh

# Cause the script to exit immediately upon failure
set -e

echo "Starting build-ccl-acl2h.sh"
echo " -- Running in `pwd`"
echo " -- Running on `hostname`"
echo " -- PATH is $PATH"

source $JENKINS_HOME/env.sh

ACL2DIR=`pwd`

LISP=`which ccl`
echo "Using LISP = $LISP"
echo "Using STARTJOB = `which startjob`"

echo "Making ACL2(h)"
startjob -c "make acl2h LISP=$LISP &> make.log" \
  --name "J_CCL_ACL2H" \
  --limits "pmem=4gb,nodes=1:ppn=1,walltime=10:00"

echo "Building the books."
cd acl2-devel/books
make ACL2=$ACL2DIR/acl2-devel/saved_acl2h all $MAKEOPTS USE_QUICKLISP=1

echo "Build was successful."

exit 0
