#!/usr/bin/env bash

pwd=$(pwd)

# Prepare git server
echo "Preparing Git server..."

! rm -rf ./temp
mkdir -p temp/myrepo

cp git-server/README.md temp/myrepo
cd temp/myrepo
git init --shared=true
git add .
git commit -m "first commit"
cd $pwd/temp
git clone --bare myrepo myrepo.git

cp -r myrepo.git $pwd/git-server/repos/

# Prepare gocd
echo "Preparing Go CD..."
cd $pwd
cp ./git-server/keys/id_rsa_git_test.pub ./gocd-server/home-dir/.ssh/id_rsa.pub
cp ./git-server/keys/id_rsa_git_test ./gocd-server/home-dir/.ssh/id_rsa

# Start things up
docker-compose up -d

sleep 2
docker-compose ps

#sleep 10
#ssh git@localhost -p 2222 -i /Users/Shared/projects/build_monitors/monart/scripts/git-server/keys/id_rsa_git_test

# Use 0.0.0.0:8153 to do anything in the browser, otherwise CSRF errors on server
#curl 0.0.0.0:8153

# ssh-keyscan -t rsa git-docker  > /home/go/.ssh/known_hosts

# ssh://git@git-docker/git-server/repos/myrepo.git
