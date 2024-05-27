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

        border)
            echo "100::integer as class_number, 'Floresta' as class_name"
            ;;

        no_forest)
            echo "101::integer as class_number, 'Nao Floresta' as class_name"
            ;;
        *)
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

generate_raster(){
    TB_NAME="${1}"
    BBOX=${2}
    PGCONNECTION="${3}"
    OUTPUT="${4}"
    gdal_rasterize -tr 0.0002689997882979999733 -0.000269000486077000027 \
    -te ${BBOX} \
    -a_nodata 255 -ot Byte PG:"${PGCONNECTION}" \
    -a "class_number" \
    -sql "SELECT class_number, geom FROM public.burn_${TB_NAME}" "${OUTPUT}.tif"
}

generate_final_raster(){
    INPUT_FILES="${1}"
    OUTPUT_FILE="${2}"

    gdalbuildvrt "${OUTPUT_FILE}.vrt" "${OUTPUT_FILE}.tif" "${INPUT_FILES}"
}