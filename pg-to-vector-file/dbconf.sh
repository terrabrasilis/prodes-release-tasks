#!/bin/bash

if [[ -f "./pgconfig.exportation" ]];
then
  source "./pgconfig.exportation"
  export PGUSER="${user}"
  export PGPASSWORD="${password}"
  PG_BIN="/usr/bin"
  PG_CON_BASE="-p ${port} -U ${user} -h ${host}"
else
  echo "Missing PostgreSQL config file."
  echo "I'm creating one with default settings, but you must edit it to provide the correct configuration."
  echo "host=\"localhost\"" > "./pgconfig.exportation"
  echo "user=\"postgres\"" >> "./pgconfig.exportation"
  echo "schema=\"public\"" >> "./pgconfig.exportation"
  echo "port=\"5432\"" >> "./pgconfig.exportation"
  echo "password=\"postgres\"" >> "./pgconfig.exportation"
  exit
fi