#!/bin/bash

# ABSTRACT: developer tool to apply perltidy to all Perl files in the repository

# bash safeguards
set -o errexit -o nounset -o pipefail

# self-document this script
set -o xtrace

# must be executed from the project root to get all files
git ls-files |
    grep -E '\.(pl|pm|t)$' |
    xargs perltidy --backup-and-modify-in-place --backup-file-extension=/
