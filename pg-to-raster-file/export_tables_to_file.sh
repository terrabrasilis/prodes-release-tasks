#!/bin/bash
#
# the path of the binaries in the container where the CLI programs are installed.
PATH_BIN="/usr/bin"
#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

# load functions
. ./functions_lib.sh

# if raster mosaic is enabled, it needs temporary files, so disable tmp files removal.
if [[ "${RASTERS_MOSAIC}" = "yes" ]];
then
    # used to store one raster for each database
    INPUT_FILES_MOSAIC=()
fi;

# to store dbnames used to clean temporary files in the end
DB_NAMES=()

# loop to export all tables of each database for an schema define into pgconfig file
for TARGET_NAME in ${PRODES_DBS[@]}
do
    # The database name based in biome name
    DB_NAME="prodes_${TARGET_NAME}_nb_p${BASE_YEAR}"

    if [[ "${TARGET_NAME}" = "amazonia_legal" ]]; then
        DB_NAME="prodes_amazonia_nb_p${BASE_YEAR}"
    fi;

    # Logging which database will be processed now.
    echo ""
    echo "Processing the database: ${DB_NAME}"
    echo "----------------------------------------------"

    # used in the end
    DB_NAMES+=("${DB_NAME}")

    # Set a default local directory if not set
    if [[ "" = "${BASE_PATH_DATA}" ]]; then
        BASE_PATH_DATA=`pwd`
    fi;
    # The output directory for each database
    OUTPUT_DIR="${BASE_PATH_DATA}/${DB_NAME}"
    # creating output directory to put files
    mkdir -p "${OUTPUT_DIR}"

    # add database name into GDAL pg connect string
    PGCONNECTION="dbname='${DB_NAME}' ${PG_CON_GDAL}"
    # add database name into PSQL pg connect string
    PG_CON="-d ${DB_NAME} ${PG_CON_SH}"

    # get bbox for the target data
    BBOX=$(get_extent "${TARGET_NAME}")

    # ------------------------------------------------ #
    # GENERATE ONE RASTER TO EACH TABLE AS INPUT FILES
    # ------------------------------------------------ #
    INPUT_FILES=()
    TBS_NAME=()
    # define tables of type data to insert into raster file
    TABLES=("border" "no_forest" "hydrography" "accumulated" "yearly" "residual" "cloud")
    # for amazonia we must include data for no forest areas
    if [[ "${TARGET_NAME}" = "amazonia" ]];
    then
        TABLES+=("hydrography_nf" "accumulated_nf" "yearly_nf" "residual_nf" "cloud_nf")
    fi;

    for TABLE in ${TABLES[@]}
    do
        # get table name to burn
        TB_NAME=$(get_table_name "${TARGET_NAME}" "${TABLE}")

        # test if table exists
        TABLE_EXISTS=$(table_exists "${TB_NAME}")
        if [[ "${TABLE_EXISTS}" = "${TB_NAME}" ]];
        then

            # define where clause if is cloud
            WHERE=""
            if [[ "${TABLE}" = "cloud" || "${TABLE}" = "cloud_nf" ]]; then
                WHERE="WHERE image_date >= ( SELECT (extract(year from (MAX(image_date)::date))::text||'-01-01')::date FROM public.${TB_NAME} )"
            fi;

            # create temporary table with class as number
            create_table_to_burn "${TB_NAME}" "${WHERE}"

            # output file name
            OUTPUT_FILE="${TB_NAME}_${BASE_YEAR}"
            
            # generate a color palette to current data
            generate_palette_entries "${TB_NAME}" "${OUTPUT_DIR}" "${PGCONNECTION}"

            # rasterize vector table 
            generate_raster "${TB_NAME}" "${BBOX}" "${PGCONNECTION}" "${OUTPUT_DIR}/${OUTPUT_FILE}"

            # store the table name to clean the database at the end
            TBS_NAME+=("${TB_NAME}")

            if [[ -f "${OUTPUT_DIR}/${OUTPUT_FILE}.tif" ]];
            then
                # store the generated file into input list used in next step
                INPUT_FILES+=("${OUTPUT_FILE}.tif")
            fi;
        else
            echo "Table do not exists: ${TB_NAME}"
        fi;
    done

    INPUT_FILES=$(echo ${INPUT_FILES[@]})
    OUTPUT_FILE="prodes_${TARGET_NAME}_${BASE_YEAR}"

    # generate the final file with all intermediary files
    generate_final_raster "${INPUT_FILES}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # store file name of final raster, used to make mosaic
    if [[ "${RASTERS_MOSAIC}" = "yes" && -f "${OUTPUT_DIR}/${OUTPUT_FILE}.tif" ]];
    then
        INPUT_FILES_MOSAIC+=("${OUTPUT_DIR}/${OUTPUT_FILE}.tif")
    fi;

    # join all style fractions, sfl and sldf into one style file for each style format
    generate_main_palette_entries "${OUTPUT_FILE}" "${OUTPUT_DIR}"
    
    # generate the style as QML file
    QML_FRACTIONS=("${OUTPUT_FILE}.sfl")
    generate_qml_file "${QML_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"
    
    # generate the style as SLD file
    SLD_FRACTIONS=("${OUTPUT_FILE}.sldf")
    generate_sld_file "${SLD_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # generate the report file
    generate_report_file "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # generate the ZIP file
    generate_final_zip_file "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # drop the temporary tables
    for TB in ${TBS_NAME[@]}
    do
        drop_table_burn "${TB}"
    done

# end of biome list
done

# if the mosaic raster is enable, join all rasters into one
if [[ "${RASTERS_MOSAIC}" = "yes" ]];
then
    INPUT_FILES_MOSAIC=$(echo ${INPUT_FILES_MOSAIC[@]})
    OUTPUT_FILE="prodes_brasil_${BASE_YEAR}"
    # The output directory for mosaic
    OUTPUT_DIR="${BASE_PATH_DATA}"
    
    # generate the final file with all intermediate files
    generate_final_raster "${INPUT_FILES_MOSAIC}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # generate a base map from prodes with forest+non-forest+hydrography to use in the fires dashboard
    generate_fires_dashboard_products "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${BASE_YEAR}" "p1"

    # generate a map from deforestation data from more than 3 years ago to use on the fires dashboard
    generate_fires_dashboard_products "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${BASE_YEAR}" "p2"

    # generate a map only with recent deforestation less than 3 years old
    generate_fires_dashboard_products "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${BASE_YEAR}" "p3"

    # join all style fractions into one style file for each style format, QML and SLD
    generate_main_palette_entries "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    # generate the style as QML file
    QML_FRACTIONS=("${OUTPUT_FILE}.sfl")
    generate_qml_file "${QML_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"
    
    # generate the style as SLD file
    SLD_FRACTIONS=("${OUTPUT_FILE}.sldf")
    generate_sld_file "${SLD_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"
fi;

# remove the temporary files to clean the output dirs
DB_NAMES=$(echo ${DB_NAMES[@]})
remove_temporary_files "${DB_NAMES}" "${BASE_PATH_DATA}"