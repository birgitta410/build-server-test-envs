#!/usr/bin/env bash
set -e

# A crude little script to push things to our test repository without messing up the local ssh config with temporary keys

! git remote add origin ssh://git@0.0.0.0:2222/git-server/repos/myrepo.git

gitCmd=$1

ssh-agent bash -c "ssh-add /Users/Shared/projects/build_monitors/gocd-test-env/environment/git-server/keys/id_rsa_gocd_env; ${gitCmd}"