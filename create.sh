#!/usr/bin/env bash
set -e

rootDir=$(pwd)

! docker-compose stop
! docker-compose rm  -f

# Build docker images
cd $rootDir/docker-gocd-server
docker build -t gocd-server-custom .
cd $rootDir/docker-gocd-agent
docker build -t gocd-agent-custom .

# Prepare the local environment directory
cd $rootDir/
! rm -rf environment
mkdir environment
mkdir ./environment/git-server
mkdir ./environment/gocd-server
mkdir ./environment/gocd-agent1

envDir=$rootDir/environment

#####################################################
############# Prepare git server
echo "Preparing Git server..."
gitServerDir=$envDir/git-server

mkdir $gitServerDir/keys
mkdir $gitServerDir/repos

# Create key pair for communication between servers
keyName=id_rsa_gocd_env
ssh-keygen -t rsa -C "local-gocd-env" -f $gitServerDir/keys/$keyName -q -N ""

# Create repositories

function create_repo() {
  # Utility script to send git commands to server later
  cp $rootDir/templates/git_local_server.sh $gitServerDir/$repoName/
  echo "git_local_server.sh" > $gitServerDir/$repoName/.gitignore

  cd $gitServerDir/$repoName
  git init --shared=true
  git add .
  git commit -m "first commit"
  cd $gitServerDir
  git clone --bare $1 $1.git
  mv $1.git $gitServerDir/repos/$1.git
}

repoName=myrepo
mkdir -p $gitServerDir/$repoName
  echo "A test repo for local GoCD environment" > $gitServerDir/$repoName/README.md
  cp $rootDir/templates/randomlyFails.sh $gitServerDir/$repoName/
create_repo $repoName

repoName=gocd-config
mkdir -p $gitServerDir/$repoName
  echo "A repo to hold Go CD config" > $gitServerDir/$repoName/README.md
  cp $rootDir/templates/pipeline-config/*.gopipeline.json $gitServerDir/$repoName/
create_repo $repoName

#####################################################
############# Prepare GOCD Server
echo "Preparing Go CD server..."
goServerDir=$envDir/gocd-server

mkdir -p $goServerDir/home-dir/.ssh
mkdir -p $goServerDir/godata

cp $gitServerDir/keys/$keyName.pub $goServerDir/home-dir/.ssh/id_rsa.pub
cp $gitServerDir/keys/$keyName $goServerDir/home-dir/.ssh/id_rsa
chmod 600 $goServerDir/home-dir/.ssh/id_rsa

mkdir -p $goServerDir/godata/plugins/external
wget https://github.com/tomzo/gocd-json-config-plugin/releases/download/0.2.0/json-config-plugin-0.2.jar -O $goServerDir/godata/plugins/external/json-config-plugin-0.2.jar

mkdir -p $goServerDir/godata/config
cp $rootDir/templates/cruise-config.xml $goServerDir/godata/config

#####################################################
############# Prepare GOCD Agent
echo "Preparing Go CD agent..."
goAgentDir=$envDir/gocd-agent1

mkdir -p $goAgentDir/home-dir/.ssh
mkdir -p $goAgentDir/godata

cp $gitServerDir/keys/$keyName.pub $goAgentDir/home-dir/.ssh/id_rsa.pub
cp $gitServerDir/keys/$keyName $goAgentDir/home-dir/.ssh/id_rsa
chmod 600 $goAgentDir/home-dir/.ssh/id_rsa

#####################################################
############# Start things up
cd $rootDir
docker-compose up -d

sleep 2
docker-compose ps

echo ""
echo "##################################################################"
echo "GoCD server takes a little bit to start up, wait for it..."
echo "[ tail logs with 'tail -f environment/gocd-server/godata/logs/go-server.log' ]"
echo "...then visit http://0.0.0.0:8153/go/pipelines (using localhost causes CSRF issues)"
echo "Wait for pipeline configured through JSON plugin to show up under 'Pipelines'."
echo "Wait for the agent to show up under 'Agents' and enable it."
echo "##################################################################"
