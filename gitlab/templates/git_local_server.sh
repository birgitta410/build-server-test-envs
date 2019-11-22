#!/usr/bin/env bash
set -e

# A crude little script to push things to our test repository without messing up the local ssh config with temporary keys

! git remote add origin ssh://git@0.0.0.0:2223/root/test.git

gitCmd=$1

GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" ssh-agent bash -c "ssh-add ../keys/id_rsa_gitlab_env; ${gitCmd}"