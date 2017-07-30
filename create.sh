#!/usr/bin/env bash
set -e

rootDir=$(pwd)

! docker-compose stop
! docker-compose rm  -f

# Building docker images
cd docker-gocd-server
docker build -t gocd-server-custom .
cd ../docker-gocd-agent
docker build -t gocd-agent-custom .
cd ..

# Prepare the local environment directory
! rm -rf environment
mkdir environment
mkdir ./environment/git-server
mkdir ./environment/gocd-server
mkdir ./environment/gocd-agent1

cd environment
envDir=$(pwd)

############# Prepare git server
echo "Preparing Git server..."
cd $envDir

mkdir $envDir/git-server/keys
mkdir $envDir/git-server/repos
mkdir -p $envDir/git-server/myrepo-checked-out

# Create key pair for communication between servers
ssh-keygen -t rsa -C "local-gocd-env" -f $envDir/git-server/keys/id_rsa_gocd_env -q -N ""

echo "A test repo for local GoCD environment" > $envDir/git-server/myrepo-checked-out/README.md
cp $rootDir/templates/randomlyFails.sh $envDir/git-server/myrepo-checked-out/
cp $rootDir/templates/git_local_server.sh $envDir/git-server/myrepo-checked-out/
echo "git_local_server.sh" > $envDir/git-server/myrepo-checked-out/.gitignore
cd $envDir/git-server/myrepo-checked-out
git init --shared=true
git add .
git commit -m "first commit"
cd $envDir/git-server
git clone --bare myrepo-checked-out myrepo.git

mv myrepo.git $envDir/git-server/repos/myrepo.git

############# Prepare GOCD Server
echo "Preparing Go CD server..."

mkdir -p $envDir/gocd-server/home-dir/.ssh
mkdir -p $envDir/gocd-server/godata

cp $envDir/git-server/keys/id_rsa_gocd_env.pub $envDir/gocd-server/home-dir/.ssh/id_rsa.pub
cp $envDir/git-server/keys/id_rsa_gocd_env $envDir/gocd-server/home-dir/.ssh/id_rsa
chmod 600 $envDir/gocd-server/home-dir/.ssh/id_rsa

############# Prepare GOCD Agent
echo "Preparing Go CD agent..."

mkdir -p $envDir/gocd-agent1/home-dir/.ssh
mkdir -p $envDir/gocd-agent1/godata

cp $envDir/git-server/keys/id_rsa_gocd_env.pub $envDir/gocd-agent1/home-dir/.ssh/id_rsa.pub
cp $envDir/git-server/keys/id_rsa_gocd_env $envDir/gocd-agent1/home-dir/.ssh/id_rsa
chmod 600 $envDir/gocd-agent1/home-dir/.ssh/id_rsa

############# Start things up
cd $rootDir
docker-compose up -d

sleep 2
docker-compose ps

echo "##################################################################"
echo "GoCD server takes a little bit to start up, wait for it..."
echo "...then visit http://0.0.0.0:8153/go/pipelines (using localhost might have CSRF issues)"
echo "Wait for the agent to show up under 'Agents' and enable it."
echo "Then create a pipeline with Material 'ssh://git@git-docker/git-server/repos/myrepo.git'"
echo "##################################################################"
