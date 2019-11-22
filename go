#!/usr/bin/env bash
set -e

ROOT_DIR=$(pwd)

BLUE='\033[1;34m'
NC='\033[0m' # No Color

logColoredLine() {
    printf "${BLUE}${1}${NC}\n"
}

wait_for_server() {
    local url=$1
    echo -n " waiting for ${url}"
    until curl --output /dev/null --silent --head --fail "$url"; do
        printf '.'
        sleep 5
    done
    logColoredLine "\n${url} is up"
}

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

function getKeyNameForSetupType() {
    type=$1
    echo "id_rsa_${type}_env"
}

function create_repo() {
    name=$1
    desc=$2
    gitServerDir=$3
    type=$4

    echo "Creating repo ${name} in ${gitServerDir}/${name} for setup ${type}..."

    mkdir -p $gitServerDir/$name
    echo $desc > $gitServerDir/$name/README.md
    
    # Utility script to send git commands to server later
    cp $ROOT_DIR/${type}/templates/git_local_server.sh $gitServerDir/$name/
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

    logColoredLine "Preparing Git server dir and keys..."

    keyName=`getKeyNameForSetupType $type`
    mkdir -p $gitServerDir/keys
    mkdir -p $gitServerDir/repos

    # Create key pair for communication between servers
    ssh-keygen -t rsa -C "local-${type}" -f $gitServerDir/keys/$keyName -q -N ""

}

