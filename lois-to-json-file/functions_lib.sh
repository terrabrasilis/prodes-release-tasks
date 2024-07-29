fix_column_names(){
    TB="${1}"
    echo "${LOI_SCHEMA}.${TB}"
    echo "=========================================================="

    SQL="ALTER TABLE IF EXISTS ${LOI_SCHEMA}.${TB} RENAME bioma TO ${LOI_NAME_COLUMN};"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    SQL="ALTER TABLE IF EXISTS ${LOI_SCHEMA}.${TB} RENAME terrai_nom TO ${LOI_NAME_COLUMN};"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    SQL="ALTER TABLE IF EXISTS ${LOI_SCHEMA}.${TB} RENAME sprclasse TO ${LOI_NAME_COLUMN};"
    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"    
}

create_loi_view(){
    # Used to create a View for each LOI tables for biome schemas.
    # These Views are used into GeoServer publication layers.
    #
    TB="${1}"

    SQL="BEGIN;"

    # drop View, if exists, to procceding with changes
    SQL="${SQL} DROP VIEW IF EXISTS public.${LOI_SCHEMA}_${TB};"

    # update geometries to keep only Polygons into ${LOI_GEOM_COLUMN} column
    SQL="${SQL} ALTER TABLE ${LOI_SCHEMA}.${TB} ADD COLUMN geoms geometry(MultiPolygon,4674);"
    SQL="${SQL} UPDATE ${LOI_SCHEMA}.${TB} SET geoms=ST_Multi( ST_CollectionExtract(${LOI_GEOM_COLUMN},3) );"
    SQL="${SQL} ALTER TABLE ${LOI_SCHEMA}.${TB} DROP COLUMN ${LOI_GEOM_COLUMN};"
    SQL="${SQL} ALTER TABLE ${LOI_SCHEMA}.${TB} RENAME geoms TO ${LOI_GEOM_COLUMN};"

    # recreate View after changes
    SQL="${SQL} CREATE OR REPLACE VIEW public.${LOI_SCHEMA}_${TB} AS SELECT * FROM ${LOI_SCHEMA}.${TB};"

    SQL="${SQL} COMMIT;"

    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"

}

create_loi_table(){
    # Used to create a copy of the LOIs biome tables, simpler and prepared for use in the Dashboard Data Model and Dashboard Application.
    # After some adjustments, these tables are exported to GeoJson and Shapefile
    #
    TB="${1}"

    SQL="BEGIN;"

    SQL="${SQL} DROP TABLE IF EXISTS ${LOI_SCHEMA}.${TB}_loi;"
    
    # the municipality LOI needs to have the IBGE geocode when used into Dashboard Data Model process.
    if [[ "${TB}" = "municipality" ]]; then
        
        SQL="${SQL} DROP TABLE IF EXISTS ${LOI_SCHEMA}.${TB}_loi_dm;"

        SQL="${SQL} CREATE TABLE ${LOI_SCHEMA}.${TB}_loi_dm AS"
        SQL="${SQL} WITH concat AS ("
        SQL="${SQL} 	SELECT (mn.${LOI_NAME_COLUMN} || '_' || uf.${LOI_NAME_COLUMN}) as name, mn.geocodigo as cod"
        SQL="${SQL} 	FROM ${LOI_SCHEMA}.municipality mn, ${LOI_SCHEMA}.state uf"
        SQL="${SQL} 	WHERE substring(mn.geocodigo,1,2)=uf.geocodigo"
        SQL="${SQL} )"
        SQL="${SQL} SELECT ct.name, mn.geocodigo as codibge, ST_Multi( ST_CollectionExtract(mn.${LOI_GEOM_COLUMN}, 3) ) as ${LOI_GEOM_COLUMN}"
        SQL="${SQL} FROM ${LOI_SCHEMA}.municipality mn, concat ct"
        SQL="${SQL} WHERE ct.cod=mn.geocodigo"
        SQL="${SQL} GROUP BY 1,2,3;"

    fi;

    SQL="${SQL} CREATE TABLE ${LOI_SCHEMA}.${TB}_loi AS"
    SQL="${SQL} SELECT ${LOI_NAME_COLUMN} as name, ST_Multi( ST_CollectionExtract(${LOI_GEOM_COLUMN}, 3) ) as ${LOI_GEOM_COLUMN}"
    SQL="${SQL} FROM ${LOI_SCHEMA}.${TB}"
    SQL="${SQL} GROUP BY 1,2;"

    SQL="${SQL} COMMIT;"

    ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
}

