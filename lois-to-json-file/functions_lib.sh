fix_uc_names(){

    if [[ "${FIX_UCS}" = "yes" ]]; then

        SQL="BEGIN;"

        # create a column to put changes
        SQL="${SQL} ALTER TABLE IF EXISTS ${schema}.${UC_TABLE_NAME}"
        SQL="${SQL} ADD COLUMN ${LOI_NAME_COLUMN}_fix text;"

        # Capitalize first letter
        SQL="${SQL} UPDATE ${schema}.${UC_TABLE_NAME} SET ${LOI_NAME_COLUMN}_fix=INITCAP(${LOI_NAME_COLUMN});"

        PATTERNS_I=("'Área De Proteção Ambiental'" "'Rppn'" "'Reserva Particular Do Patrimônio Natural'" "' Da '" "' Das '" "' De '" "' Do '" "' Dos '" "' A '" "' As '" "' E '" "' O '" "' Os '")
        PATTERNS_O=("'APA'" "'RPPN'" "'RPPN'" "' da '" "' das '" "' de '" "' do '" "' dos '" "' a '" "' as '" "' e '" "' o '" "' os '")
        
        length=${#PATTERNS_I[@]}
        for ((i=0; i<$length; ++i));
        do
            # update based on input/output patterns
            SQL="${SQL} UPDATE ${schema}.${UC_TABLE_NAME} SET ${LOI_NAME_COLUMN}_fix=replace(${LOI_NAME_COLUMN}_fix, "${PATTERNS_I[$i]}", "${PATTERNS_O[$i]}" )"
            SQL="${SQL} WHERE strpos(${LOI_NAME_COLUMN}_fix, "${PATTERNS_I[$i]}")>0;"
        done

        # COPY TO DEFAULT COLUMN "name"
        SQL="${SQL} UPDATE ${schema}.${UC_TABLE_NAME} SET ${LOI_NAME_COLUMN}=${LOI_NAME_COLUMN}_fix"
        SQL="${SQL} WHERE ${LOI_NAME_COLUMN}_fix IS NOT NULL;"

        # remove temp column
        SQL="${SQL} ALTER TABLE IF EXISTS ${schema}.${UC_TABLE_NAME} DROP COLUMN IF EXISTS ${LOI_NAME_COLUMN}_fix;"

        SQL="${SQL} COMMIT;"

        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    fi;
}

fix_geom(){
    TB="$1"
    SQL="UPDATE ${schema}.${TB} SET ${LOI_GEOM_COLUMN}=ST_MakeValid(${LOI_GEOM_COLUMN}) WHERE NOT ST_IsValid(${LOI_GEOM_COLUMN});"
    if [[ "${FIX_GEOM}" = "yes" ]]; then
        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    fi;
}

simplify_geom(){
    TB="$1"
    # create a column to put changes
    SQL="ALTER TABLE IF EXISTS ${schema}.${TB} ADD COLUMN ${LOI_GEOM_COLUMN}_small geometry;"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    
    # https://postgis.net/docs/ST_SimplifyPreserveTopology.html
    tolerance="0.0009" # ~100 meters
    SQL="UPDATE ${schema}.${TB} SET ${LOI_GEOM_COLUMN}_small=ST_SimplifyPreserveTopology(${LOI_GEOM_COLUMN}, ${tolerance});"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"

    SQL="UPDATE ${schema}.${TB} SET ${LOI_GEOM_COLUMN}_small=ST_MakeValid(${LOI_GEOM_COLUMN}_small) WHERE NOT ST_IsValid(${LOI_GEOM_COLUMN}_small);"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
}

export_geojson(){
    TB="$1"
    BIOME="${2}"
    
    simplify_geom "${TB}"

    # remove old json file
    rm ${OUTPUT_DATA}/${BIOME}_${TB}.json

    # Query to load data
    SQL="SELECT ${LOI_NAME_COLUMN}, ${LOI_GEOM_COLUMN}_small as geom FROM ${schema}.${TB}"
    # read from Postgres and write into GeoJson file
    ogr2ogr -f "GeoJSON" ${OUTPUT_DATA}/${BIOME}_${TB}.json \
    -lco WRITE_NAME=NO -lco RFC7946=YES -lco COORDINATE_PRECISION=6 \
    PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -sql "${SQL}"
    
    # remove temp column
    SQL="ALTER TABLE IF EXISTS ${schema}.${TB} DROP COLUMN IF EXISTS ${LOI_GEOM_COLUMN}_small;"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
}