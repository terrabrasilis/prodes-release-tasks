## PRODES release data

Set of scripts to read data from the PostgreSQL/PostGIS database and write it to a file.

The first case is to generate Shapefiles and GeoPackages.

The second case is to generate the Geotiffs.

The objective of the first and second cases is to generate files for publication on the download page at PRODES dissemination events, generally in the year in which new data are released.

The precondition is the existence of a database for each PRODES biome with the standard names and columns for tables of the main data classes of the PRODES Project.

### Software tools

Most scripts are written in bash-compatible Shell Script. To connect to PostgreSQL we need client libraries and CLI tools. There are snippets of code that depend directly or indirectly on Python. The export core is provided by GDAL/OGR.

To easily resolve the execution environment, we provide a Docker image with all dependencies. But, if you want to use your own environment, look inside the Dockerfile.

### PostgreSQL/PostGIS to vector file

Set of scripts for reading vector data from the PostgreSQL/PostGIS database and writing it to a vector files in Shapefile and GeoPackage formats.

Details can be found in [README](pg-to-vector-file/README.md).

### PostgreSQL/PostGIS to raster file

Set of scripts for reading vector data from the PostgreSQL/PostGIS database and writing it to a raster file in Geotiff format.

Details can be found in [README](pg-to-raster-file/README.md).
