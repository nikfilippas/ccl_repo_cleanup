#!/bin/bash

## 1. Repo URL input by user
read -p "Enter repo URL: " URL
NAME=$(echo $URL | sed 's/.*\///' | sed 's/\.git//')  # extract repo name
echo "Cleaning up ${NAME} at ${URL}."

## 2. Set up `bfg`
mkdir -p cleanup && cd cleanup  # create an empty directory and switch to it
curl https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar --output bfg.jar  # download bfg
shopt -s expand_aliases && alias bfg="java -jar bfg.jar"  # allow aliases and set `bfg` as an alias for simpler call

## 3. Clean up protected HEAD
echo "Cleaning up HEAD."
git clone $URL && cp -r $NAME "$NAME"_bak  # download a fresh copy of the repo and keep a backup
cd $NAME
rm -r benchmarks/data doc examples                     # remove all the things that take up space
git add . && git commit -m "REPO CLEANUP" && git push  # commit the changes and push
cd ..

## 4. Clean up the refs/history of the bare repo
echo "Cleaning up the refs/history of the local repo."
git clone --mirror $URL                               # download a bare copy of the repo
bfg --delete-folders "{data,doc,examples}" $NAME.git  # clean up commit history for the specific directories
cd $NAME.git
git reflog expire --expire=now --all                  # expire all the orphaned files from history
git gc --prune=now --aggressive                       # run the garbage collector to remove expired files


## 5. (Optional) Fix tag names using semantic versioning (https://semver.org/)
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

echo "Deleting remote tags"
git -C ../$NAME push origin --delete $(git -C ../$NAME tag -l)  # delete remote tags
echo "Updating the refs of the remote repo."
git push --force  # force-push (because it re-writes commit history)
cd ..

## 6. Print info
mv $NAME ${NAME}_old && git clone $URL     # clone the cleaned-up repo
echo "Cleaned-up repo cloned in ${NAME}."

OLD_SIZE=$(du -sh ${NAME}_bak | awk '{print $1}')
NEW_SIZE=$(du -sh $NAME | awk '{print $1}')
echo "Repo size reduced from ${OLD_SIZE} to ${NEW_SIZE}."
