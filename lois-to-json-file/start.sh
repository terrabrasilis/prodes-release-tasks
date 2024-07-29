#!/bin/bash
if [[ ! "${1}" = "" ]]; then
    export BASE_PATH="${1}"
fi;
DATE_LOG=$(date +"%Y_%m_%d_%H_%M_%S")
./export_tables_to_file.sh >> ./export_tables_to_file_${DATE_LOG}.log 2>&1