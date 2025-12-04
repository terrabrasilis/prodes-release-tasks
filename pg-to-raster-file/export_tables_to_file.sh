#!/bin/bash
#
# the path of the binaries in the container where the CLI programs are installed.
PATH_BIN="/usr/bin"

# GDAL settings
export CHECK_DISK_FREE_SPACE=NO
export GDAL_CACHEMAX=10%
export GDAL_NUM_THREADS=ALL_CPUS

#
# load database server configurations
. ./dbconf.sh

# apply configs based on environment and context selections
. ./export_tables_to_file_config.sh

echo "DEBUG INFO"
echo "REFERENCE_YEAR=${REFERENCE_YEAR}"

# load functions
. ./functions_lib.sh

# if raster mosaic is enabled, it needs temporary files, so disable tmp files removal.
if [[ "${BUILD_BR_MOSAIC}" = "yes" ]];
then
    # used to store one raster for each database
    INPUT_FILES_MOSAIC=()
fi;

# to store dbnames used to clean temporary files in the end
DB_NAMES=()

# loop to export all tables of each database for an schema define into pgconfig file
length=${#PRODES_DBS[@]}
for ((i=0; i<$length; ++i));
do
    TARGET_NAME=${PRODES_DBS[$i]}
    BASE_YEAR=${BASE_YEARS[$i]}
# done

# for TARGET_NAME in ${PRODES_DBS[@]}
# do
    # The database name based in biome name
    DB_NAME="prodes_${TARGET_NAME}_nb_p${BASE_YEAR}"

    if [[ "${TARGET_NAME}" = "amazonia_legal" ]]; then
        DB_NAME="prodes_amazonia_nb_p${BASE_YEAR}"
    fi;

    # used to identify the Marco UE databases
    DB_NAME="${DB_NAME}_marco"
    
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

    # ------------------------------------------------ #
    # GENERATE ONE RASTER TO EACH TABLE AS INPUT FILES
    # ------------------------------------------------ #
    if [[ "${REBUILD_ONLY_BR_MOSAIC}" = "no" ]];
    then
        # get bbox for the target data (only if we want use one BBOX for each biome)
        if [[ ! -v BBOX_FROM_CONFIG ]];
        then
            echo "get extent from vector data to use as BBOX"
            BBOX_BIOME=$(get_extent "${TARGET_NAME}")
            echo "${TARGET_NAME} BBOX_BIOME=${BBOX_BIOME}"
            BBOX_FINAL=$(adjust_extent "${BBOX_BIOME}")
            echo "${TARGET_NAME} BBOX_FINAL=${BBOX_FINAL}"
        else
            echo "using BBOX from config file"
            BBOX_FINAL=${BBOX_FROM_CONFIG}
        fi;

        INPUT_FILES=()
        REFERENCE_INPUT_FILES=()
        TBS_NAME=()
        # define tables of type data to insert into raster file.
        # the tables to export data from database.
        TABLES=("border" "no_forest" "hydrography" "accumulated" "yearly" "residual")
        # for amazonia we must include data for no forest areas
        if [[ "${TARGET_NAME}" = "amazonia" ]];
        then
            TABLES+=("hydrography_nf" "accumulated_nf" "yearly_nf" "residual_nf")
        fi;

        for TABLE in ${TABLES[@]}
        do
            # get table name to burn
            TB_NAME=$(get_table_name "${TARGET_NAME}" "${TABLE}")

            # test if table exists
            TABLE_EXISTS=$(table_exists "${TB_NAME}")
            if [[ ! "${TB_NAME}" = "" && "${TABLE_EXISTS}" = "${TB_NAME}" ]];
            then
                # create temporary table with class as number
                create_table_to_burn "${TB_NAME}"

                # output file name
                OUTPUT_FILE="${TB_NAME}_${BASE_YEAR}"
                REFERENCE_OUTPUT_FILE=""
                echo "DEBUG INFO"
                echo "OUTPUT_FILE=${OUTPUT_FILE}"
                
                # generate a color palette to current data
                generate_palette_entries "${TB_NAME}" "${OUTPUT_DIR}" "${PGCONNECTION}" "${BASE_YEAR}"

                # rasterize vector table 
                generate_raster "${TB_NAME}" "${BBOX_FINAL}" "${PIXEL_SIZE}" "${PGCONNECTION}" "${OUTPUT_DIR}/${OUTPUT_FILE}"

                # If there is a difference between the REFERENCE YEAR and the BASE YEAR of the biome, construct the mosaic for the reference year.
                if [[ ! "${BASE_YEAR}" = "${REFERENCE_YEAR}" ]]; then
                    # output file name
                    REFERENCE_OUTPUT_FILE="${TB_NAME}_${REFERENCE_YEAR}"
                    echo "DEBUG INFO"
                    echo "REFERENCE_OUTPUT_FILE=${REFERENCE_OUTPUT_FILE}"
                    
                    # generate a color palette to current data
                    generate_palette_entries "${TB_NAME}" "${OUTPUT_DIR}" "${PGCONNECTION}" "${REFERENCE_YEAR}"

                    # rasterize vector table 
                    generate_raster "${TB_NAME}" "${BBOX_FINAL}" "${PIXEL_SIZE}" "${PGCONNECTION}" "${OUTPUT_DIR}/${REFERENCE_OUTPUT_FILE}" "${REFERENCE_YEAR}"
                fi;

                # store the table name to clean the database at the end
                TBS_NAME+=("${TB_NAME}")

                if [[ -f "${OUTPUT_DIR}/${OUTPUT_FILE}.tif" ]];
                then
                    # store the generated file into input list used in next step
                    INPUT_FILES+=("${OUTPUT_FILE}.tif")
                fi;
                
                if [[ -f "${OUTPUT_DIR}/${REFERENCE_OUTPUT_FILE}.tif" ]];
                then
                    # store the generated file into input list used in next step
                    REFERENCE_INPUT_FILES+=("${REFERENCE_OUTPUT_FILE}.tif")

                elif [[ -f "${OUTPUT_DIR}/${OUTPUT_FILE}.tif" ]]; then
                    # using the default generated file
                    REFERENCE_INPUT_FILES+=("${OUTPUT_FILE}.tif")
                fi;
                
            else
                echo "Table do not exists: ${TB_NAME}"
            fi;
        done # end build raster for each table

        # ------------------------------------------------ #
        # GENERATE ONE RASTER FOR THE CURRENT BIOME AND BASE YEAR
        # ------------------------------------------------ #
        # build the biome raster using each table raster
        INPUT_FILES=$(echo ${INPUT_FILES[@]})
        OUTPUT_FILE="prodes_${TARGET_NAME}_${BASE_YEAR}"

        # generate the final file with all intermediary files
        generate_final_raster "${INPUT_FILES}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

        # join all style fractions, sfl and sldf into one style file for each style format
        generate_main_palette_entries "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${BASE_YEAR}"
        
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

        # remove temporary files
        remove_temporary_files "${INPUT_FILES}" "${OUTPUT_DIR}" "file"

        # ------------------------------------------------ #
        # GENERATE ONE RASTER FOR THE CURRENT BIOME AND REFERENCE YEAR
        # ------------------------------------------------ #
        if [[ ! "${BASE_YEAR}" = "${REFERENCE_YEAR}" ]]; then
            # build the biome raster using each table raster
            REFERENCE_INPUT_FILES=$(echo ${REFERENCE_INPUT_FILES[@]})
            OUTPUT_FILE="prodes_${TARGET_NAME}_${REFERENCE_YEAR}"

            # generate the final file with all intermediary files
            generate_final_raster "${REFERENCE_INPUT_FILES}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

            # join all style fractions, sfl and sldf into one style file for each style format
            generate_main_palette_entries "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${REFERENCE_YEAR}"
            
            # generate the style as QML file
            QML_FRACTIONS=("${OUTPUT_FILE}.sfl")
            generate_qml_file "${QML_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"
            
            # generate the style as SLD file
            SLD_FRACTIONS=("${OUTPUT_FILE}.sldf")
            generate_sld_file "${SLD_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

            # remove temporary files
            remove_temporary_files "${REFERENCE_INPUT_FILES}" "${OUTPUT_DIR}" "file"
        fi;
        # drop the temporary tables
        TBS_NAME=$(echo ${TBS_NAME[@]})
        drop_temporary_table "${TBS_NAME}"
    else
        # if skip build of each biome mosaic we need the name for output file to build BR mosaic
        if [[ ! "${BASE_YEAR}" = "${REFERENCE_YEAR}" ]]; then
            OUTPUT_FILE="prodes_${TARGET_NAME}_${REFERENCE_YEAR}"
        else
            OUTPUT_FILE="prodes_${TARGET_NAME}_${BASE_YEAR}"
        fi;
    fi;

    # store file name of each biome raster, used to make BR mosaic
    if [[ "${BUILD_BR_MOSAIC}" = "yes" && -f "${OUTPUT_DIR}/${OUTPUT_FILE}.tif" && ! "${TARGET_NAME}" = "amazonia_legal" ]];
    then
        INPUT_FILES_MOSAIC+=("${OUTPUT_DIR}/${OUTPUT_FILE}.tif")
    fi;

done # end of biome list

# if the Brasil raster mosaic is enable, join all rasters into one using the REFERENCE_YEAR input rasters
if [[ "${BUILD_BR_MOSAIC}" = "yes" ]];
then
    INPUT_FILES_MOSAIC=$(echo ${INPUT_FILES_MOSAIC[@]})
    OUTPUT_FILE="prodes_brasil_${REFERENCE_YEAR}"
    # The output directory for BR mosaic
    OUTPUT_DIR="${BASE_PATH_DATA}"
    
    # generate the final file with all intermediate files
    generate_final_raster "${INPUT_FILES_MOSAIC}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

    if [[ "${BUILD_FIRES_DASHBOARD_PRODUCTS}" = "yes" ]];
    then
        # generate a base map from prodes with forest + non-forest + hydrography
        generate_fires_dashboard_products "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${REFERENCE_YEAR}" "p1"

        # generate a map from deforestation data from more than 3 years ago
        generate_fires_dashboard_products "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${REFERENCE_YEAR}" "p2"

        # generate a map only with recent deforestation less than 3 years old
        generate_fires_dashboard_products "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${REFERENCE_YEAR}" "p3"
    fi;

    # join all style fractions into one style file for each style format, QML and SLD
    generate_main_palette_entries "${OUTPUT_FILE}" "${OUTPUT_DIR}" "${REFERENCE_YEAR}"

    # generate the style as QML file
    QML_FRACTIONS=("${OUTPUT_FILE}.sfl")
    generate_qml_file "${QML_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"
    
    # generate the style as SLD file
    SLD_FRACTIONS=("${OUTPUT_FILE}.sldf")
    generate_sld_file "${SLD_FRACTIONS}" "${OUTPUT_FILE}" "${OUTPUT_DIR}"

fi;


# remove the temporary files to clean the output dirs
DB_NAMES=$(echo ${DB_NAMES[@]})
remove_temporary_files "${DB_NAMES}" "${BASE_PATH_DATA}" "dir"