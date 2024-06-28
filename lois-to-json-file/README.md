# Export PostGIS tables to GeoJson file

Used to export LOI tables with geographic vector data to GeoJson files.
These output files will be used into PRODES dashboard map.

The main process need apply some changes to improve names of LOIs, fix and simplify geometries to guarantee speed up map render.

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

### Process Settings

The process expects some parameter definitions. These parameters are defined in the "export_tables_to_file_config.sh" script and have default values, they are:

```sh
#!/bin/bash
#
# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEAR="2023"
#
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
#
# Remove the output files
RM_OUT="no"
#
# Fix geometries before export
FIX_GEOM="no"
# Fix UC names before export
FIX_UCS="yes"
#
# Export to GeoJson
GEOJSON="yes"
# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
# list of biomes as fraction of target database name. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("pantanal" "amazonia")
```

If you need to change these values, edit the "export_tables_to_file_config.sh" file inside the "lois-to-json-file/" directory on repository root.

### Container configuration

The exportation task need a directory to use as a docker volume where output data is written.

Adjust the path in the "run-pg-export-to-file.sh", using the VOLUME_HOST if necessary.
```sh
VOLUME_HOST="/main/storage/exported/files"
```

If VOLUME_HOST is empty, the default is to use the current directory to store the output files.
For raster option the output is located inside "pg-to-raster-file/" otherwise if it is vector then the locations are "lois-to-json-file/"

## Manual container run

Before running, read the "Container configuration" session.

Using canonical form.
```sh
# Call the script passing the type of exportation and command to docker:
# - "vector" "raster" "lois"
# - "up" or "down"
# for this process
./run-pg-export-to-file.sh lois up
```