#!/bin/bash
#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

# output file name
OUTPUT_FILE="PDigital2000_${BASE_YEAR}.tif"

# if has an old tiff file, use it to make changes
if [[ ! "${NEW_FILE}" = "yes" ]]; then

gdal_calc.py -A PDigital2000_2022_AMZ_raster.tif  --quiet \
--calc="((A*logical_and(A>=0,A<=31)) + (A==32)*1 + (A*logical_and(A>=33,A<=110)))" \
--outfile PDigital2000_2022_AMZ_raster_semnv.tif

fi;

# loop to export all tables of each database for an schema define into pgconfig file
for DB_NAME in ${PRODES_DBS[@]}
do
    # The database name based in biome name
    database="prodes_${DB_NAME}_nb_p${BASE_YEAR}"

    if [[ "${DB_NAME}" = "amazonia_legal" ]]; then
        database="prodes_amazonia_nb_p${BASE_YEAR}"
    fi;

    # The output directory for each database
    OUTPUT_DATA="${BASE_PATH_DATA}/${database}/${schema}"

    # add database name into pg connect string
    PGCONNECTION="dbname=${database} ${PG_CON_BASE}"

    gdal_rasterize -burn 23 -tr 0.0002689997882979999733 -0.000269000486077000027 \
    -te  -73.9783163999999971 -18.0406292244049773 -43.9135550608740317 5.2714908999999999 \
    -a_nodata 255 -ot Byte PG:"host=localhost dbname='postgres' user='postgres' password='postgres'" -sql "SELECT * FROM public.yearly_deforestation_2008_2023 where class_name = 'd2023'" prodes_incremento2023.tif

# end of biome list
done