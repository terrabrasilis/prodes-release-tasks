#!/bin/bash

# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEAR="2023"

# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"

# list of biomes to export data
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia")

#
# join all rasters into a single file. If disable, the fires dashboard rasters do not generated. Use "yes" to enable.
BUILD_BR_MOSAIC="yes"
# if you want to skip building each biome raster file. Use "yes" to enable.
REBUILD_ONLY_BR_MOSAIC="no"
# if you want to build the fires dashboard input products. Use "yes" to enable.
BUILD_FIRES_DASHBOARD_PRODUCTS="no"
#

# remove temporary files and tables? Use "yes" to enable.
REMOVE_TEMPORARY_ARTIFACTS="yes"

#
# default values for BBOX and Pixel size.
# force the same BBOX Brazil for all biomes
# BBOX="-73.98318215899995 -33.75117799399993 -28.847770352999916 5.269580833000035" # THE ORIGINAL FROM VECTOR
PIXEL_SIZE="0.0002689 0.0002689"
