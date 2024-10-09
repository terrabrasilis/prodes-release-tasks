get_table_name(){
    TARGET="${1}"
    TABLE="${2}"
    TB=`get_${TABLE}_table_name "${TARGET}"`
    echo "${TB}"
}

get_table(){
    TARGET="${1}"
    TB="${2}"
    if [[ "${TARGET}" = "amazonia" ]]; then
        TB="${TB}_biome"
    fi;
    echo "${TB}"
}

get_yearly_table_name(){
    TB=$(get_table "${1}" "yearly_deforestation")
    echo "${TB}"
}

get_residual_table_name(){
    TB=$(get_table "${1}" "residual")
    echo "${TB}"
}

get_hydrography_table_name(){
    TB=$(get_table "${1}" "hydrography")
    echo "${TB}"
}

get_cloud_table_name(){
    TB=$(get_table "${1}" "cloud")
    echo "${TB}"
}

get_no_forest_table_name(){
    TARGET="${1}"
    # default name
    TB=""
    # Case Amazon Biome
    if [[ "${TARGET}" = "amazonia" ]]; then
        TB="no_forest_biome"
    fi;
    # Case Legal Amazon
    if [[ "${TARGET}" = "amazonia_legal" ]]; then
        TB="no_forest"
    fi;
    echo "${TB}"
}

get_accumulated_table_name(){
    TARGET="${1}"
    TB="accumulated_deforestation_2000"
    # Case Amazon Biome and Legal Amazon
    if [[ "${TARGET}" = "amazonia" || "${TARGET}" = "amazonia_legal" ]]; then
        TB="accumulated_deforestation_2007"
    fi;
    TB=$(get_table "${TARGET}" "${TB}")
    echo "${TB}"
}

# ############################
# NF data is only in Amazonia
# ############################
get_yearly_nf_table_name(){
    echo "yearly_deforestation_nf_biome"
}

get_residual_nf_table_name(){
    echo "residual_nf_biome"
}

get_hydrography_nf_table_name(){
    echo "hydrography_nf_biome"
}

get_cloud_nf_table_name(){
    echo "cloud_nf_biome"
}

get_accumulated_nf_table_name(){
    echo "accumulated_deforestation_2000_nf_biome"
}
# ############################
# end of NF data
# ############################

get_border_table_name(){
    TARGET="${1}"
    # default name
    TB="biome_border"
    # Case Amazon Biome
    if [[ "${TARGET}" = "amazonia" ]]; then
        TB="amazon_biome_border"
    fi;
    # Case Legal Amazon
    if [[ "${TARGET}" = "amazonia_legal" ]]; then
        TB="brazilian_legal_amazon"
    fi;
    echo "${TB}"
}

get_class_number(){
    DATA_PATTERN=$(echo "${1}" | cut -d'_' -f1)

    case $DATA_PATTERN in

        yearly | accumulated)
            echo "substring(class_name, 4, 2)::integer as class_number, class_name"
            ;;

        residual)
            echo "substring(class_name, 4, 2)::integer+40 as class_number, class_name"
            ;;

        hydrography)
            echo "91::integer as class_number, 'Hidrografia' as class_name"
            ;;

        biome | amazon | brazilian)
            echo "100::integer as class_number, 'Vegetação Nativa' as class_name"
            ;;

        no)
            echo "101::integer as class_number, 'Não Floresta' as class_name"
            ;;
        cloud)
            echo "99::integer as class_number, 'Nuvem' as class_name"
            ;;
        *)
            echo "255::integer as class_number, 'no data' as class_name"
            ;;
    esac
}

table_exists(){
    TB="${1}"

    SQL="SELECT table_name FROM information_schema.tables WHERE table_name='${TB}';"
    EXISTS=($(${PATH_BIN}/psql ${PG_CON} -t -c "${SQL};"))
    echo "${EXISTS}"
}

create_table_to_burn(){
    TB="${1}"
    WHERE=""
    if [[ ! "${2}" = "" ]]; then
        WHERE="${2}"
    fi;
    DATA_PATTERN=$(get_class_number "${1}")
    SQL="CREATE TABLE IF NOT EXISTS public.burn_${TB} AS"
    SQL="${SQL} WITH target AS ("
    SQL="${SQL} 	 SELECT ${DATA_PATTERN}, geom FROM public.${TB} ${WHERE}"
    SQL="${SQL} )"
    SQL="${SQL} SELECT * FROM target"
    ${PATH_BIN}/psql ${PG_CON} -t -c "${SQL};"
}