fix_uc_names(){

    if [[ "${FIX_UCS}" = "yes" ]]; then

        SQL="BEGIN;"

        # create a column to put changes
        SQL="${SQL} ALTER TABLE IF EXISTS ${LOI_SCHEMA}.${UC_TABLE_NAME}"
        SQL="${SQL} ADD COLUMN ${LOI_NAME_COLUMN}_fix text;"

        # Capitalize first letter
        SQL="${SQL} UPDATE ${LOI_SCHEMA}.${UC_TABLE_NAME} SET ${LOI_NAME_COLUMN}_fix=INITCAP(${LOI_NAME_COLUMN});"

        PATTERNS_I=("'Área De Proteção Ambiental'" "'Rppn'" "'Reserva Particular Do Patrimônio Natural'" "' Da '" "' Das '" "' De '" "' Do '" "' Dos '" "' A '" "' As '" "' E '" "' O '" "' Os '")
        PATTERNS_O=("'APA'" "'RPPN'" "'RPPN'" "' da '" "' das '" "' de '" "' do '" "' dos '" "' a '" "' as '" "' e '" "' o '" "' os '")
        
        length=${#PATTERNS_I[@]}
        for ((i=0; i<$length; ++i));
        do
            # update based on input/output patterns
            SQL="${SQL} UPDATE ${LOI_SCHEMA}.${UC_TABLE_NAME} SET ${LOI_NAME_COLUMN}_fix=replace(${LOI_NAME_COLUMN}_fix, "${PATTERNS_I[$i]}", "${PATTERNS_O[$i]}" )"
            SQL="${SQL} WHERE strpos(${LOI_NAME_COLUMN}_fix, "${PATTERNS_I[$i]}")>0;"
        done

        # COPY TO DEFAULT COLUMN "name"
        SQL="${SQL} UPDATE ${LOI_SCHEMA}.${UC_TABLE_NAME} SET ${LOI_NAME_COLUMN}=${LOI_NAME_COLUMN}_fix"
        SQL="${SQL} WHERE ${LOI_NAME_COLUMN}_fix IS NOT NULL;"

        # remove temp column
        SQL="${SQL} ALTER TABLE IF EXISTS ${LOI_SCHEMA}.${UC_TABLE_NAME} DROP COLUMN IF EXISTS ${LOI_NAME_COLUMN}_fix;"

        SQL="${SQL} COMMIT;"

        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    fi;
}

fix_geom(){
    # To fix invalid geometries
    #
    TB="${1}"
    SQL="UPDATE ${LOI_SCHEMA}.${TB} SET ${LOI_GEOM_COLUMN}=ST_MakeValid(${LOI_GEOM_COLUMN}) WHERE NOT ST_IsValid(${LOI_GEOM_COLUMN});"
    if [[ "${FIX_GEOM}" = "yes" ]]; then
        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    fi;
}

export_geojson(){
    # Used to export LOI table to GeoJson used into Dashboard Application via REDIS API
    #
    if [[ "${GEOJSON_EXPORT}" = "yes" ]]; then

        TB="${1}_loi" # Input Table Name
        FN="${1}" # Output File Name

        # remove old json file
        if [[ -f "${OUTPUT_DATA}/${FN}.json" ]]; then
            rm ${OUTPUT_DATA}/${FN}.json
        fi;

        # Query to load data
        SQL="SELECT name, ${LOI_GEOM_COLUMN} FROM ${LOI_SCHEMA}.${TB}"
        # read from Postgres and write into GeoJson file
        ogr2ogr -f "GeoJSON" ${OUTPUT_DATA}/${FN}.pretty.json \
        -lco WRITE_NAME=NO -lco RFC7946=YES -lco COORDINATE_PRECISION=6 -simplify ${SIMPLIFY_TOLERANCE} \
        PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -sql "${SQL}"

        # It's need the jq tool utility (like: apt-get install jq)
        cat ${OUTPUT_DATA}/${FN}.pretty.json | jq -c > ${OUTPUT_DATA}/${FN}.json

        # remove the pretty json file
        if [[ -f "${OUTPUT_DATA}/${FN}.pretty.json" ]]; then
            rm ${OUTPUT_DATA}/${FN}.pretty.json
        fi;
    fi;
}

export_shape(){
    # Used to export LOI table to shapefile used into Dashboard Data Model process
    #
    if [[ "${SHAPEFILE_EXPORT}" = "yes" ]]; then
    
        TB="${1}_loi" # Input Table Name
        FN="${1}" # Output File Name
        
        # For municipalities we need a specific table model.
        if [[ "${1}" = "municipality" ]]; then
            TB="${1}_loi_dm"
        fi;

        # Query to load data
        SQL="SELECT name, geom FROM ${LOI_SCHEMA}.${TB}"
        # read from Postgres and write into Shapefile
        ogr2ogr -overwrite -f "ESRI Shapefile" ${OUTPUT_DATA} -nln ${FN} \
        PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -sql "${SQL}"

        # store on ZIP
        zip -j "${OUTPUT_DATA}/${FN}.zip" "${OUTPUT_DATA}/${FN}.shp" "${OUTPUT_DATA}/${FN}.shx" "${OUTPUT_DATA}/${FN}.prj" "${OUTPUT_DATA}/${FN}.dbf"

        # remove old files
        if [[ -f "${OUTPUT_DATA}/${FN}.shp" ]]; then
            rm ${OUTPUT_DATA}/"${FN}".{shp,shx,prj,dbf}
        fi;
    fi;
}