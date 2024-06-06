#!/bin/bash
#
# Need a directory to use as a docker volume where output data is written.
# Adjust the path in VOLUME_HOST if necessary.
VOLUME_HOST=""
#
# detect the location of this script
SCRIPT_DIR=$(pwd)
#
# 
DIR_TYPE=""
if [[ "${1}" = "vector" ]]; then
  DIR_TYPE="pg-to-vector-file"
elif [[ "${1}" = "raster" ]]; then
  DIR_TYPE="pg-to-raster-file"
else
  echo "You need provide some type of exportation."
  echo "------------------------------------------"
  echo "The options are: vector or raster"
  echo "Example: ./run-pg-export-to-file.sh vector up"
  exit
fi;

#
# If a new image with a different tag was created, change the IMAGE_TAG
IMAGE_TAG="v1.0.0"

if [[ "$2" != "up" && "$2" != "down" ]]; then
  echo "Use up to start OR down to stop."
  echo "------------------------------------------"
  echo "Example: ./run-pg-export-to-file.sh vector up"

else
  if [[ "${VOLUME_HOST}" = "" ]]; then
    VOLUME_HOST="${SCRIPT_DIR}/${DIR_TYPE}"
  fi;

  if [[ "$2" == "up" ]]; then
    docker run -d --name export_pg_to_${1}_file --rm -v ${SCRIPT_DIR}/${DIR_TYPE}:/scripts \
    -v ${VOLUME_HOST}:/main/storage/exported/files \
    terrabrasilis/run-scripts-pg-gdal-3-6:${IMAGE_TAG} bash /scripts/start.sh
  fi;
  if [[ "$2" == "down" ]]; then
    docker container stop export_pg_to_${1}_file
  fi;
fi;
