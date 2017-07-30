I like building build monitors, and this is a little local environment that spins up the minimum necessary to have a GoCD server running with a simple pipeline, for testing.

`./create.sh` spins up 3 docker containers with `docker-compose`: a GoCD server, one GoCD agent, and a Git server with one sample repository (`ssh://git@git-docker/git-server/repos/myrepo.git`). Also adds permissions so that the server and agent can access the git repository.

After created, you can stop and start the stack again with `docker-compose`:
```
docker-compose stop
docker-compose up
```

## GoCD
Will mount the `godata` directories from `./environment/gocd-server/godata` and `./environment/gocd-agent1/godata`, so you can mess around with config etc. from right there.

## Git
Will create a little test repository. This is how you can push to it:

```
cd ./environment/git-server/myrepo-checked-out
./git_local_server.sh "git fetch" # Should be able to successfully contact the git server in Docker
# make your changes and use that same script to execute more git commands
```