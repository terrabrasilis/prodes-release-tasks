# Export PostGIS tables to raster file

Used to export tables with geographic vector data to raster file.

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
# Used as a database name suffix. Consider that the default database name is prodes_<biome>_nb_p<BASE_YEAR>
BASE_YEAR="2023"
#
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"

# list of biomes to export data
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("pantanal")
```

If you need to change these values, edit the "export_tables_to_file_config.sh" file inside the "pg-to-raster-file/" directory on repository root.

### Container configuration

The exportation task need a directory to use as a docker volume where output data is written.

Adjust the path in the "run-pg-export-to-file.sh", using the VOLUME_HOST if necessary.
```sh
VOLUME_HOST="/main/storage/exported/files"
```

If VOLUME_HOST is empty, the default is to use the current directory to store the output files.
For raster option the output is located inside "pg-to-raster-file/" otherwise if it is vector then the locations are "pg-to-vector-file/"

## Manual container run

Before running, read the "Container configuration" session.

Using canonical form.
```sh
# Call the script passing the type of exportation and command to docker:
# - "vector" or "raster" or "json"
# - "up" or "down"
./run-pg-export-to-file.sh raster up
```