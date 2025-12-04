#!/bin/bash

# Used as name suffix for the output files (some files as prodes_brasil and dashboard intermediary files)
REFERENCE_YEAR="2024"

# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"

# list of biomes to export data and the YEAR for each bioma database
#PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia") # "amazonia_legal")
# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
#BASE_YEARS=("2024" "2024" "2025" "2024" "2025" "2024") # "2024")

PRODES_DBS=("amazonia")
BASE_YEARS=("2024")
#
# join all rasters into a single file. If disable, the fires dashboard rasters do not generated. Use "yes" to enable.
BUILD_BR_MOSAIC="no"
# if you want to skip building each biome raster file. Use "yes" to enable.
REBUILD_ONLY_BR_MOSAIC="no"
# if you want to build the fires dashboard input products. Use "yes" to enable.
BUILD_FIRES_DASHBOARD_PRODUCTS="no"
#

# remove temporary files and tables? Use "yes" to enable.
REMOVE_TEMPORARY_ARTIFACTS="no"

#
# default values for BBOX and Pixel size.
# force the same BBOX Brazil for all biomes
# BBOX_FROM_CONFIG="-73.98318215899995 -33.75117799399993 -28.847770352999916 5.269580833000035" # THE ORIGINAL FROM VECTOR
# force the IBAMA BBOX for Amazônia biome (from AMZ.2022.M.tif)
#BBOX_FROM_CONFIG="-73.9831821599999984 -16.6619791700000022 -43.3992921600000017 5.2695808299999998"
# force the IBAMA BBOX for Amazônia biome (from Fechamento_TC_AMZ.pptx)
#BBOX_FROM_CONFIG="-73.9831821589999521 -16.6620184999999168 -43.3993179269999985 5.2695808330000347"

# force the IBAMA Upper Left corner and BBOX Brasil Lower Right corner
# BBOX_FROM_CONFIG="-73.9831821589999521 -33.75117799399993 -28.847770352999916 5.2695808330000347"
# the adjusted bbox for cerrado, after use the adjust_extent.py
# BBOX_FROM_CONFIG="-60.47265215899995 -24.681699166999966 -41.27754215899995 -2.3319991669999656"

PIXEL_SIZE="0.0002689 0.0002689" # 30 m
#PIXEL_SIZE="0.00009 0.00009" # 10 m
