#!/usr/bin/env bash
set -e

rootDir=$(pwd)

cd $rootDir/teamcity
! docker-compose stop
! docker-compose rm  -f


# Prepare the local environment directory
cd $rootDir/
! rm -rf environment/teamcity
mkdir -p environment/teamcity
envDir=$rootDir/environment/teamcity

mkdir $envDir/git-server
mkdir $envDir/teamcity-server
mkdir $envDir/teamcity-agent1


#####################################################
############# Prepare git server
echo "Preparing Git server..."
gitServerDir=$envDir/git-server

mkdir $gitServerDir/keys
mkdir $gitServerDir/repos

# Create key pair for communication between servers
keyName=id_rsa_teamcity_env
ssh-keygen -t rsa -C "local-gocd-env" -f $gitServerDir/keys/$keyName -q -N ""

# Create repositories

function create_repo() {
  # Utility script to send git commands to server later
  cp $rootDir/teamcity/templates/git_local_server.sh $gitServerDir/$repoName/
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
  echo "A test repo for local build server environment" > $gitServerDir/$repoName/README.md
  cp $rootDir/templates/randomlyFails.sh $gitServerDir/$repoName/
create_repo $repoName

repoName=teamcity-config
mkdir -p $gitServerDir/$repoName
  echo "A repo to hold TeamCity config" > $gitServerDir/$repoName/README.md
create_repo $repoName

#####################################################
############# Prepare Teamcity Server
echo "Preparing TeamCity server..."
teamCityServerDir=$envDir/teamcity-server

mkdir -p $teamCityServerDir/home-dir/.ssh
mkdir -p $teamCityServerDir/datadir
mkdir -p $teamCityServerDir/logs

cp $gitServerDir/keys/$keyName.pub $teamCityServerDir/home-dir/.ssh/id_rsa.pub
cp $gitServerDir/keys/$keyName $teamCityServerDir/home-dir/.ssh/id_rsa
chmod 600 $teamCityServerDir/home-dir/.ssh/id_rsa

#####################################################
############# Prepare TeamCity Agent
echo "Preparing TeamCity agent..."
teamCityAgentDir=$envDir/teamcity-agent1

mkdir -p $teamCityAgentDir/home-dir/.ssh
mkdir -p $teamCityAgentDir/conf
mkdir -p $teamCityAgentDir/logs

cp $gitServerDir/keys/$keyName.pub $teamCityAgentDir/home-dir/.ssh/id_rsa.pub
cp $gitServerDir/keys/$keyName $teamCityAgentDir/home-dir/.ssh/id_rsa
chmod 600 $teamCityAgentDir/home-dir/.ssh/id_rsa

#####################################################
############# Start things up
cd $rootDir/teamcity
docker-compose up -d

sleep 2
docker-compose ps

echo ""
echo "##################################################################"
echo "[ tail server logs with 'tail -f environment/teamcity/teamcity-server/logs/teamcity-server.log' ]"
echo "[ tail agent logs with 'tail -f environment/teamcity/teamcity-agent1/logs/teamcity-agent.log' ]"
echo "TeamCity is available at http://0.0.0.0:8111/"
echo "To get Super User authentication token: 'cat environment/teamcity/teamcity-server/logs/teamcity-server.log | grep Super'"
echo "Wait for the agent to show up under 'Agents' > 'Unauthorized' and authorize it, then wait for it to show up under 'Connected'."
echo "##################################################################"
