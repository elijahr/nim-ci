![Github Actions](https://github.com/elijahr/nim-ci/workflows/Build/badge.svg)
![Travis](https://travis-ci.org/elijahr/nim-ci.svg?branch=devel&status=errored)

Hassle-free continuous integration configs for your nim project.

Supported CI environments:

* Github Actions
* Travis

## Usage

If you are starting a new project, just click the ["Use this template"](https://github.com/elijahr/nim-ci/generate) button near the top of the page.

To add CI to an existing project:

### Github actions


```sh
cd path/to/my/project
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/devel/scripts/install_github_actions.sh | sh
git add .github
git commit -m "Added Github Actions CI"
git push
```

### Travis

```sh
cd path/to/my/project
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/devel/scripts/install_travis_ci.sh | sh
git add .travis.yml
git commit -m "Added Travis CI"
git push
```


Template Nim project with CI configurations to build binaries for Linux (amd64, arm64/aarch64), macOS (amd64), and Windows (amd64).

TODO: add to github marketplace


Copy the `.travis.yml` file into your repo and modify as needed. It will download
the latest `travis.sh` from this repo and setup the environment as required.

This script is used by various tools like [nimble](https://github.com/nim-lang/nimble),
[choosenim](https://github.com/dom96/choosenim), and
[nimterop](https://github.com/nimterop/nimterop).

