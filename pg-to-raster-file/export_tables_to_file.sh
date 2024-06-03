#!/bin/bash
#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

# load functions
. ./functions_lib.sh

# loop to export all tables of each database for an schema define into pgconfig file
for TARGET_NAME in ${PRODES_DBS[@]}
do
    # The database name based in biome name
    DB_NAME="prodes_${TARGET_NAME}_nb_p${BASE_YEAR}"

    if [[ "${TARGET_NAME}" = "amazonia_legal" ]]; then
        DB_NAME="prodes_amazonia_nb_p${BASE_YEAR}"
    fi;

    # The output directory for each database
    OUTPUT_DIR="${BASE_PATH_DATA}/${DB_NAME}/${schema}"
    # creating output directory to put files
    mkdir -p "${OUTPUT_DIR}"

    # add database name into GDAL pg connect string
    PGCONNECTION="dbname='${DB_NAME}' ${PG_CON_GDAL}"
    # add database name into PSQL pg connect string
    PG_CON="-d ${DB_NAME} ${PG_CON_SH}"
    # add database name into psycopg2 pg connect string
    PG_CON_PY="${PG_CON_PY}/${DB_NAME}"

    # get bbox for the target data
    BBOX=$(get_extent "${TARGET_NAME}")

    # ------------------------------------------------ #
    # GENERATE ONE RASTER TO EACH TABLE AS INPUT FILES
    # ------------------------------------------------ #
    INPUT_FILES=()
    QML_FRACTIONS=()
    TABLES=("border" "no_forest" "hydrography" "accumulated" "yearly" "residual" "cloud")
    for TABLE in ${TABLES[@]}
    do
        # get table name to burn
        TB_NAME=$(get_table_name "${TARGET_NAME}" "${TABLE}")

        # define where clause if is cloud
        WHERE=""
        if [[ "${TABLE}" = "cloud" ]]; then
            WHERE="WHERE image_date >= ( SELECT (extract(year from (MAX(image_date)::date))::text||'-01-01')::date FROM public.${TB_NAME} )"
        fi;

        if [[ ! "${TB_NAME}" = "" ]];
        then
            # create temporary table with class as number
            create_table_to_burn "${TB_NAME}" "${WHERE}"

            # output file name
            OUTPUT_FILE="${TB_NAME}_${BASE_YEAR}"
            # store the generated file into input list used in next step
            INPUT_FILES+=("${OUTPUT_FILE}.tif")

            # generate a color palette to current data
            generate_palette_entries "${TB_NAME}" "${OUTPUT_DIR}" "${PG_CON_PY}"

            # store the style fractions for each table used in next step to build the final QML
            QML_FRACTIONS+=("${TB_NAME}.sfl")

            # rasterize vector table 
            generate_raster "${TB_NAME}" "${BBOX}" "${PGCONNECTION}" "${OUTPUT_DIR}/${OUTPUT_FILE}"

            # drop the temporary table
            drop_table_burn "${TB_NAME}"
        fi;
    done

    INPUT_FILES=$(echo ${INPUT_FILES[@]})
    OUTPUT_FILE="prodes_${TARGET_NAME}_${BASE_YEAR}"

    # generate the final file with all intermediate files
    generate_final_raster "${INPUT_FILES}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # generate the style as QML file
    generate_qml_file "${QML_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

# end of biome list
done