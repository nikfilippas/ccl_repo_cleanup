#!/bin/bash

# 

read -p "Enter repo URL: " URL
[ -z "$NEW_HASH" ] && URL="https://github.com/nikfilippas/cleanup_demo.git"
NAME=$(echo $URL | sed 's/.*\///' | sed 's/\.git//')  # extract repo name

git clone $URL CCL_current
git -C CCL_current push origin --delete $(git -C CCL_current tag -l)  # delete remote tags

git clone https://github.com/LSSTDESC/CCL.git CCL_reset  # clone original CCL
git -C CCL_reset remote set-url origin $URL              # change remote URL
git -C CCL_reset push --force                            # force-push history
git -C CCL_reset push --tags                             # push tags
sudo rm -r CCL_current CCL_reset
