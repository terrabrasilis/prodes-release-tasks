#!/bin/bash
###############################################
# General settings
###############################################
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
# The database name used to apply changes and export auxiliary data
DB_NAME="auxiliary_2022"
# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
###############################################
# Settings to control the changes in LOI tables
###############################################
# Fix geometries before export
FIX_GEOM="no"
# Fix UC names before export
FIX_UCS="yes"
# the table name of UCs
UC_TABLE_NAME="uc"
# the tolerance to simplify Polygons (use dot separator for thousands)
SIMPLIFY_TOLERANCE=0.0018
#
###############################################
# Settings about column pattern for LOI tables
###############################################
# we expect that default column name for geometries of LOI is "geom"
LOI_GEOM_COLUMN="geom"
# we expect that default column name for names of LOI is "nome"
LOI_NAME_COLUMN="nome"
#
###############################################
# Settings about what data will be exported
###############################################
#
# The name of the schemas for each LOI cropp.
LOI_SCHEMAS=("amazonia" "amazonia_legal" "caatinga" "cerrado" "mata_atlantica" "pampa" "pantanal")
#
# Control GeoJson exportation
GEOJSON_EXPORT="yes"
# Control Shapefile exportation
SHAPEFILE_EXPORT="no"