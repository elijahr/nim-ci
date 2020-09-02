#!/bin/sh

set -e

curl https://raw.githubusercontent.com/elijahr/nim-ci/devel/.travis.yml -LsSf > .travis.yml
echo "Installed .travis.yml. Next steps:"
echo
echo " * Enable Travis-CI for your repository at https://travis-ci.org"
echo " * Commit & push .travis.yml"
echo
