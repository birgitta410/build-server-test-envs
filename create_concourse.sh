#!/usr/bin/env bash
set -e

rootDir=$(pwd)
envPath=environment/concourse
envDir="${rootDir}/${envPath}"

gitServerDir=$envDir/git-server
concourseDir=$envDir/concourse-server

setup() {
    echo -n "This will delete all files of previous Concourse environments - sure you want to continue? (y/n)"
    read answer
    if echo "$answer" | grep -iq "^y" ;then
        echo "Will continue to create a fresh environment"
    else
        echo "Exiting"
        exit
    fi

    cd $rootDir/concourse
    ! docker-compose stop
    ! docker-compose rm  -f

    # Prepare the local environment directory
    cd $rootDir/
    ! rm -rf ${envPath}
    mkdir -p ${envPath}
    
    mkdir $envDir/git-server

    #####################################################
    ############# Prepare git server
    echo "Preparing Git server..."
    
    mkdir $gitServerDir/keys
    mkdir $gitServerDir/repos

    # Create key pair for communication between servers
    keyName=id_rsa_concourse_env
    ssh-keygen -t rsa -C "local-concourse" -f $gitServerDir/keys/$keyName -q -N ""

    # Create repositories

    function create_repo() {
        # Utility script to send git commands to server later
        cp $rootDir/concourse/templates/git_local_server.sh $gitServerDir/$repoName/
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
    echo "A test repo for local Concourse environment" > $gitServerDir/$repoName/README.md
    cp $rootDir/templates/randomlyFails.sh $gitServerDir/$repoName/
    create_repo $repoName

    repoName=concourse-config
    mkdir -p $gitServerDir/$repoName
    echo "A repo to hold Concourse config" > $gitServerDir/$repoName/README.md
    cp $rootDir/concourse/templates/*.* $gitServerDir/$repoName/
    create_repo $repoName

    #####################################################
    ############# Prepare Concourse Server
    echo "Preparing Concourse server..."
    mkdir ${concourseDir}
    
    echo "github-private-key: |" > ${concourseDir}/credentials.yml
    cat $gitServerDir/keys/$keyName >> ${concourseDir}/credentials.yml
    # indent the key value
    sed -i.bak '2,100s/^/  /' ${concourseDir}/credentials.yml

    mkdir -p $concourseDir/home-dir/.ssh

    cp $gitServerDir/keys/$keyName.pub $concourseDir/home-dir/.ssh/id_rsa.pub
    cp $gitServerDir/keys/$keyName $concourseDir/home-dir/.ssh/id_rsa
    chmod 600 $concourseDir/home-dir/.ssh/id_rsa

    #####################################################
    ############# Start things up
    cd $rootDir/concourse
    docker-compose up -d

    sleep 2
    docker-compose ps
}

###############################
readonly BASE_URL="http://localhost:8080"

wait_for_server() {
    local url=$1
    echo -n " waiting for ${url}"
    until curl --output /dev/null --silent --head --fail "$url"; do
        printf '.'
        sleep 5
    done
}

provision_pipeline() {
    local fly_bin="/tmp/fly.$$"
    
    curl -vL "${BASE_URL}/api/v1/cli?arch=amd64&platform=darwin" -o "$fly_bin"
    chmod a+x "$fly_bin"

    "$fly_bin" -t buildviz login -c "$BASE_URL" -u user -p password
    "$fly_bin" -t buildviz set-pipeline -p pipeline -c "${rootDir}/concourse/templates/pipeline.yml" -n -l "${concourseDir}/credentials.yml"
    "$fly_bin" -t buildviz unpause-pipeline -p pipeline
    "$fly_bin" -t buildviz unpause-job -j pipeline/build-and-test
    "$fly_bin" -t buildviz trigger-job -j pipeline/build-and-test
    rm "$fly_bin"
    
}

############################

setup

cd $rootDir/concourse
wait_for_server "$BASE_URL"
provision_pipeline

