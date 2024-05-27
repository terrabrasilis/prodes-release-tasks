#!/bin/bash
# remove old logs
if [[ -f "./*.log" ]]; then
    rm ./*.log
fi;
# get data to new log file
DATE_LOG=$(date +"%Y_%m_%d_%H_%M_%S")
./export_tables_to_file.sh >> ./export_tables_to_file_${DATE_LOG}.log 2>&1
