#!/bin/sh

set -e

mkdir -p .github/workflows
curl https://raw.githubusercontent.com/elijahr/nim-ci/devel/.github/workflows/build.yml -LsSf > .github/workflows/build.yml

echo "Installed .github/workflows/build.yml. Next steps:"
echo
echo " * Enable GitHub Actions for your repository at https://github.com"
echo " * Commit & push .github"
echo
