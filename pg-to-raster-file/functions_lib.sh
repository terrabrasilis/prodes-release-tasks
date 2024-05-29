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
            echo "100::integer as class_number, 'Floresta' as class_name"
            ;;

        no_forest)
            echo "101::integer as class_number, 'Nao Floresta' as class_name"
            ;;
        cloud)
            echo "99::integer as class_number, 'Nuvem' as class_name"
            ;;
        *)
            echo "255::integer as class_number, 'no data' as class_name"
            ;;
    esac
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
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL};"
}

drop_table_burn() {
    TB="${1}"
    SQL="DROP TABLE IF EXISTS public.burn_${TB}"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL};"
}

get_extent(){
    TARGET="${1}"
    TB=$(get_border_table_name "${TARGET}")

    SQL="WITH target AS"
    SQL="${SQL}( SELECT ST_Extent(geom) as bbox FROM public.${TB} )"
    SQL="${SQL}SELECT ST_XMin(bbox) ||','|| ST_YMin(bbox) ||','|| ST_XMax(bbox) ||','|| ST_YMax(bbox) FROM target"
    BBOX=($(${PG_BIN}/psql ${PG_CON} -t -c "${SQL};"))
    
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
    # used to generate and store each fraction of QML palette entry on data dir to build the final QML file
    python3 build_qml.py
}

