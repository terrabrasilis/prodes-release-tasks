#!/bin/bash
#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

# load functions
. ./functions_lib.sh

# if has base path from start script via run time param, use it.
if [[ -d "${BASE_PATH}" ]]; then
    BASE_PATH_DATA="${BASE_PATH}"
fi;

# loop through database list to export all tables from LOI schemas
for DB_NAME in ${PRODES_DBS[@]}
do
    # The database name based in biome name
    database="prodes_${DB_NAME}_nb_p${BASE_YEAR}"
    schema="${DB_NAME}_lois"

    if [[ "${DB_NAME}" = "amazonia_legal" ]]; then
        database="prodes_amazonia_nb_p${BASE_YEAR}"
    fi;

    # The output directory for each database
    OUTPUT_DATA="${BASE_PATH_DATA}/${database}/${schema}"

    # add database name into pg connect string
    PG_CON="-d ${database} ${PG_CON_BASE}"
    echo "PG_CON=${PG_CON}"

    # creating output directory to put files
    mkdir -p "${OUTPUT_DATA}"

    SQL_TABLES="select table_name from information_schema.tables where table_schema = '${schema}'"
    SQL_TABLES="${SQL_TABLES} and table_type = '${TABLE_TYPE}' "

    TABLES=($(${PG_BIN}/psql ${PG_CON} -t -c "${SQL_TABLES};"))

    for TABLE in ${TABLES[@]}
    do
        # To fix if needed
        if [[ "${TABLE}" = "${UC_TABLE_NAME}" ]]; then
            fix_uc_names "${TABLE}"
        fi;

        fix_geom "${TABLE}"
        export_geojson "${TABLE}"
    done

# end of biome list
done