drop_table_burn() {
    if [[ "${REMOVE_TMP_FILES}" = "yes" ]];
    then
        TB="${1}"
        SQL="DROP TABLE IF EXISTS public.burn_${TB}"
        ${PATH_BIN}/psql ${PG_CON} -t -c "${SQL};"
    fi;
}

get_extent(){
    TARGET="${1}"
    TB=$(get_border_table_name "${TARGET}")

    SQL="WITH target AS"
    SQL="${SQL}( SELECT ST_Extent(geom) as bbox FROM public.${TB} )"
    SQL="${SQL}SELECT ST_XMin(bbox) ||','|| ST_YMin(bbox) ||','|| ST_XMax(bbox) ||','|| ST_YMax(bbox) FROM target"
    BBOX=($(${PATH_BIN}/psql ${PG_CON} -t -c "${SQL};"))
    
    XMIN=$(echo "${BBOX}" | cut -d',' -f1)
    YMIN=$(echo "${BBOX}" | cut -d',' -f2)
    XMAX=$(echo "${BBOX}" | cut -d',' -f3)
    YMAX=$(echo "${BBOX}" | cut -d',' -f4)
    echo "${XMIN} ${YMIN} ${XMAX} ${YMAX}"
}

generate_raster(){
    TB_NAME="${1}"
    BBOX=${2}
    PGCONNECTION="${3}"
    OUTPUT="${4}"
    gdal_rasterize -tr 0.000268900 -0.000268900 \
    -te ${BBOX} \
    -a_nodata 255 -co "COMPRESS=LZW" \
    -ot Byte PG:"${PGCONNECTION}" \
    -a "class_number" \
    -sql "SELECT class_number, geom FROM public.burn_${TB_NAME}" "${OUTPUT}.tif"
}

generate_final_raster(){
    INPUT_FILES="${1}"
    OUTPUT_FILE="${2}"
    DATA_DIR="${3}"

    cd ${DATA_DIR}

    gdalbuildvrt "${OUTPUT_FILE}.vrt" ${INPUT_FILES}

    gdal_translate -of GTiff -co "COMPRESS=LZW" -co BIGTIFF=YES "${OUTPUT_FILE}.vrt" "${OUTPUT_FILE}.tif"

    cd -
}

generate_palette_entries(){
    # Used to read inside python script
    export TB_NAME="${1}"
    export DATA_DIR="${2}"
    export PG_CONN="${3}"
    # used to generate and store each fraction of QML and SLD palette entries on data dir to build the final style files
    python3 build_style_fraction.py
}

generate_main_palette_entries(){
    # Used to read inside python script
    export FILE_NAME="${1}"
    export DATA_DIR="${2}"
    # used to join each QML and SLD biome files into one mosaic style file
    python3 build_style.py
}

generate_report_file() {
    FILE_NAME="${1}"
    DATA_DIR="${2}"
    
    # to create a PERMANENT directory using for the next step
    ${PATH_BIN}/grass -e -c ${DATA_DIR}/${FILE_NAME}.tif ${DATA_DIR}/MAPSET

    # generate the report
    ${PATH_BIN}/grass ${DATA_DIR}/MAPSET/PERMANENT --exec bash grass_report.sh "${DATA_DIR}" "${FILE_NAME}"

    # remove the MAPSET 
    rm -rf ${DATA_DIR}/MAPSET
}

generate_final_zip_file(){
    FILE_NAME="${1}"
    DATA_DIR="${2}"

    zip -j ${DATA_DIR}/${FILE_NAME}.zip ${DATA_DIR}/${FILE_NAME}.*
}

