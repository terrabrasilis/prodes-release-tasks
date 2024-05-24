#!/bin/bash
#
# Need a directory to use as a docker volume where output data is written.
# Adjust the path in VOLUME_HOST if necessary.
VOLUME_HOST="/main/storage/exported/files"
#
# detect the location of this script
SCRIPT_DIR=$(pwd)
#
# If a new image with a different tag was created, change the IMAGE_TAG
IMAGE_TAG="v1.0.0"

if [[ "$1" != "up" && "$1" != "down" ]]; then
  echo "Use up to start OR down to stop."
else
  if [[ "$1" == "up" ]]; then
    docker run -d --name export_pg_to_vector --rm -v ${SCRIPT_DIR}/pg-to-vector-file:/scripts \
    -v ${VOLUME_HOST}:/main/storage/exported/files \
    terrabrasilis/run-scripts-pg-gdal-3-6:${IMAGE_TAG} bash /scripts/start.sh
  fi;
  if [[ "$1" == "down" ]]; then
    docker container stop export_pg_to_vector
  fi;
fi;
