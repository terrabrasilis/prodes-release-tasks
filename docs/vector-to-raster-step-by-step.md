## Steps for building Geotiff PRODES.

As a precondition we consider that there is a previous geotiff file.

### Use Case for Amazon 2023

For the 2023 Amazon data we use the increments of deforestation, residual and cloud.

1) Starting with 2022 file

1.1) Get the original 2022 file from the TerraBrasilis download page

1.2) Convert cloud 2022 to forest. Rewrite the number 32 to 1.

```sh
gdal_calc.py -A PDigital2000_2022_AMZ_raster.tif  --quiet --calc="((A*logical_and(A>=0,A<=31)) + (A==32)*1 + (A*logical_and(A>=33,A<=110)))" --outfile PDigital2000_2022_AMZ_raster_semnv.tif
```

2) Create a tiff for each data: increment/cloud/residual 2023 (using the same bbox and resolution as tif 2022)

2.1) 2023 increment

```sh
gdal_rasterize -burn 23 -tr 0.0002689997882979999733 -0.000269000486077000027 -te  -73.9783163999999971 -18.0406292244049773 -43.9135550608740317 5.2714908999999999 -a_nodata 255 -ot Byte PG:"host=localhost dbname='postgres' user='postgres' password='postgres'" -sql "SELECT * FROM public.yearly_deforestation_2008_2023 where class_name = 'd2023'" prodes_incremento2023.tif &
```

2.2) 2023 cloud

```sh
gdal_rasterize -burn 32 -tr 0.0002689997882979999733 -0.000269000486077000027 -te  -73.9783163999999971 -18.0406292244049773 -43.9135550608740317 5.2714908999999999 -a_nodata 255 -ot Byte PG:"host=localhost dbname='postgres' user='postgres' password='postgres'" -sql "SELECT * FROM public.yearly_deforestation_2008_2023 where class_name = 'NUVEM'" prodes_nuvem2023.tif &
```

2.3) 2023 residual

```sh
gdal_rasterize -burn 63 -tr 0.0002689997882979999733 -0.000269000486077000027 -te  -73.9783163999999971 -18.0406292244049773 -43.9135550608740317 5.2714908999999999 -a_nodata 255 -ot Byte PG:"host=localhost dbname='postgres' user='postgres' password='postgres'" -sql "SELECT * FROM public.yearly_deforestation_2008_2023 where class_name = 'r2023'" prodes_residuo2023.tif &
```

3) Create a 2023 tiff using the previous files from step 2

3.1) Create a virtual raster using the files from steps 1.2 + 2.1 + 2.2 + 2.3

```sh
gdalbuildvrt prodes2023.vrt PDigital2000_2022_AMZ_raster_semnv.tif prodes_incremento2023.tif prodes_nuvem2023.tif prodes_residuo2023.tif
```

3.2) Create the final tiff using the virtual raster from step 3.1

```sh
gdal_translate -of GTiff -co "COMPRESS=LZW"  -co BIGTIFF=YES prodes2023.vrt PDigital2000_2023_AMZ_raster.tif
```

4) Edit the old QML legend file to add a new entry for each new piece of data, as an example.

```xml
class 23 (d2023)
class 63 (r2023)
```
And save as: PDigital2000_2023_AMZ_raster.qml