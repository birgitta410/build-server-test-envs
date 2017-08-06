#! /bin/bash
set -xe

if (( RANDOM % 5 )); then oops-failing-on-purpose; else ls; fi