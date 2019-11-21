#!/usr/bin/env bash
set -e

# A crude little script to push things to our test repository without messing up the local ssh config with temporary keys

repoName=$(basename "$PWD")
! git remote add origin ssh://git@0.0.0.0:2222/root/$repoName.git

gitCmd=$1

ssh-agent bash -c "ssh-add ../keys/id_rsa_gitlab_env; ${gitCmd}"