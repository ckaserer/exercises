#!/bin/bash

####################### 
# READ ONLY VARIABLES #
#######################

readonly PROG_NAME=`basename "$0"`
readonly SCRIPT_HOME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#################### 
# GLOBAL VARIABLES #
####################

########## 
# SOURCE #
##########
set -ex

rm -rf docs
docker build -t exercises .
docker container rm -f exercises >/dev/null
docker run -d --name exercises exercises
docker cp exercises:/app/content/static/exercises docs
chmod -R 777 docs