function setup_gocd {
    type=gocd
    envDir=`getEnvDir $type`
    gitServerDir=`getGitServerDir $type`

    logColoredLine "Setup GoCD Server and Agent..."

    # GIT REPOS
    repoName=myrepo
    mkdir -p $gitServerDir/$repoName
    cp $ROOT_DIR/templates/randomlyFails.sh $gitServerDir/$repoName/
    create_repo $repoName "A test repo for local GoCD environment" $gitServerDir $type

    repoName=gocd-config
    mkdir -p $gitServerDir/$repoName
    cp $ROOT_DIR/gocd/templates/pipeline-config/*.gopipeline.json $gitServerDir/$repoName/
    create_repo $repoName "A repo to hold Go CD config" $gitServerDir $type

    # Build docker images
    cd $ROOT_DIR/gocd/docker-gocd-server
    docker build -t gocd-server-custom .
    cd $ROOT_DIR/gocd/docker-gocd-agent
    docker build -t gocd-agent-custom .

    mkdir $envDir/gocd-server
    mkdir $envDir/gocd-agent1

    # GO SERVER
    echo "Preparing Go CD server..."
    goServerDir=$envDir/gocd-server
    keyName=`getKeyNameForSetupType $type`

    mkdir -p $goServerDir/home-dir/.ssh
    mkdir -p $goServerDir/godata

    cp $gitServerDir/keys/$keyName.pub $goServerDir/home-dir/.ssh/id_rsa.pub
    cp $gitServerDir/keys/$keyName $goServerDir/home-dir/.ssh/id_rsa
    chmod 600 $goServerDir/home-dir/.ssh/id_rsa

    mkdir -p $goServerDir/godata/plugins/external
    wget https://github.com/tomzo/gocd-json-config-plugin/releases/download/0.2.0/json-config-plugin-0.2.jar -O $goServerDir/godata/plugins/external/json-config-plugin-0.2.jar

    mkdir -p $goServerDir/godata/config
    cp $ROOT_DIR/gocd/templates/cruise-config.xml $goServerDir/godata/config

    ############# Prepare GOCD Agent
    echo "Preparing Go CD agent..."
    goAgentDir=$envDir/gocd-agent1

    mkdir -p $goAgentDir/home-dir/.ssh
    mkdir -p $goAgentDir/godata

    cp $gitServerDir/keys/$keyName.pub $goAgentDir/home-dir/.ssh/id_rsa.pub
    cp $gitServerDir/keys/$keyName $goAgentDir/home-dir/.ssh/id_rsa
    chmod 600 $goAgentDir/home-dir/.ssh/id_rsa

}

function setup_concourse() {
    type=concourse
    gitServerDir=`getGitServerDir $type`
    concourseDir=`getEnvDir "${type}/concourse-server"`

    logColoredLine "Setup Concourse..."

    # GIT REPO
    repoName=myrepo
    mkdir -p $gitServerDir/$repoName
    ls $gitServerDir/$repoName
    cp $ROOT_DIR/templates/randomlyFails.sh $gitServerDir/$repoName/
    create_repo $repoName "A test repo for local Concourse environment" $gitServerDir $type

    repoName=concourse-config
    mkdir -p $gitServerDir/$repoName
    cp $ROOT_DIR/concourse/templates/*.* $gitServerDir/$repoName/
    create_repo $repoName "A repo to hold Concourse config" $gitServerDir $type

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

}

function setup_gitlab() {
    
    type=gitlab
    gitServerDir=`getGitServerDir $type`

    logColoredLine "Setup gitlab..."

    # Add the key that we have in the gitlab baseline backup
    rm -rf ${gitServerDir}/keys
    cp -r ./gitlab/templates/keys ${gitServerDir}/
    
    repoName=test
    mkdir -p $gitServerDir/$repoName
    cp $ROOT_DIR/templates/randomlyFails.sh $gitServerDir/$repoName/
    create_repo $repoName "A test repo for local GoCD environment" $gitServerDir $type
    
}

function usage() {
    echo "./go concourse | gocd | gitlab | gitlab-backup"
}

function when_started_concourse() {
    readonly BASE_URL="http://localhost:8080"
    provision_pipeline() {
        local fly_bin="/tmp/fly.$$"
        
        curl -vL "${BASE_URL}/api/v1/cli?arch=amd64&platform=darwin" -o "$fly_bin"
        chmod a+x "$fly_bin"

        "$fly_bin" -t buildviz login -c "$BASE_URL" -u user -p password
        "$fly_bin" -t buildviz set-pipeline -p pipeline -c "${ROOT_DIR}/concourse/templates/pipeline.yml" -n -l "${concourseDir}/credentials.yml"
        "$fly_bin" -t buildviz unpause-pipeline -p pipeline
        "$fly_bin" -t buildviz unpause-job -j pipeline/build-and-test
        "$fly_bin" -t buildviz trigger-job -j pipeline/build-and-test
        rm "$fly_bin"
        
    }
    cd $ROOT_DIR/concourse
    wait_for_server "$BASE_URL"
    provision_pipeline
}

function when_started_gocd() {
    echo ""
    echo "##################################################################"
    echo "GoCD server takes a little bit to start up, wait for it..."
    echo "[ tail logs with 'tail -f environment/gocd/gocd-server/godata/logs/go-server.log' ]"
    logColoredLine "...then visit http://0.0.0.0:8153/go/pipelines (using localhost causes CSRF issues)"
    echo "Wait for pipeline configured through JSON plugin to show up under 'Pipelines'."
    echo "Wait for the agent to show up under 'Agents' and enable it."
    echo "##################################################################"

}

function when_started_gitlab() {
    
    wait_for_server "http://localhost:8888"

    gitlabConfigPath=$ROOT_DIR/environment/gitlab/gitlab/etc/gitlab

    cp $ROOT_DIR/gitlab/templates/gitlab.rb ${gitlabConfigPath}/
    cp $ROOT_DIR/gitlab/templates/gitlab-secrets.json ${gitlabConfigPath}/
    
    logColoredLine "Restoring backup file with some basic configuration..."
    gitlabConfigPath=$ROOT_DIR/environment/gitlab/gitlab/etc/gitlab
    mkdir ${gitlabConfigPath}/backups
    cp $ROOT_DIR/gitlab/templates/gitlab_backup.tar ${gitlabConfigPath}/backups/
    cp $ROOT_DIR/gitlab/restore_backup.sh ${gitlabConfigPath}/backups/
    docker exec gitlab_gitlab_1 /etc/gitlab/backups/restore_backup.sh

    echo ""
    echo "##################################################################"
    logColoredLine "Gitlab is running on localhost:8888"    
    echo "username 'root', password 'Passw0rd1234'"
    echo ""

}

function create_gitlab_backup() {
    gitlabConfigPath=./environment/gitlab/gitlab/etc/gitlab

    cp $ROOT_DIR/gitlab/create_backup.sh ${gitlabConfigPath}/backups/
    docker exec gitlab_gitlab_1 /etc/gitlab/backups/create_backup.sh
    ls ${gitlabConfigPath}/backups/new_gitlab_backup.tar
    cp ${gitlabConfigPath}/backups/new_gitlab_backup.tar ./gitlab/templates/gitlab_backup.tar
}

function when_started() {
    type=$1
    case ${type} in
        concourse)  when_started_concourse ;;
        gocd)       when_started_gocd ;;
        gitlab)     when_started_gitlab ;;
        *)          usage ;;
    esac
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
        gocd)       setup_gocd ;;
        gitlab)     setup_gitlab ;;
        *)          usage ;;
    esac

    ## START THINGS UP
    logColoredLine "Done with prepping things, ready to start up!"
    cd $ROOT_DIR/$type
    docker-compose up -d

    sleep 2
    docker-compose ps

    when_started $type
}


CMD=${1:-}
shift || true
case ${CMD} in
  concourse)        setup_build_server "concourse" ;;
  gocd)             setup_build_server "gocd" ;;
  gitlab)           setup_build_server "gitlab" ;;
  gitlab-backup)    create_gitlab_backup ;;
  *)          usage ;;
esac
