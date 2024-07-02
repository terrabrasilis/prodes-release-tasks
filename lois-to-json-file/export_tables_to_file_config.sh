#!/bin/bash
#
# The database name used to apply changes and export auxiliary data
DB_NAME="auxiliary_2022"
#
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
# Fix geometries before export
FIX_GEOM="no"
# Fix UC names before export
FIX_UCS="yes"
# the table name of UCs into each PRODES database
UC_TABLE_NAME="uc"
#
# we expect that default column name for geometries of LOI is "geom"
LOI_GEOM_COLUMN="geom"
# we expect that default column name for names of LOI is "nome"
LOI_NAME_COLUMN="nome"
#
# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
# The name of the schemas for each LOI cropp.
LOI_SCHEMAS=("amazonia" "amazonia_legal" "caatinga" "cerrado" "mata_atlantica" "pampa" "pantanal")