#!/bin/bash
#
# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEAR="2023"
#
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
# Fix geometries before export
FIX_GEOM="no"
# Fix UC names before export
FIX_UCS="yes"
# the table name of UCs into each PRODES database
UC_TABLE_NAME="consunit"
#
# we expect that default column name for geometries of LOI is "geom"
LOI_GEOM_COLUMN="geom"
# we expect that default column name for names of LOI is "name"
LOI_NAME_COLUMN="name"
#
# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
# list of biomes as fraction of target database name. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("mata_atlantica")