#! /bin/bash
set -xe

if (( RANDOM % 2 )); then ls; else oops-failing-on-purpose; fi