#!/bin/sh

BASEDIR="$(dirname "$(readlink -f "$0")")"

# generate RDoc
cd lib/posixpsutil
# rdoc doesn't allow we overwrite an existed directory, so I use hardcode instead of `mktemp`
TEMP=/tmp/Posixpsutil
rdoc -f darkfish -o "$TEMP" process.rb psutil_error.rb linux/system.rb

# check out and commit to gh page
cd "$BASEDIR"
git branch gh-pages > /dev/null 2>&1 || git checkout gh-pages || exit
cp ${TEMP}/* "$BASEDIR"
rmdir $TEMP

