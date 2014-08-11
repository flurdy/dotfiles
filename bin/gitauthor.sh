#!/bin/sh

git filter-branch --env-filter '

tn="My Name"
tm="myname@emample.com"

wm1="me@example.org"
wm2="my.name@example.org"

an="$GIT_AUTHOR_NAME"
am="$GIT_AUTHOR_EMAIL"
cn="$GIT_COMMITTER_NAME"
cm="$GIT_COMMITTER_EMAIL"

if [ "$GIT_COMMITTER_EMAIL" = "$wm1" ]
then
    cn="$tn"
    cm="$tm"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$wm1" ]
then
    an="$tn"
    am="$tm"
fi
if [ "$GIT_COMMITTER_EMAIL" = "$wm2" ]
then
    cn="$tn"
    cm="$tm"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$wm2" ]
then
    an="$tn"
    am="$tm"
fi

export GIT_AUTHOR_NAME="$an"
export GIT_AUTHOR_EMAIL="$am"
export GIT_COMMITTER_NAME="$cn"
export GIT_COMMITTER_EMAIL="$cm"
'