add_qml_start(){
    OUTPUT_FILE="${1}"
    DATA_DIR="${2}"

    echo "<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>" > "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<qgis maxScale=\"0\" styleCategories=\"AllStyleCategories\" version=\"3.10.4-A Coruña\" hasScaleBasedVisibilityFlag=\"0\" minScale=\"1e+08\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<flags>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Identifiable>1</Identifiable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Removable>1</Removable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Searchable>1</Searchable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</flags>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<customproperties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<property key=\"WMSBackgroundLayer\" value=\"false\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<property key=\"WMSPublishDataSourceUrl\" value=\"false\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<property key=\"embeddedWidgets/count\" value=\"0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</customproperties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<pipe>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rasterrenderer type=\"paletted\" band=\"1\" alphaBand=\"-1\" opacity=\"1\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rasterTransparency/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<minMaxOrigin>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<limits>None</limits>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<extent>WholeRaster</extent>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<statAccuracy>Estimated</statAccuracy>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<cumulativeCutLower>0.02</cumulativeCutLower>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<cumulativeCutUpper>0.98</cumulativeCutUpper>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<stdDevFactor>2</stdDevFactor>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</minMaxOrigin>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<colorPalette>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
}

add_qml_end(){
    OUTPUT_FILE="${1}"
    DATA_DIR="${2}"

    echo "</colorPalette>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<colorramp type=\"cpt-city\" name=\"[source]\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop v=\"0\" k=\"inverted\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop v=\"cpt-city\" k=\"rampType\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop v=\"cb/seq/YlOrRd_09\" k=\"schemeName\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop v=\"\" k=\"variantName\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</colorramp>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</rasterrenderer>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<brightnesscontrast contrast=\"0\" brightness=\"0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<huesaturation grayscaleMode=\"0\" colorizeRed=\"255\" saturation=\"0\" colorizeGreen=\"128\" colorizeOn=\"0\" colorizeStrength=\"100\" colorizeBlue=\"128\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rasterresampler maxOversampling=\"2\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</pipe>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<blendMode>0</blendMode>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</qgis>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
}

generate_qml_file(){
    QML_FRACTIONS="${1}"
    OUTPUT_FILE="${2}"
    DATA_DIR="${3}"

    add_qml_start "${OUTPUT_FILE}" "${DATA_DIR}"

    for QML_FRACTION in ${QML_FRACTIONS[@]}
    do
        FRACTION=$(cat "${DATA_DIR}/${QML_FRACTION}")
        echo "${FRACTION}" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    done;

    add_qml_end "${OUTPUT_FILE}" "${DATA_DIR}"
}

add_sld_start(){
    OUTPUT_FILE="${1}"
    DATA_DIR="${2}"
    LAYER_NAME="${3}"

    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<StyledLayerDescriptor xmlns=\"http://www.opengis.net/sld\" version=\"1.0.0\" xmlns:gml=\"http://www.opengis.net/gml\" xmlns:sld=\"http://www.opengis.net/sld\" xmlns:ogc=\"http://www.opengis.net/ogc\">" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<UserLayer>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:LayerFeatureConstraints>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:FeatureTypeConstraint/>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:LayerFeatureConstraints>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:UserStyle>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:Name>${OUTPUT_FILE}</sld:Name>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:FeatureTypeStyle>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:Rule>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:RasterSymbolizer>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:ChannelSelection>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:GrayChannel>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:SourceChannelName>1</sld:SourceChannelName>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:GrayChannel>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:ChannelSelection>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "<sld:ColorMap type=\"values\">" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
}

add_sld_end(){
    OUTPUT_FILE="${1}"
    DATA_DIR="${2}"

    echo "</sld:ColorMap>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:RasterSymbolizer>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:Rule>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:FeatureTypeStyle>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</sld:UserStyle>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</UserLayer>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    echo "</StyledLayerDescriptor>" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"

}

generate_sld_file(){
    SLD_FRACTIONS="${1}"
    OUTPUT_FILE="${2}"
    DATA_DIR="${3}"

    add_sld_start "${OUTPUT_FILE}" "${DATA_DIR}"

    for SLD_FRACTION in ${SLD_FRACTIONS[@]}
    do
        FRACTION=$(cat "${DATA_DIR}/${SLD_FRACTION}")
        echo "${FRACTION}" >> "${DATA_DIR}/${OUTPUT_FILE}.sld"
    done;

    add_sld_end "${OUTPUT_FILE}" "${DATA_DIR}"
}

remove_temporary_files(){
    DB_NAMES="${1}"
    BASE_DIR="${2}"

    if [[ "${REMOVE_TMP_FILES}" = "yes" ]];
    then
        for DBNAME in ${DB_NAMES[@]}
        do
            rm ${BASE_DIR}/${DBNAME}/*.{sfl,sldf,vrt}
        done;
    fi;
}