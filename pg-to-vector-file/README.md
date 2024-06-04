# Export PostGIS tables to vector file

Used to export tables with geographic vector data to Shapefiles and GeoPackage files.

No ports are exposed, runs only autonomous job on container starts.

## Configuration

We have some configurations to make this scripts works.

Define a directory to store your output files and include a configuration file for the SGDB host that you want run the exportation task.

The data storage directory is used to map to a volume inside the container, see the "Export Settings" and "Container configuration" sections.

See the "Export Settings" section to find more setting options about the export task.

### SGDB host configuration

The "dbconf.sh" script searches for the "pgconfig.exportation" file within the root directory.

If "pgconfig.exportation" is not found, the script will create one as an example.

You need to provide SGDB host settings by editing "pgconfig.exportation".

The setting file example:
```txt
user="postgres"
host="localhost"
port=5432
schema="public"
password="postgres"
```

### Export Settings

The export expects some parameter definitions. These parameters are defined in the "export_tables_to_file_config.sh" script and have default values, they are:

```sh
# if you want export only filtered tables, set the table names into FILTER variable below and removing the character # to uncomment that.
# FILTER=("table_name_a" "table_name_b" "table_name_c")
FILTER=("accumulated_deforestation_2007" "hydrography" "no_forest" "residual" "yearly_deforestation")
#
# Used for cloud table or forest table, generate one shape of each class_name/year to avoid the limit of maximum size of shapefiles
BREAK_SHP=("forest" "cloud" "forest_biome" "cloud_biome")
# BREAK_SHP=("forest_biome" "cloud_biome")
#
# used to confirm the sub_class column only for the deforestation tables in the list below (valid for "amazonia" and "amazonia_legal")
TABLES_WITH_SUBCLASS=("yearly_deforestation" "yearly_deforestation_biome")
#
# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEAR="2023"
#
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
#
# Remove the output files after ZIP
RM_OUT="no"
#
# Fix geometries before export
FIX="no"
#
# Fix FID before export. Make an update into sequential numeric column used as primary key.
FID="no"
#
# Export to Shapefile
SHP="no"
#
# Export to GeoPackage
GPKG="yes"
# if same file is yes, than the gpkg file name is the same of the all data from each database.
SAME_FILE="yes"

# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
# list of biomes to export data
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("pantanal" "amazonia")
```

If you need to change these values, edit the "export_tables_to_file_config.sh" file inside the "pg-to-vector-file/" directory on repository root.

### Container configuration

The exportation task need a directory to use as a docker volume where output data is written.

Adjust the path in the "run-pg-export-to-file.sh", using the VOLUME_HOST if necessary.
```sh
VOLUME_HOST="/main/storage/exported/files"
```

## Manual container run

Before running, read the "Container configuration" session.

Using canonical form.
```sh
run-pg-export-to-file.sh vector
```