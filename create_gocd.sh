#!/usr/bin/env bash
set -e

echo -n "This will delete all files of previous GoCD environments - sure you want to continue? (y/n)"
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Will continue to create a fresh environment"
else
    echo "Exiting"
    exit
fi


rootDir=$(pwd)

cd $rootDir/gocd
! docker-compose stop
! docker-compose rm  -f

# Build docker images
cd $rootDir/gocd/docker-gocd-server
docker build -t gocd-server-custom .
cd $rootDir/gocd/docker-gocd-agent
docker build -t gocd-agent-custom .

# Prepare the local environment directory
cd $rootDir/
! rm -rf environment/gocd
mkdir -p environment/gocd
envDir=$rootDir/environment/gocd

mkdir $envDir/git-server
mkdir $envDir/gocd-server
mkdir $envDir/gocd-agent1

#####################################################
############# Prepare git server
echo "Preparing Git server..."
gitServerDir=$envDir/git-server

mkdir $gitServerDir/keys
mkdir $gitServerDir/repos

# Create key pair for communication between servers
keyName=id_rsa_gocd_env
ssh-keygen -t rsa -C "local-gocd" -f $gitServerDir/keys/$keyName -q -N ""

# Create repositories

function create_repo() {
  # Utility script to send git commands to server later
  cp $rootDir/gocd/templates/git_local_server.sh $gitServerDir/$repoName/
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
  cp $rootDir/gocd/templates/pipeline-config/*.gopipeline.json $gitServerDir/$repoName/
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
cp $rootDir/gocd/templates/cruise-config.xml $goServerDir/godata/config

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
cd $rootDir/gocd
docker-compose up -d

sleep 2
docker-compose ps

echo ""
echo "##################################################################"
echo "GoCD server takes a little bit to start up, wait for it..."
echo "[ tail logs with 'tail -f environment/gocd/gocd-server/godata/logs/go-server.log' ]"
echo "...then visit http://0.0.0.0:8153/go/pipelines (using localhost causes CSRF issues)"
echo "Wait for pipeline configured through JSON plugin to show up under 'Pipelines'."
echo "Wait for the agent to show up under 'Agents' and enable it."
echo "##################################################################"
