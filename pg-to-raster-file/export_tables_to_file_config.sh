#!/bin/bash

# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEAR="2023"

# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"

# list of biomes to export data
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia")

#
# join all rasters into a single file. If disable, the fires dashboard rasters do not generated.
RASTERS_MOSAIC="yes"

#
# remove temporary files and tables?
REMOVE_TMP_FILES="yes"

#
# default values for BBOX and Pixel size.
# force the same BBOX Brazil for all biomes
BBOX="-73.98318215899995 -33.75117799399993 -28.847770352999916 5.269580833000035"
PIXEL_SIZE="0.000268900 -0.000268900"
# BY TERRACLASS, BUT ONLY TO BIOME AMZ, MISSING TO BR...NEED CHANGE THE COORDS: -16.6620184999999168 AND -43.3993179269999985
# echo "-73.9831821589999521 -16.6620184999999168 -43.3993179269999985 5.2695808330000347"