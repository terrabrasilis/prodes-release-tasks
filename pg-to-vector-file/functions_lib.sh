fix_uid(){
    if [[ "${FID}" = "yes" ]]; then
        SQL="CREATE SEQUENCE ${schema}.update_uid_for_all INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9999999999999 CACHE 1;"
        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
        TB="$1"
        SQL="UPDATE ${schema}.${TB} SET uid=nextval('${schema}.update_uid_for_all'::regclass);"
        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
        SQL="DROP SEQUENCE IF EXISTS ${schema}.update_uid_for_all;"
        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    fi;
}

fix_geom(){
    TB="$1"
    SQL="UPDATE ${schema}.${TB} SET geom=ST_MakeValid(geom) WHERE NOT ST_IsValid(geom);"
    if [[ "${FIX}" = "yes" ]]; then
        ${PG_BIN}/psql ${PG_CON} -t -c "${SQL}"
    fi;
}

export_shp(){
    SQL="$1"
    TB="$2"
    if [[ "${SHP}" = "yes" ]]; then
        ogr2ogr -overwrite -f "ESRI Shapefile" ${OUTPUT_DATA} -nln ${TB} PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -sql "${SQL}"
        zip -j "${OUTPUT_DATA}/${TB}.zip" "${OUTPUT_DATA}/${TB}.shp" "${OUTPUT_DATA}/${TB}.shx" "${OUTPUT_DATA}/${TB}.prj" "${OUTPUT_DATA}/${TB}.dbf"
    fi;
}

export_gpkg(){
    # https://gis.stackexchange.com/questions/327958/ogr2ogr-write-multiple-layers-to-one-geopackage
    # https://gdal.org/programs/ogr2ogr.html#cmdoption-ogr2ogr-update
    # -append (insert new data to the same layer)(insere novos dados na mesma camada) 
    # -update (open the existing file, in update mode, to create a new layer named by the -nln parameter value.)
    SQL="$1"
    TB="$2"
    FNAME="${TB}"
    echo "call export_gpkg..................."
    echo "database=${database}"
    echo "SL=${SQL}"
    echo "TB=${TB}"
    if [[ "$GPKG" = "yes" ]]; then
        if [[ "$SAME_FILE" = "yes" ]]; then
            FNAME="${GPKG_FNAME}"
            if [[ -f "${OUTPUT_DATA}/${FNAME}.gpkg" ]]; then
                ogr2ogr -f "GPKG" ${OUTPUT_DATA}/${FNAME}.gpkg -nln ${TB} PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -update -sql "${SQL}"
            else
                ogr2ogr -f "GPKG" ${OUTPUT_DATA}/${FNAME}.gpkg -nln ${TB} PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -sql "${SQL}"
            fi;
        else
            ogr2ogr -f "GPKG" ${OUTPUT_DATA}/${FNAME}.gpkg -nln ${TB} PG:"host=${host} dbname=${database} port=${port} user=${user} password=${password}" -sql "${SQL}"
        fi;
        zip -j ${OUTPUT_DATA}/${FNAME}.gpkg.zip ${OUTPUT_DATA}/${FNAME}.gpkg
    fi;
}