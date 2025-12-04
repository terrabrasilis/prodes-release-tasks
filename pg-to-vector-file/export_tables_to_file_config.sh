#!/bin/bash
#
# list of biomes to export data and list of year for each database suffix
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
# BASE_YEARS=("2024" "2024" "2025" "2024" "2025" "2024" "2024")
#PRODES_DBS=("cerrado" "pantanal")
#PRODES_DBS=("pampa" "caatinga" "mata_atlantica" "amazonia" "amazonia_legal")
PRODES_DBS=("amazonia" "amazonia_legal")
# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEARS=("2024" "2024")
#
# if you want export only filtered tables, set the table names into FILTER variable below and removing the character # to uncomment that.
# FILTER=("table_name_a" "table_name_b" "table_name_c")
# FILTER=("forest" "accumulated_deforestation_2007" "hydrography" "cloud" "no_forest" "residual" "yearly_deforestation" )
# FILTER=("accumulated_deforestation_2007_biome" "hydrography_biome" "no_forest_biome" "residual_biome" "yearly_deforestation_biome" "yearly_deforestation_nf_biome" "yearly_deforestation_smaller_than_625ha_biome")
#FILTER=("residual_${BASE_YEAR}_pri" "residual_${BASE_YEAR}_pri_biome" "yearly_deforestation_${BASE_YEAR}_pri" "yearly_deforestation_${BASE_YEAR}_pri_biome") # "yearly_deforestation_smaller_than_625ha_${BASE_YEAR}_pri")
#FILTER=("accumulated_deforestation_2000" "yearly_deforestation" "residual" "hydrography")
#
# Used for cloud table or forest table, generate one shape of each class_name/year to avoid the limit of maximum size of shapefiles
# BREAK_SHP=("forest" "cloud" "forest_biome" "cloud_biome")
# BREAK_SHP=("cloud")
#
# used to confirm the sub_class column only for the deforestation tables in the list below (valid for "amazonia" and "amazonia_legal")
TABLES_WITH_SUBCLASS=("yearly_deforestation" "yearly_deforestation_biome")
#TABLES_WITH_SUBCLASS=("residual_${BASE_YEAR}_pri" "residual_${BASE_YEAR}_pri_biome" "yearly_deforestation_${BASE_YEAR}_pri" "yearly_deforestation_${BASE_YEAR}_pri_biome")
#
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
#
# Remove the output files after ZIP
RM_OUT="yes"
#
# Fix geometries before export
FIX_GEOM="no"
#
# Fix FID before export. Make an update into sequential numeric column used as primary key.
FIX_FID="no"
#
# used to cast the year column to integer and update the value using the class_name data
FIX_YEAR_COLUMN="no"
#
# Export to Shapefile
SHP="yes"
#
# Export to GeoPackage
GPKG="yes"
# if same file is yes, than the gpkg file name is the same of the all data from each database.
SAME_FILE="yes"

# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
# list of tables prefix used to fix year column and export MARCO UE files
TABLES_LIKE=("accumulated" "residual" "yearly")
