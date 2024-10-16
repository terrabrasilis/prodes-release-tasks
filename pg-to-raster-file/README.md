# Export PostGIS tables to raster file

Used to export tables with geographic vector data to raster file.

The output products are:

    - One GeoTiff and style file for each biome;
    - One GeoTiff and style file for Legal Amazon;
    - One GeoTiff and style file for Brasil;
    - Three GeoTiffs for Brasil to use as input in the Fires Dashboard;
 > See the "Export Settings" section to control what you want as outputs.

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

# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"

# list of biomes to export data
# PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")
PRODES_DBS=("pampa" "caatinga" "pantanal" "mata_atlantica" "cerrado" "amazonia" "amazonia_legal")

#
# join all rasters into a single file. If disable, the fires dashboard rasters do not generated.
RASTERS_MOSAIC="yes"

#
# remove temporary files and tables?
REMOVE_TMP_FILES="yes"

#
# default values for BBOX and Pixel size.
# force the same BBOX Brazil for all biomes
BBOX="-73.98318215899995 -33.75117799399993 -28.847770352999916 5.269580833000035"
PIXEL_SIZE="0.000268900 -0.000268900"
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