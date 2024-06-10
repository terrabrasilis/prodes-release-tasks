#!/bin/bash
#
# using Grass to generate the RASTER report
# https://grass.osgeo.org/grass83/manuals/grass.html
#
# 
DATA_DIR="${1}"
FILE_NAME="${2}"

r.external input="${DATA_DIR}/${FILE_NAME}.tif" \
band=1 output="${FILE_NAME}" --overwrite -o

g.region -p

r.report map=${FILE_NAME} units="k" null_value="*" page_length=0 \
page_width=79 nsteps=255 sort="asc" \
output="${DATA_DIR}/${FILE_NAME}.txt" --overwrite