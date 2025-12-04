#!/bin/bash
#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

# load functions
. ./functions_lib.sh

# loop to export all tables of each database for an schema define into pgconfig file
length=${#PRODES_DBS[@]}
for ((i=0; i<$length; ++i));
do
    DB_NAME=${PRODES_DBS[$i]}
    BASE_YEAR=${BASE_YEARS[$i]}

    # The database name based in biome name
    database="prodes_${DB_NAME}_nb_p${BASE_YEAR}"
    gpkg_suffix=""

    if [[ "${DB_NAME}" = "amazonia_legal" ]]; then
        database="prodes_amazonia_nb_p${BASE_YEAR}"
    else
        gpkg_suffix="_nb"
    fi;
    # used to identify the Marco UE databases
    database="${database}_marco"

    # include one new column to export data of PRODES "amazonia" and "amazonia_legal"
    if [[ "${DB_NAME}" = "amazonia" || "${DB_NAME}" = "amazonia_legal" ]]; then
        EXTRA_COL="sub_class ,"
    fi;

    # the file name of GPKG file when SAME_FILE="yes"
    GPKG_FNAME="prodes_${DB_NAME}${gpkg_suffix}"
    # and the GeoPackage file name for MARCO UE data
    GPKG_FNAME_MARCO="${GPKG_FNAME}_marco"

    # Set a default local directory if not set
    if [[ "" = "${BASE_PATH_DATA}" ]]; then
        BASE_PATH_DATA=`pwd`
    fi;
    # The output directory for each database
    OUTPUT_DATA="${BASE_PATH_DATA}/${database}/${schema}"

    # add database name into pg connect string
    PG_CON="-d ${database} ${PG_CON_BASE}"

    # try remove old exportation file
    if [[ -f "${OUTPUT_DATA}/${GPKG_FNAME}.gpkg" ]]; then
        rm -f ${OUTPUT_DATA}/${GPKG_FNAME}.gpkg
        rm -f ${OUTPUT_DATA}/${GPKG_FNAME}.gpkg.zip
    fi;

    # fix year column
    if [[ "${FIX_YEAR_COLUMN}" = "yes" ]]; then
        fix_year_column
    fi;

    # creating output directory to put files
    mkdir -p "${OUTPUT_DATA}"

    SQL_TABLES="SELECT table_name FROM information_schema.tables WHERE table_schema = '${schema}'"
    SQL_TABLES="${SQL_TABLES} AND table_type = '${TABLE_TYPE}' AND table_name NOT IN ('geometry_columns','geography_columns','spatial_ref_sys')"

    if [[ ${#FILTER[@]} -gt 0 ]]; then
        OR_TBS=""
        for TABLE_NAME in ${FILTER[@]}
        do
            if [[ ! "" = "${OR_TBS}" ]]; then
                OR_TBS="${OR_TBS} OR"
            fi;
            OR_TBS="${OR_TBS} table_name ILIKE '${TABLE_NAME}%' "
        done

        SQL_TABLES="${SQL_TABLES} AND (${OR_TBS})"
    fi;

    if [[ "${DB_NAME}" = "amazonia" ]]; then
        SQL_TABLES="${SQL_TABLES} AND table_name ILIKE '%_biome'"
    else
        # Amazonia Legal or other databases
        SQL_TABLES="${SQL_TABLES} AND table_name NOT ILIKE '%_biome'"
    fi;

    TABLES=($(${PG_BIN}/psql ${PG_CON} -t -c "${SQL_TABLES};"))

    for TABLE in ${TABLES[@]}
    do
        # To fix if needed
        fix_uid "${TABLE}"
        fix_geom "${TABLE}"

        YEAR_COL="year"
        YEAR_TYPE_SQL="SELECT pg_typeof(year)::text FROM ${schema}.${TABLE} LIMIT 1"
        YEAR_TYPE=($(${PG_BIN}/psql ${PG_CON} -t -c "${YEAR_TYPE_SQL};"))
        if [[ "${YEAR_TYPE}" = "integer" ]]; then
            YEAR_COL="year::integer"
        fi;

        if [[ " ${TABLES_WITH_SUBCLASS[@]} " =~ " ${TABLE} " ]]; then
            subclass="${EXTRA_COL}"
        else
            subclass=""
        fi;

        # To skip FID column generation in GPKG, use full column list in SQL and map uid to fid column name
        COLUMNS="uid as fid, geom, state, path_row, main_class, class_name, ${subclass} def_cloud, julian_day::integer as julian_day, image_date, ${YEAR_COL} as year, area_km, scene_id::integer as scene_id, source, satellite, sensor, uuid::text as uuid"
        DATA_QUERY="SELECT ${COLUMNS} FROM ${schema}.${TABLE}"

        # if cloud table or forest table, generate one shape of each class_name/year to avoid the limit of maximum size of shapefiles
        # if [[ " ${BREAK_SHP[@]} " =~ " ${TABLE} " ]]; then
        #     GRP_CLASS="SELECT class_name FROM ${schema}.${TABLE} GROUP BY 1 ORDER BY 1 ASC"
        #     CLS=($(${PG_BIN}/psql ${PG_CON} -t -c "${GRP_CLASS};"))

        #     for CLASS_NAME in ${CLS[@]}
        #     do
        #         DATA_QUERY_CLS="${DATA_QUERY} WHERE class_name='${CLASS_NAME}';"
        #         export_shp "${DATA_QUERY_CLS}" "${TABLE}_${CLASS_NAME}"
        #     done
        # else
        #    export_shp "${DATA_QUERY}" "${TABLE}"
        # fi;

        export_shp "${DATA_QUERY}" "${TABLE}"
        export_gpkg "${DATA_QUERY}" "${TABLE}" "${GPKG_FNAME}"

        # to export MARCO UE files
        # Check if TABLE name starts with $TABLE_LIKE
        for TABLE_LIKE in ${TABLES_LIKE[@]}
        do
            if [[ "${TABLE}" == "${TABLE_LIKE}"* ]]; then

                DATA_QUERY_MARCO="${DATA_QUERY} WHERE year<=2020"
                TABLE_MARCO="${TABLE}_marco"

                export_shp "${DATA_QUERY_MARCO}" "${TABLE_MARCO}"
                export_gpkg "${DATA_QUERY_MARCO}" "${TABLE_MARCO}" "${GPKG_FNAME_MARCO}"
            fi;
        done
    done
    # remove intermediary files
    if [[ "${RM_OUT}" = "yes" ]]; then
        rm -f ${OUTPUT_DATA}/*.{shp,shx,prj,dbf,gpkg}
        # remove shapes of marco
        rm -f ${OUTPUT_DATA}/*_marco.zip
    fi;

# end of biome list
done