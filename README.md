I like building build monitors, and this is a little local environment that spins up the minimum necessary to have a build server running with a simple pipeline, for testing and playing around with the features.

Has setups for GoCD, TeamCity and Concourse.

All `create_*.sh` scripts tear down and recreate a respective subdirectory in `./environment` that will contain all files for the locally running server and agent environments. They spin up multiple docker containers with `docker-compose`: one for the server, if applicable one for an agent, and a git server. Also adds permissions so that the server and agent can access the git repositories, plus a repository to hold the respective server config.


After creation, you can stop and start the stack again with `docker-compose`:
```
cd gocd # OR cd teamcity # OR cd concourse
docker-compose stop
docker-compose up
```

## Git Server
Will create a Git server with a little test repository (`ssh://git@git-<gocd | teamcity | concourse>-docker/git-server/repos/myrepo.git`) that can be used as material for build configurations. This is how you can push to it:

```
cd ./environment/<gocd | teamcity | concourse>/git-server/myrepo
./git_local_server.sh "git fetch" # Should be able to successfully contact the git server in Docker
# make your changes and use that same script to execute more git commands
```

## GoCD
```
./create_gocd.sh
```

Will mount the `godata` directories with logs and config to `./environment/gocd/gocd-server/godata` and `./environment/gocd/gocd-agent1/godata`.

## TeamCity
```
./create_teamcity.sh
```

Will mount directories with logs and config to `./environment/teamcity/teamcity-server` and `./environment/teamcity/teamcity-agent1`.

## Concourse
```
./create_concourse.sh
```
