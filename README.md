I like building build monitors, and this is a little local environment that spins up the minimum necessary to have a GoCD server running with a simple pipeline, for testing.

`./start.sh` spins up 3 docker containers with `docker-compose`: a GoCD server, one GoCD agent, and a Git server with one sample repository (`ssh://git@git-docker/git-server/repos/myrepo.git`). Also adds permissions so that the server and agent can access the git repository.
