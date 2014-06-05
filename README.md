Merged ACL2+Books Git Repository
================================

**Warning** -- experimental, unofficial, unsanctioned, etc.

This repository is intended only for evaluation of how hard it would be to
migrate acl2-books and acl2-devel from Google Code to Github.

# Creation notes

```
 # convert acl2-books/acl2-devel to git
 git svn clone \
   --stdlayout \
   --prefix='svn/' \
   http://acl2-books.googlecode.com/svn \
   acl2-books.git | tee acl2-books.clone.log

 git svn clone \
   --stdlayout \
   --prefix='svn/' \
   http://acl2-devel.googlecode.com/svn \
   acl2-devel.git | tee acl2-devel.clone.log

 # prepare new repository for the merge
 git init new
 cd new
 touch temp.txt
 git add temp.txt
 git commit -m "temporary commit"
 git rm temp.txt
 git commit -m "remove temporary file"

 # bring in both repositories
 git remote add books ../acl2-books
 git remote add devel ../acl2-devel
 git fetch

 # merge full history of acl2-books and move it to books/
 git merge books/master
 mkdir books
 git add books
 git mv `ls -1  | grep -v books` books
 git mv .gitignore books
 git commit -m "move merged books into books subdirectory"

 # merge full history of acl2-devel
 git merge devel/master

 # upload to github (after creating acl2.git repo there)
 git remote add origin https://github.com/jaredcdavis/acl2.git
 git push -u origin master
```

