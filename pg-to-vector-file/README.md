# Export PostGIS tables to vector file

Used to export tables with geographic data from the filtered list of databases for hosts defined by pgconfig files inside the config directory.

No ports are exposed, runs only autonomous job on container starts.

## Configuration

We have some configurations to make this scripts works.

Define a directory to store your output files and include a configuration file for each SGDB host that you need to back up.

The data storage directory is used to map to a volume inside the container, see the docker-compose.yml file or the manual container run session.

The script expects a configuration subdirectory within the data store directory where the configuration files are placed.

See the "Export Settings" section to change export settings.

### SGDB hosts configuration

Suppose the data storage directory is **/data/**, then we need **/data/config/** as the location to place the SGDB host settings.

 - /data/ (where the export files and log file is placed)
 - /data/config/ (where the hosts setting files is placed)

The setting file example:
```txt
user="postgres"
host="localhost"
port=5432
password="postgres"
```

We may need more than one host configuration, so repeat the file using a new name.

 - /data/config/host1
 - /data/config/host2
 - /data/config/host3

## Export Settings

The export expects some parameter definitions. These parameters are defined in the exportconf.sh script and have default values, they are:

```sh
# Remove the output files after ZIP
RM_OUT="yes"
#
# Fix geometries before export
FIX="yes"
#
# Export to Shapefile
SHP="yes"
#
# Export to GeoPackage
GPKG="yes"
SAME_FILE="yes"
#
# the selected schema
SCHEMA="public"
#
# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
```

If you need to change these values, create a new file called "exportconf" inside the config directory and put the KVP that you want overwrite.

 - /data/config/exportconf

Same location used to put the host configuration file, like described in "SGDB hosts configuration" session.

```sh
# KVP example to avoid making valid geometries
FIX="no"
```

## Build image

To change the image tag version, create a new git project version number before creating it.

To build, use the following script.
```sh
./docker-build.sh
```

## Manual container run

Before running, read the configuration session.

Using canonical form.
```sh
docker run -d --rm --name export_pg \
-v /volume/directory:/data \
terrabrasilis/export-pg-dump:v<version>
```
Or use the compose file.
```sh
docker-compose -f docker-compose.yml up -d
```