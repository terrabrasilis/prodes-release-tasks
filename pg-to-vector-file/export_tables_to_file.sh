#!/bin/bash
#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

# load functions
. ./functions_lib.sh

# loop to export all tables of each database for an schema define into pgconfig file
for DB_NAME in ${PRODES_DBS[@]}
do
    # The database name based in biome name
    database="prodes_${DB_NAME}_nb_p${BASE_YEAR}"
    gpkg_suffix=""

    if [[ "${DB_NAME}" = "amazonia_legal" ]]; then
        database="prodes_amazonia_nb_p${BASE_YEAR}"
    else
        gpkg_suffix="_nb"
    fi;

    # include one new column to export data of PRODES "amazonia" and "amazonia_legal"
    if [[ "${DB_NAME}" = "amazonia" || "${DB_NAME}" = "amazonia_legal" ]]; then
        EXTRA_COL="sub_class ,"
    fi;

    # the file name of GPKG file when SAME_FILE="yes"
    GPKG_FNAME="prodes_${DB_NAME}${gpkg_suffix}"

    # The output directory for each database
    OUTPUT_DATA="${BASE_PATH_DATA}/${database}/${schema}"

    # add database name into pg connect string
    PG_CON="-d ${database} ${PG_CON_BASE}"

    # try remove old exportation file
    if [[ -f "${OUTPUT_DATA}/${GPKG_FNAME}.gpkg" ]]; then
        rm -f ${OUTPUT_DATA}/${GPKG_FNAME}.gpkg
        rm -f ${OUTPUT_DATA}/${GPKG_FNAME}.gpkg.zip
    fi;

    # creating output directory to put files
    mkdir -p "${OUTPUT_DATA}"

    SQL_TABLES="select table_name from information_schema.tables where table_schema = '${schema}'"
    SQL_TABLES="${SQL_TABLES} and table_type = '${TABLE_TYPE}' and table_name NOT IN ('geometry_columns','geography_columns','spatial_ref_sys')"

    if [[ ${#FILTER[@]} -gt 0 ]]; then
        OR_TBS=""
        for TABLE_NAME in ${FILTER[@]}
        do
            if [[ ! "" = "${OR_TBS}" ]]; then
                OR_TBS="${OR_TBS} OR"
            fi;
            OR_TBS="${OR_TBS} table_name ilike '${TABLE_NAME}%' "
        done

        SQL_TABLES="${SQL_TABLES} AND (${OR_TBS})"
    fi;

    if [[ "${DB_NAME}" = "amazonia" ]]; then
        SQL_TABLES="${SQL_TABLES} and table_name ilike '%_biome'"
    else
        # Amazonia Legal or other databases
        SQL_TABLES="${SQL_TABLES} and table_name NOT ilike '%_biome'"
    fi;

    TABLES=($(${PG_BIN}/psql ${PG_CON} -t -c "${SQL_TABLES};"))

    for TABLE in ${TABLES[@]}
    do
        # To fix if needed
        fix_uid "${TABLE}"
        fix_geom "${TABLE}"

        YEAR_COL="year"
        YEAR_TYPE_SQL="SELECT pg_typeof(year)::text FROM ${schema}.${TABLE} limit 1"
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
        if [[ " ${BREAK_SHP[@]} " =~ " ${TABLE} " ]]; then
            GRP_CLASS="SELECT class_name FROM ${schema}.${TABLE} GROUP BY 1 ORDER BY 1 ASC"
            CLS=($(${PG_BIN}/psql ${PG_CON} -t -c "${GRP_CLASS};"))

            for CLASS_NAME in ${CLS[@]}
            do
                DATA_QUERY_CLS="${DATA_QUERY} WHERE class_name='${CLASS_NAME}';"
                export_shp "${DATA_QUERY_CLS}" "${TABLE}_${CLASS_NAME}"
            done
        else
            export_shp "${DATA_QUERY}" "${TABLE}"
        fi;

        export_gpkg "${DATA_QUERY}" "${TABLE}"

        # remove intermediate files
        if [[ "${RM_OUT}" = "yes" ]]; then
            if [[ "${SHP}" = "yes" ]]; then
                rm -f ${OUTPUT_DATA}/"${TABLE}*".{shp,shx,prj,dbf}
            fi;
            if [[ "${GPKG}" = "yes" ]]; then
                FNAME="${TABLE}"
                if [[ ! "$SAME_FILE" = "yes" ]]; then
                    # only remove the gpkg if same file is disabled or the process will be overwrite the zip file content
                    FNAME="${GPKG_FNAME}"
                    rm -f ${OUTPUT_DATA}/${FNAME}.gpkg
                fi;
            fi;
        fi;
    done

# end of biome list
done