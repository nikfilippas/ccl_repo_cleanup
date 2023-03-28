#!/bin/bash

# Usage: `$ ./reset.sh` (prompts for destination & origin repo URLs)
#
# This script creates an exact replica of a remote repo and pushes it to another
# remote repo, rewriting the commit history to exactly match the origin repo.
# It replicates all the branches and all the tags.

read -p "Enter test repo URL: " TEST
read -p "Enter original repo URL:" ORIGINAL

# Set defaults for my repo so I don't have to copy+paste every time.
[ -z "$TEST" ] && TEST="https://github.com/nikfilippas/cleanup_demo.git"
[ -z "$ORIGINAL" ] && ORIGINAL="https://github.com/LSSTDESC/CCL.git"

git clone $TEST current                                       # clone test tepo
git -C current push origin --delete $(git -C current tag -l)  # delete remote tags

git clone $ORIGINAL original                                  # clone original repo
git -C original remote set-url origin $TEST                   # change remote URL
git -C original push --force                                  # force-push history
git -C original push --tags                                   # push tags

# Force-push all the branches
cd original
for branch in $(git branch -r | grep -vE "HEAD|releases"); do
  branch_name=${branch#origin/}
  git checkout $branch_name
  git branch --set-upstream-to origin/$branch_name
  git push --force
done
cd ..

sudo rm -r current original
