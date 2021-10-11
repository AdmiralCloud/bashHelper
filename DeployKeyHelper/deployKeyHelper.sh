#!/usr/bin/env bash

CONFIG=~/.ssh/config
PATH_TO_REPOS=/opt
GIT_USER=admiralcloud

### SETUP an optional config.txt file with
#CONFIG=~/.ssh/config // path to SSH config for this user
#PATH_TO_REPOS=/PATH TO REPOS e.g. /opt or /home ...
#GIT_USER=

if test -f "config.txt"; then
  source config.txt
fi

read -e -i "$GIT_USER" -p "Github User: " input
GIT_USER="${input:-$GIT_USER}"

read -e -i "$PATH_TO_REPOS" -p "Path to repos (e.g./opt): " input
PATH_TO_REPOS="${input:-$PATH_TO_REPOS}"

read -p 'Repo Name: ' REPO_NAME

cd ~/.ssh

echo "Creating SSH Key for "$REPO_NAME
FILE=$REPO_NAME'_dk'
ssh-keygen -t ed25519 -N "" -C $REPO_NAME -f $FILE

chmod 400 $FILE

echo "Adding config to SSH"
echo "" >> $CONFIG
echo "Host $REPO_NAME.github.com" >> $CONFIG
echo "HostName github.com" >> $CONFIG
echo "User git" >> $CONFIG
echo "IdentityFile ~/.ssh/$FILE" >> $CONFIG
echo "IdentitiesOnly yes" >> $CONFIG

if [ -d "$PATH_TO_REPOS/$REPO_NAME" ]; then
  echo "Updating Remote URL for GIT"
  cd $PATH_TO_REPOS/$REPO_NAME
  git remote set-url origin git@$REPO_NAME.github.com:$GIT_USER/$REPO_NAME
else
  echo "Run the following script after you have cloned git repo and you discover connection issues"
  echo "git remote set-url origin git@$REPO_NAME.github.com:$GIT_USER/$REPO_NAME"
fi

echo ""
echo "Copy this as deployment key"
echo ""
cat ~/.ssh/$FILE'.pub'
