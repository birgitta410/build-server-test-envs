#! /bin/bash
set -xe

# Give it some time, to make testing of a monitor that shows build status easier
sleep 10

if (( RANDOM % 5 )); then oops-failing-on-purpose; else ls; fi
