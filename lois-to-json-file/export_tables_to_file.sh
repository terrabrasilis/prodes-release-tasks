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
for LOI_SCHEMA in ${LOI_SCHEMAS[@]}
do
    database="${DB_NAME}"

    # The output directory for each database
    OUTPUT_DATA="${BASE_PATH_DATA}/${database}/${LOI_SCHEMA}"

    # add database name into pg connect string
    PG_CON="-d ${database} ${PG_CON_BASE}"

    # creating output directory to put files
    mkdir -p "${OUTPUT_DATA}"

    SQL_TABLES="SELECT table_name FROM information_schema.tables WHERE table_schema = '${LOI_SCHEMA}'"
    SQL_TABLES="${SQL_TABLES} AND table_type = '${TABLE_TYPE}' AND NOT table_name ilike '%_loi%'"

    TABLES=($(${PG_BIN}/psql ${PG_CON} -t -c "${SQL_TABLES};"))

    for TABLE in ${TABLES[@]}
    do

        # used only once to improve normalization of tables and columns
        # fix_column_names "${TABLE}"
        
        # To fix if needed
        if [[ "${TABLE}" = "${UC_TABLE_NAME}" ]]; then
            fix_uc_names "${TABLE}"
        fi;

        create_loi_table "${TABLE}"
        create_loi_view "${TABLE}"

        fix_geom "${TABLE}"
        export_geojson "${TABLE}"
        export_shape "${TABLE}"
    done

# end of biome list
done