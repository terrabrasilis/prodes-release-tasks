#!/bin/bash
# get data to new log file
DATE_LOG=$(date +"%Y_%m_%d")
DATE_I=$(date +"%d/%m/%Y %H:%M")
echo "${DATE_I}" > ./export_tables_to_file_${DATE_LOG}.log
echo "==============================" >> ./export_tables_to_file_${DATE_LOG}.log
#./export_tables_to_file.sh >> ./export_tables_to_file_${DATE_LOG}.log 2>&1
./test_terraclass.sh >> ./export_tables_to_file_${DATE_LOG}.log 2>&1
echo "==============================" >> ./export_tables_to_file_${DATE_LOG}.log
DATE_F=$(date +"%d/%m/%Y %H:%M")
echo "${DATE_F}" >> ./export_tables_to_file_${DATE_LOG}.log