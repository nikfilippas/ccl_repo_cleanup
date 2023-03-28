#!/bin/bash

# Usage: `$ ./make_patches.sh /path/to/repo`
#
# This script creates a directory `patches_repo/` which contains patchfiles
# (diff files) for all remote branches of `repo`. Patchfiles can be used via
# `git apply /path/to/patch` to replay the differences in a branch.
#
# This is useful in cases where the commit history has changed and the local
# working repo is broken, as it saves time manually replaying all the commits.

mkdir -p patches_$NAME   # directory to save the patchfiles
for branch in $(git -C $NAME branch -r | grep -vE "HEAD|master|releases"); do
  # loop through all remote branches except for pointer `HEAD` and `releases/`
  echo -n "$branch..."
  branch_name=${branch#origin/}
  # and save the patchfile for later use
  git -C $NAME diff origin/HEAD..${branch} >> patches_$NAME/$branch_name.patch
  echo "done"
done