generate_qml_file(){
    QML_FRACTIONS="${1}"
    OUTPUT_FILE="${2}"
    DATA_DIR="${3}"

    echo "<!DOCTYPE qgis PUBLIC \"http://mrcc.com/qgis.dtd\" \"SYSTEM\">" > "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<qgis hasScaleBasedVisibilityFlag=\"0\" minScale=\"1e+08\" styleCategories=\"AllStyleCategories\" maxScale=\"0\" version=\"3.22.7-Białowieża\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<flags>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Identifiable>1</Identifiable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Removable>1</Removable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Searchable>1</Searchable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Private>0</Private>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</flags>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<temporal fetchMode=\"0\" enabled=\"0\" mode=\"0\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<fixedRange>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<start></start>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<end></end>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</fixedRange>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</temporal>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<customproperties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option type=\"Map\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"WMSBackgroundLayer\" value=\"false\" type=\"bool\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"WMSPublishDataSourceUrl\" value=\"false\" type=\"bool\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"embeddedWidgets/count\" value=\"0\" type=\"int\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"identify/format\" value=\"Value\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</Option>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</customproperties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<pipe-data-defined-properties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option type=\"Map\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"name\" value=\"\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"properties\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"type\" value=\"collection\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</Option>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</pipe-data-defined-properties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<pipe>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<provider>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<resampling zoomedInResamplingMethod=\"nearestNeighbour\" maxOversampling=\"2\" enabled=\"false\" zoomedOutResamplingMethod=\"nearestNeighbour\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</provider>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rasterrenderer opacity=\"1\" classificationMin=\"7\" classificationMax=\"101\" type=\"singlebandpseudocolor\" nodataColor=\"\" band=\"1\" alphaBand=\"-1\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rasterTransparency/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<minMaxOrigin>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<limits>None</limits>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<extent>WholeRaster</extent>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<statAccuracy>Estimated</statAccuracy>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<cumulativeCutLower>0.02</cumulativeCutLower>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<cumulativeCutUpper>0.98</cumulativeCutUpper>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<stdDevFactor>2</stdDevFactor>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</minMaxOrigin>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rastershader>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<colorrampshader classificationMode=\"2\" minimumValue=\"7\" labelPrecision=\"0\" maximumValue=\"101\" colorRampType=\"INTERPOLATED\" clip=\"0\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<colorramp name=\"[source]\" type=\"gradient\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option type=\"Map\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"color1\" value=\"250,248,47,255\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"color2\" value=\"242,19,249,255\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"discrete\" value=\"0\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"rampType\" value=\"gradient\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"stops\" value=\"0.0106383;217,31,31,255:0.0212766;219,37,34,255:0.0319149;220,44,36,255:0.0425532;222,50,39,255:0.0531915;223,56,42,255:0.0638298;225,63,45,255:0.0744681;227,69,48,255:0.0851064;228,76,51,255:0.0957447;230,82,54,255:0.106383;232,88,57,255:0.117021;233,95,60,255:0.12766;235,101,63,255:0.138298;236,107,66,255:0.148936;238,114,69,255:0.159574;240,120,72,255:0.170213;169,35,53,255:0.265957;55,254,244,255:0.457447;255,242,175,255:0.468085;255,245,179,255:0.478723;255,249,183,255:0.489362;255,252,187,255:0.5;255,255,191,255:0.510638;252,254,190,255:0.521277;248,253,189,255:0.531915;245,251,188,255:0.542553;241,250,187,255:0.553191;238,248,185,255:0.56383;234,247,184,255:0.574468;230,245,183,255:0.585106;227,244,182,255:0.595745;223,242,181,255:0.893617;5,19,177,255:0.989362;48,135,3,255\" type=\"QString\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</Option>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop k=\"color1\" v=\"250,248,47,255\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop k=\"color2\" v=\"242,19,249,255\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop k=\"discrete\" v=\"0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop k=\"rampType\" v=\"gradient\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<prop k=\"stops\" v=\"0.0106383;217,31,31,255:0.0212766;219,37,34,255:0.0319149;220,44,36,255:0.0425532;222,50,39,255:0.0531915;223,56,42,255:0.0638298;225,63,45,255:0.0744681;227,69,48,255:0.0851064;228,76,51,255:0.0957447;230,82,54,255:0.106383;232,88,57,255:0.117021;233,95,60,255:0.12766;235,101,63,255:0.138298;236,107,66,255:0.148936;238,114,69,255:0.159574;240,120,72,255:0.170213;169,35,53,255:0.265957;55,254,244,255:0.457447;255,242,175,255:0.468085;255,245,179,255:0.478723;255,249,183,255:0.489362;255,252,187,255:0.5;255,255,191,255:0.510638;252,254,190,255:0.521277;248,253,189,255:0.531915;245,251,188,255:0.542553;241,250,187,255:0.553191;238,248,185,255:0.56383;234,247,184,255:0.574468;230,245,183,255:0.585106;227,244,182,255:0.595745;223,242,181,255:0.893617;5,19,177,255:0.989362;48,135,3,255\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</colorramp>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"

    for QML_FRACTION in ${QML_FRACTIONS[@]}
    do
        QML_FRACTION=$(cat "${DATA_DIR}/${QML_FRACTION}")
        echo "${QML_FRACTION}" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    done;

    echo "<rampLegendSettings useContinuousLegend=\"0\" minimumLabel=\"\" maximumLabel=\"\" direction=\"0\" orientation=\"2\" prefix=\"\" suffix=\"\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<numericFormat id=\"basic\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option type=\"Map\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"decimal_separator\" value=\"\" type=\"QChar\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"decimals\" value=\"6\" type=\"int\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"rounding_type\" value=\"0\" type=\"int\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"show_plus\" value=\"false\" type=\"bool\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"show_thousand_separator\" value=\"true\" type=\"bool\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"show_trailing_zeros\" value=\"false\" type=\"bool\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<Option name=\"thousand_separator\" value=\"\" type=\"QChar\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</Option>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</numericFormat>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</rampLegendSettings>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</colorrampshader>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</rastershader>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</rasterrenderer>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<brightnesscontrast brightness=\"0\" gamma=\"1\" contrast=\"0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<huesaturation grayscaleMode=\"0\" colorizeBlue=\"128\" colorizeStrength=\"100\" colorizeRed=\"255\" saturation=\"0\" invertColors=\"0\" colorizeOn=\"0\" colorizeGreen=\"128\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<rasterresampler maxOversampling=\"2\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<resamplingStage>resamplingFilter</resamplingStage>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</pipe>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<blendMode>0</blendMode>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</qgis>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
}