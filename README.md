## PRODES release data

Set of scripts to read data from the PostgreSQL/PostGIS database and write it to a file.

The first case is to generate Shapefiles and GeoPackages.

The second case is to generate the Geotiffs.

The goal of the first and second cases is necessary for publication on the download page at PRODES dissemination events, generally in the year in which new data is released.

The precondition is the existence of a database for each PRODES biome with the standard names and columns for tables of the main data classes of the PRODES Project.

## PostgreSQL/PostGIS to vector file

Set of scripts for reading vector data from the PostgreSQL/PostGIS database and writing it to a raster file in Geotiff format.

Details can be found in ./pg-to-vector-file/README.md

## PostgreSQL/PostGIS to raster file

Set of scripts for reading vector data from the PostgreSQL/PostGIS database and writing it to a raster file in Geotiff format.

Details can be found in ./pg-to-raster-file/README.md
