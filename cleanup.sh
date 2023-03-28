#!/bin/bash

# Usage: `$ ./cleanup.sh` (prompts for repo URL)
#
# This script is tailored for use with LSST DESC CCL.
#
# It cleans up large files from the repo commit history, drastically reducing
# the total repo size. The tool used is [bfg](https://rtyley.github.io/bfg-repo-cleaner/)
# which automatically recreates a mapping from the old hash to the new hash of
# every commit in the history. This also allows it to automatically update all
# branches, as well as tags.
#
# Optionally, it renames the tags using standard [semantic versioning](https://semver.org/),
# and pushes the updated names to the remote repo.
#
# The script is split into 7 sections, each doing one task:
#   1. Prompts for remote URL and defines internal variables.
#   2. Saves a backup of the remote repo locally, which can be used to revert
#      all the changes should anything go wrong.
#   3. `bfg` protects `HEAD`, so this step brings the head to its final desired
#      state, making any deletions/modifications.
#   4. Downloads `bfg`.
#   5. Runs `bfg`. Remaps commits, branches, tags.
#   6. Fixes tag names, if they do not follow semantic versioning rules. When
#      this step completes, we need to clean up all tags from the remote, or
#      there will be orphaned tags.
#   7. Pushes the changes to the remote. 
#      Downloads a fresh clone of the cleaned repo and prints repo size stats.
#      Note that `bfg` also updates all the hidden refs (such as references to
#      pull requests). Most hosting websites, including GitHub, do not allow
#      updating hidden refs, so these will be rejected.


## 1. Repo URL input by user
read -p "Enter repo URL: " URL
NAME=$(echo $URL | sed 's/.*\///' | sed 's/\.git//')  # extract repo name
mkdir -p cleanup && cd cleanup  # create an empty directory and switch to it
echo "Cleaning up ${NAME} at ${URL}."


## 2. Create backup
echo "Cloning & creating backup."
git clone $URL           # download a fresh clone of the repo
cp -r $NAME "$NAME"_bak  # create a backup


## 3. Clean up protected HEAD
echo "Cleaning up HEAD."
cd $NAME
rm -r benchmarks/data doc examples                     # remove all the things that take up space
git add . && git commit -m "REPO CLEANUP" && git push  # commit the changes and push
cd ..


## 4. Set up `bfg`
curl https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar --output bfg.jar  # download bfg
shopt -s expand_aliases && alias bfg="java -jar bfg.jar"  # allow aliases and set `bfg` as an alias for simpler call


## 5. Clean up the refs/history of the bare repo
echo "Cleaning up the refs/history of the local repo."
git clone --mirror $URL                               # download a bare copy of the repo
bfg --delete-folders "{data,doc,examples}" $NAME.git  # clean up commit history for the specific directories
cd $NAME.git
git reflog expire --expire=now --all                  # expire all the orphaned files from history
git gc --prune=now --aggressive                       # run the garbage collector to remove expired files


## 6. (Optional) Fix tag names using semantic versioning.
for tag_old in $(git tag --sort=-creatordate); do  # loop through the original tags
  tag_new=$tag_old

  [[ "${tag_new}" != v* ]] && tag_new="v${tag_new}"              # e.g. [0.3.2      --> v0.3.2]
  [[ "${tag_new}" == *.*.* ]] || tag_new="${tag_new}.0"          # e.g. [v0.3       --> v0.3.0]
  [[ "${tag_new}" == *-rc.* ]] || tag_new="${tag_new//rc/-rc.}"  # e.g. [v2.0.0rc1  --> v2.0.0-rc.1]
  
  if [[ "${tag_new}" != "${tag_old}" ]]; then
    echo "Replacing ${tag_old} with ${tag_new}."
    git tag $tag_new $tag_old^{}  # rename the local (dereferenced) tag if needed
    git tag -d $tag_old           # delete the local old tag
  fi
done

echo "Fixed tag names. Deleting remote tags"
git -C ../$NAME push origin --delete $(git -C ../$NAME tag -l)  # delete remote tags


## 7. Push & finalize
echo "Updating the refs of the remote repo."
git push --force  # force-push (because it re-writes commit history)
cd ..

mv $NAME ${NAME}_old && git clone $URL     # clone the cleaned-up repo
echo "Cleaned-up repo cloned in ${NAME}."

OLD_SIZE=$(du -sh ${NAME}_bak | awk '{print $1}')
NEW_SIZE=$(du -sh $NAME | awk '{print $1}')
echo "Repo size reduced from ${OLD_SIZE} to ${NEW_SIZE}."
cd ..
