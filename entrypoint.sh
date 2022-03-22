#!/bin/sh -l

# echo "Hello $1"
# time=$(date)
# echo "::set-output name=time::$time"

# build_mode="refresh"
# build_environment=""
# deploy_diff=""
# build_refresh_days="99"

build_mode=$1
build_environment=$2
deploy_diff=$3
build_refresh_days=$4

git_branch=$(git rev-parse --abbrev-ref HEAD)
username=$(whoami)
computername=$HOSTNAME
git fetch --all --tags

# This executes for hotfix/* and feature/* branch pushes
if [ "$build_mode" == "feature" ]; then
	git checkout $git_branch
	git pull
	diff_cmd="git diff main.. --name-only --diff-filter=d"
fi

# On a merge to main deploy the latest commit to UAT
if [ "$build_mode" == "main" ] && [ "$build_environment" == "uat" ] && [ "$deploy_diff" != "tags" ]; then
  git checkout main
  commits=( $( git log --pretty='format:%h' -2 ) )
  diff_cmd="git diff ${commits[1]}..${commits[0]} --name-only --diff-filter=d"
fi

# On an explicit execution of the deploy action deploy the lastest tags diff to UAT
if [ "$build_mode" == "main" ] && [ "$build_environment" == "uat" ] && [ "$deploy_diff" == "tags" ]; then
  git checkout main
  git pull
	latest_tags=( $( git for-each-ref --sort=-taggerdate --format '%(tag)' --count=2 refs/tags ) )
	git checkout ${latest_tags[0]}
	diff_cmd="git diff ${latest_tags[1]}..${latest_tags[0]} --name-only --diff-filter=d"
fi

# On an explicit execution of the deploy action deploy the lastest tags diff to PRODUCTION
if [ "$build_mode" == "main" ] && [ "$build_environment" == "prd" ]; then
  git checkout main
  git pull
	latest_tags=( $( git for-each-ref --sort=-taggerdate --format '%(tag)' --count=2 refs/tags ) )
	git checkout ${latest_tags[0]}
	diff_cmd="git diff ${latest_tags[1]}..${latest_tags[0]} --name-only --diff-filter=d"
fi

if [ "$build_mode" == "refresh" ]; then
	git checkout main
	git pull
	refresh_hash=""
  date_since=$( date --date="$build_refresh_days days ago" +'%Y-%m-%d' )
  refresh_hash=$( git log --reverse --since="$( echo $date_since )" --pretty=format:"%h" | head -1 )
	diff_cmd="git diff $refresh_hash.. --name-only --diff-filter=d"
fi

echo "::set-output name=diff_cmd::$diff_cmd"
