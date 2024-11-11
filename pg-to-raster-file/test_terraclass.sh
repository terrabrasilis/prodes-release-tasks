#!/bin/bash

# GDAL settings
export CHECK_DISK_FREE_SPACE=NO
export GDAL_CACHEMAX=20%
export GDAL_NUM_THREADS=ALL_CPUS

PIXEL_SIZE="0.00009 0.00009"
BBOX="-60.47259563399996 -24.68178012599998 -41.27753552599995 -2.332088333999934"
PGCONNECTION="dbname='TerraClassCerrado_2022' host=192.168.15.49 port=5444 user='postgres' password='postgres'"

CLASSES=("agr_perene" "agr_semiperene" "agr_temp_1" "agr_temp_2mais" "corpos_agua" "d2022" "florestal_prim" "florestal_sec" "mineracao" "nao_veg_arenosa" "nao_veg_rochosa" "outras_edificadas" "outros_usos" "pastagem" "silvicultura" "urbanizada")
INPUT_FILES_MOSAIC=()

for CLASSE in ${CLASSES[@]}
do

gdal_rasterize -tr ${PIXEL_SIZE} \
    -te ${BBOX} -tap \
    -a_nodata 255 -co "COMPRESS=LZW" \
    -ot Byte PG:"${PGCONNECTION}" \
    -a "raster" \
    -sql "SELECT raster, ogr_geometry as geom FROM public.uc_cer22_bioma_final WHERE class_name='${CLASSE}'" \
    "/main/storage/exported/files/TerraClassCerrado_2022_${CLASSE}.tif"

INPUT_FILES_MOSAIC+=("/main/storage/exported/files/TerraClassCerrado_2022_${CLASSE}.tif")

done

INPUT_FILES_MOSAIC=$(echo ${INPUT_FILES_MOSAIC[@]})

gdalbuildvrt "/main/storage/exported/files/TerraClassCerrado_2022.vrt" ${INPUT_FILES_MOSAIC}

gdal_translate -of GTiff -co "COMPRESS=LZW" -co BIGTIFF=YES "/main/storage/exported/files/TerraClassCerrado_2022.vrt" "/main/storage/exported/files/TerraClassCerrado_2022.tif"