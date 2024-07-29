# Export PostGIS tables to GeoJson file

The objective is to create a copy of the cropped LOI tables by biome, simpler and prepared for use in the Dashboard Data Model and Dashboard Application.

This process exported LOI tables with geographic vector data to GeoJson and Shapefiles files following a specific data model.

The main process need apply some changes to improve names of LOIs, fix and simplify geometries to guarantee speed up map render.
Using the PostGIS resources like ST_SimplifyPreserveTopology and ST_MakeValid, to simplify and [GDAL/OGR](https://gdal.org/drivers/vector/geojson.html) tool to export to GeoJson, we produce similary files as old approach.

These output files will be used in the PRODES panel map, through the redis API.
More details can be found in the [Dashboard API repository](https://github.com/terrabrasilis/terrabrasilis-dashboard-api.git).

The old strategy uses [mapshaper](https://mapshaper.org/) online and has been abandoned in favor of this approach.

If we need to return to mapshaper, we can use the CLI-based solution described [here](https://blog.exploratory.io/how-to-reduce-your-geojson-file-size-smaller-for-better-performance-8fb77759870c).

No ports are exposed, runs only autonomous job on container starts.

## Configuration

We have some configurations and patterns to make this scripts works.

### About Geometry simplification

The current approach uses the [OGR simplify](https://gdal.org/programs/ogr2ogr.html#cmdoption-ogr2ogr-simplify) method to apply simplification into all Polygons of LOIs. There is no guarantee of topological consistency between features into GeoJson exported.

You may need to change the tolerance factor using SIMPLIFY_TOLERANCE to set a value. The projection of the expected data is Geographic/SIRGAS2000 (EPSG:4674) and the unit values ​​are in degrees, therefore to define a tolerance value we use an approximation of 1 degree which is ~111000 m

An example:

If we want to use the 200 meter tolerance, the calculation is: 200 / 111000 = 0.0018

```
# the tolerance to simplify Polygons (use dot separator for thousands)
SIMPLIFY_TOLERANCE="0.0018"
```

But be careful when increasing this value because the process may cause small polygons to disappear.

#### Improve Simplification

In the future we may use PostGIS methods to improve geometry simplification, but we need a newer version of PostgreSQL/PostGIS.
This approach can use the PostGIS methods to apply simplification into all Polygons of LOIs.

```sql
-- To see the PostGIS version
SELECT PostGIS_Full_Version();
```

To PostGIS major than or equal to 3.4.0, the best simplification is [ST_CoverageSimplify](https://postgis.net/docs/ST_CoverageSimplify.html)

```
Availability: 3.4.0
Requires GEOS >= 3.12.0
```

To PostGIS minor than 3.4.0, we use the [ST_SimplifyPreserveTopology](https://postgis.net/docs/ST_SimplifyPreserveTopology.html) method.

**IMPORTANT**
We tested ST_SimplifyPreserveTopology but the GeoJson file resulting from the export was insufficient for the expected purpose, as the speed improvement in the application's frontend was small.


### Schemas and Tables

The main condition is to have the schema and table based structure as follows:

 - One schema to each biome border or Legal Amazon border;
 - One table for each LOI, cropped by the border and inside the related schema;

The expected schema names of each border is: "amazonia" "amazonia_legal" "caatinga" "cerrado" "mata_atlantica" "pampa" "pantanal"
The expected table names of each LOI is: municipality, state, ti, uc

Database Structure Representation
```
amazonia (schema)
       |
       municipality (table)
       state (table)
       ti (table)
       uc (table)

cerrado (schema)
      |
      municipality (table)
      state (table)
      ti (table)
      uc (table)
```

LOI tables Structure Representation
```
# columns for state, ti and uc
nome character varying
geom geometry(MultiPolygon,4674)

# columns for municipality
nome character varying
geocodigo character varying
geom geometry(MultiPolygon,4674)
```

### Other Settings

Define a directory to store your output files and include a configuration file for the SGDB host that you want run the exportation task.

The data storage directory is used to map to a volume inside the container, see the "General Settings" and "Container Settings" sections.

See the "General Settings" section to find more setting options about the export task.

### SGDB Settings

The "dbconf.sh" script searches for the "pgconfig.exportation" file within the root directory.

If "pgconfig.exportation" is not found, the script will create one as an example.

You need to provide SGDB host settings by editing "pgconfig.exportation".

The setting file example:
```txt
user="postgres"
host="localhost"
port=5432
password="postgres"
```

### General Settings

The process expects some parameter definitions. These parameters are defined in the "export_tables_to_file_config.sh" script and have default values, they are:

```sh
###############################################
# General settings
###############################################
# Set the output directory (is mapped inside the container after run)
BASE_PATH_DATA="/main/storage/exported/files"
#
# The database name used to apply changes and export auxiliary data
DB_NAME="auxiliary_2022"
# to read the tables or views from selected schema
TABLE_TYPE='BASE TABLE'
#TABLE_TYPE='VIEW'
#
###############################################
# Settings to control the changes in LOI tables
###############################################
# Fix geometries before export
FIX_GEOM="no"
# Fix UC names before export
FIX_UCS="yes"
# the table name of UCs
UC_TABLE_NAME="uc"
# the tolerance to simplify Polygons (use dot separator for thousands)
SIMPLIFY_TOLERANCE="0.0018"
#
###############################################
# Settings about column pattern for LOI tables
###############################################
# we expect that default column name for geometries of LOI is "geom"
LOI_GEOM_COLUMN="geom"
# we expect that default column name for names of LOI is "nome"
LOI_NAME_COLUMN="nome"
#
###############################################
# Settings about what data will be exported
###############################################
#
# The name of the schemas for each LOI cropp.
LOI_SCHEMAS=("amazonia" "amazonia_legal" "caatinga" "cerrado" "mata_atlantica" "pampa" "pantanal")
#
# Control GeoJson exportation
GEOJSON_EXPORT="yes"
# Control Shapefile exportation
SHAPEFILE_EXPORT="no"
```

If you need to change these values, edit the "export_tables_to_file_config.sh" file inside the "lois-to-json-file/" directory on repository root.

### Container Settings

The exportation task need a directory to use as a docker volume where output data is written.

Adjust the path in the "run-pg-export-to-file.sh", using the VOLUME_HOST if necessary.
```sh
VOLUME_HOST="/main/storage/exported/files"
```

If VOLUME_HOST is empty, the default is to use the current directory to store the output files.
For raster option the output is located inside "pg-to-raster-file/" otherwise if it is vector then the locations are "lois-to-json-file/"

## Manual container run

Before running, read the "Container Settings" session.

Using canonical form.
```sh
# Call the script passing the type of exportation and command to docker:
# - "vector" or "raster" or "json"
# - "up" or "down"
# for this process
./run-pg-export-to-file.sh json up
```