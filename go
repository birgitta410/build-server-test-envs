#!/usr/bin/env bash
set -e

ROOT_DIR=$(pwd)

function getEnvDir() {
    type=$1
    envPath=environment/$type
    echo "${ROOT_DIR}/${envPath}"
}

function getGitServerDir() {
    type=$1
    envDir=`getEnvDir $type`
    echo "${envDir}/git-server"
}

function getKeyNameForType() {
    type=$1
    echo "id_rsa_${type}_env"
}

function create_repo() {
    name=$1
    desc=$2
    gitServerDir=$3

    echo "Creating repo ${name} in ${gitServerDir}/${name}..."

    mkdir -p $gitServerDir/$name
    echo $desc > $gitServerDir/$name/README.md
    
    # Utility script to send git commands to server later
    cp $ROOT_DIR/concourse/templates/git_local_server.sh $gitServerDir/$name/
    echo "git_local_server.sh" > $gitServerDir/$name/.gitignore

    cd $gitServerDir/$name
    git init --shared=true
    git add .
    git commit -m "first commit"
    cd $gitServerDir
    git clone --bare $1 $1.git
    mv $name.git $gitServerDir/repos/$name.git
}

function setup_git_server() {
    type=$1
    gitServerDir=`getGitServerDir $type`

    echo "Preparing Git server..."
    
    # mkdir $gitServerDir

    keyName=`getKeyNameForType $type`
    mkdir -p $gitServerDir/keys
    mkdir -p $gitServerDir/repos

    # Create key pair for communication between servers
    ssh-keygen -t rsa -C "local-concourse" -f $gitServerDir/keys/$keyName -q -N ""

}

function setup_concourse() {
    type=concourse
    gitServerDir=`getGitServerDir $type`
    concourseDir=`getEnvDir "${type}/concourse-server"`

    # GIT REPO
    repoName=myrepo
    mkdir -p $gitServerDir/$repoName
    ls $gitServerDir/$repoName
    cp $ROOT_DIR/templates/randomlyFails.sh $gitServerDir/$repoName/
    echo "copied"
    create_repo $repoName "A test repo for local Concourse environment" $gitServerDir

    repoName=concourse-config
    mkdir -p $gitServerDir/$repoName
    cp $ROOT_DIR/concourse/templates/*.* $gitServerDir/$repoName/
    create_repo $repoName "A repo to hold Concourse config" $gitServerDir

    concourseDir=$envDir/concourse-server

    # CONCOURSE
    echo "Preparing Concourse server..."
    mkdir -p ${concourseDir}
    
    echo "github-private-key: |" > ${concourseDir}/credentials.yml
    cat $gitServerDir/keys/$keyName >> ${concourseDir}/credentials.yml
    # indent the key value
    sed -i.bak '2,100s/^/  /' ${concourseDir}/credentials.yml

    mkdir -p $concourseDir/home-dir/.ssh

    cp $gitServerDir/keys/$keyName.pub $concourseDir/home-dir/.ssh/id_rsa.pub
    cp $gitServerDir/keys/$keyName $concourseDir/home-dir/.ssh/id_rsa
    chmod 600 $concourseDir/home-dir/.ssh/id_rsa

    ## START THINGS UP
    cd $ROOT_DIR/concourse
    docker-compose up -d

    sleep 2
    docker-compose ps

}

function usage() {
    echo "./go concourse"
}

function setup_build_server() {
    type=$1
    echo "Setting up build server of type ${type}..."
    envDir=`getEnvDir $type`

    echo -n "This will delete all files of previous ${type} environments - sure you want to continue? (y/n)"
    read answer
    if echo "$answer" | grep -iq "^y" ;then
        echo "Will continue to create a fresh environment"
    else
        echo "Exiting"
        exit
    fi

    cd $ROOT_DIR/$type
    ! docker-compose stop
    ! docker-compose rm  -f


    # Prepare the local environment directory
    cd $ROOT_DIR/
    ! rm -rf ${envDir}
    mkdir -p ${envDir}
    
    setup_git_server $type

    case ${type} in
        concourse)  setup_concourse ;;
        *)          usage ;;
    esac

}


CMD=${1:-}
shift || true
case ${CMD} in
  concourse)  setup_build_server "concourse" ;;
  *)          usage ;;
esac
