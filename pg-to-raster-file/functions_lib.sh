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

        border | amazon | brazilian)
            echo "100::integer as class_number, 'Floresta' as class_name"
            ;;

        no_forest)
            echo "101::integer as class_number, 'Nao Floresta' as class_name"
            ;;
        *)
            echo "255::integer as class_number, 'no data' as class_name"
            ;;
    esac
}

create_table_to_burn(){
    TB="${1}"
    DATA_PATTERN=$(get_class_number "${1}")
    SQL="CREATE TABLE IF NOT EXISTS public.burn_${TB} AS"
    SQL="${SQL} WITH target AS ("
    SQL="${SQL} 	 SELECT ${DATA_PATTERN}, geom FROM public.${TB}"
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

get_color_palette(){
    TB_NAME="${1}"
    SQL="SELECT class_number ||':'|| class_name ||':'|| concat('#', lpad(to_hex(round(random() * 1000000000)::int4),6,'0')) FROM public.burn_${TB_NAME}"
    PALETTE_COLORS=($(${PG_BIN}/psql ${PG_CON} -t -c "${SQL};"))
    echo "${PALETTE_COLORS}"
}

generate_raster(){
    TB_NAME="${1}"
    BBOX=${2}
    PGCONNECTION="${3}"
    OUTPUT="${4}"
    gdal_rasterize -tr 0.0002689997882979999733 -0.000269000486077000027 \
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

generate_color_palette(){
    OUTPUT_FILE="${1}"
    DATA_DIR="${2}"

    echo "<!DOCTYPE qgis PUBLIC \"http://mrcc.com/qgis.dtd\" \"SYSTEM\">" > "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<qgis maxScale=\"0\" version=\"3.10.4-A Coruña\" styleCategories=\"AllStyleCategories\" minScale=\"1e+08\" hasScaleBasedVisibilityFlag=\"0\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  <flags>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <Identifiable>1</Identifiable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <Removable>1</Removable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <Searchable>1</Searchable>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  </flags>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  <customproperties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <property value=\"false\" key=\"WMSBackgroundLayer\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <property value=\"false\" key=\"WMSPublishDataSourceUrl\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <property value=\"0\" key=\"embeddedWidgets/count\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <property value=\"Value\" key=\"identify/format\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  </customproperties>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  <pipe>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <rasterrenderer alphaBand=\"-1\" type=\"paletted\" opacity=\"1\" band=\"1\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "      <rasterTransparency/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "      <minMaxOrigin>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <limits>None</limits>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <extent>WholeRaster</extent>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <statAccuracy>Estimated</statAccuracy>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <cumulativeCutLower>0.02</cumulativeCutLower>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <cumulativeCutUpper>0.98</cumulativeCutUpper>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <stdDevFactor>2</stdDevFactor>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "      </minMaxOrigin>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "      <colorPalette>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"

    echo "<paletteEntry alpha=\"255\" value=\"8\" label=\"8\" color=\"#ffffcc\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"9\" label=\"9\" color=\"#ffffcc\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"10\" label=\"10\" color=\"#ffffcc\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"11\" label=\"11\" color=\"#ffeda0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"12\" label=\"12\" color=\"#ffeda0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"13\" label=\"13\" color=\"#ffeda0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"14\" label=\"14\" color=\"#fed976\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"15\" label=\"15\" color=\"#fed976\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"16\" label=\"16\" color=\"#fed976\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"17\" label=\"17\" color=\"#fed976\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"18\" label=\"18\" color=\"#feb24c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"19\" label=\"19\" color=\"#feb24c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"20\" label=\"20\" color=\"#feb24c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"21\" label=\"21\" color=\"#fd8d3c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"22\" label=\"22\" color=\"#fd8d3c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"23\" label=\"23\" color=\"#fd8d3c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"50\" label=\"50\" color=\"#fd8d3c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"51\" label=\"51\" color=\"#fc4e2a\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"52\" label=\"52\" color=\"#fc4e2a\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"53\" label=\"53\" color=\"#fc4e2a\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"54\" label=\"54\" color=\"#e31a1c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"55\" label=\"55\" color=\"#e31a1c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"56\" label=\"56\" color=\"#e31a1c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"57\" label=\"57\" color=\"#e31a1c\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"58\" label=\"58\" color=\"#bd0026\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"59\" label=\"59\" color=\"#bd0026\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"60\" label=\"60\" color=\"#bd0026\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"61\" label=\"61\" color=\"#800026\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"62\" label=\"62\" color=\"#800026\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"63\" label=\"63\" color=\"#800026\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"91\" label=\"91\" color=\"#0095b6\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"100\" label=\"100\" color=\"#005407\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "<paletteEntry alpha=\"255\" value=\"101\" label=\"101\" color=\"#ea00ff\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"

    # select class_name and class_number from temp teble
    # generate colors
    # build the list of palette entry

    # for PALETTE_ENTRY in ${PALETTE_ENTRIES[@]}
    # do
    #     VALUE=$(echo "${PALETTE_ENTRY}" | cut -d':' -f1)
    #     CLASS=$(echo "${PALETTE_ENTRY}" | cut -d':' -f2)
    #     COLOR=$(echo "${PALETTE_ENTRY}" | cut -d':' -f3)
        
    #     echo "<paletteEntry alpha=\"255\" value=\"${VALUE}\" label=\"${VALUE} ${CLASS}\" color=\"${COLOR}\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    # done;

    echo "      </colorPalette>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "      <colorramp name=\"[source]\" type=\"cpt-city\">" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <prop v=\"0\" k=\"inverted\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <prop v=\"cpt-city\" k=\"rampType\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <prop v=\"cb/seq/YlOrRd_09\" k=\"schemeName\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "        <prop v=\"\" k=\"variantName\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "      </colorramp>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    </rasterrenderer>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <brightnesscontrast brightness=\"0\" contrast=\"0\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <huesaturation saturation=\"0\" colorizeOn=\"0\" grayscaleMode=\"0\" colorizeGreen=\"128\" colorizeRed=\"255\" colorizeBlue=\"128\" colorizeStrength=\"100\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "    <rasterresampler maxOversampling=\"2\"/>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  </pipe>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "  <blendMode>0</blendMode>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"
    echo "</qgis>" >> "${DATA_DIR}/${OUTPUT_FILE}.qml"

}