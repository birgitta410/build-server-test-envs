#!/usr/bin/env bash

pwd=$(pwd)

############# Prepare git server
echo "Preparing Git server..."

! rm -rf ./git-server/temp
mkdir -p ./git-server/temp/myrepo

cp ./git-server/README.md ./git-server/temp/myrepo
cd ./git-server/temp/myrepo
git init --shared=true
git add .
git commit -m "first commit"
cd $pwd/git-server/temp
git clone --bare myrepo myrepo.git

cp -r myrepo.git $pwd/git-server/repos/myrepo.git

############# Prepare GOCD Server
echo "Preparing Go CD server..."
cd $pwd
! mkdir ./gocd-server/home-dir/.ssh
cp ./git-server/keys/id_rsa_git_test.pub ./gocd-server/home-dir/.ssh/id_rsa.pub
cp ./git-server/keys/id_rsa_git_test ./gocd-server/home-dir/.ssh/id_rsa
chmod 600 ./gocd-server/home-dir/.ssh/id_rsa

cd $pwd
cd docker-gocd-server
docker build -t gocd-server-custom .

############# Prepare GOCD Agent
echo "Preparing Go CD agent..."
cd $pwd
! mkdir ./gocd-agent1/home-dir/.ssh
cp ./git-server/keys/id_rsa_git_test.pub ./gocd-agent1/home-dir/.ssh/id_rsa.pub
cp ./git-server/keys/id_rsa_git_test ./gocd-agent1/home-dir/.ssh/id_rsa
chmod 600 ./gocd-agent1/home-dir/.ssh/id_rsa

cd $pwd
cd docker-gocd-agent
docker build -t gocd-agent-custom .

# Start things up
cd $pwd
docker-compose up -d

sleep 2
docker-compose ps

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "Wait for GoCD server to start up, then visit http://0.0.0.0:8153/go/pipelines"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
#sleep 10
#ssh git@localhost -p 2222 -i /Users/Shared/projects/build_monitors/monart/scripts/git-server/keys/id_rsa_git_test

# Use 0.0.0.0:8153 to do anything in the browser, otherwise CSRF errors on server
#curl 0.0.0.0:8153

# ssh://git@git-docker/git-server/repos/myrepo.git
