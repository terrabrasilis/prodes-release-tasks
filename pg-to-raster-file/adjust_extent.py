from osgeo import gdal
import os, sys

def aline_bbox(bbox:str, data_dir:str=None)->str:
    """
    Used to align any input extent coordinates to the Brazil reference grid.
    We expect that input bbox is inside the reference grid bbox.

    parameters:
        bbox, the input bbox, as string, to adjust. The separator character is a comma. (e.g. xmin,ymin,xmax,ymax)*;
        data_dir, the location of reference grid file;

    The output is the adjusted input bbox compatible with the expected bbox from the -te parameter to the gdal_rasterize program (gdal_rasterize -te ${BBOX} ).
    The separator character is a space (e.g. xmin ymin xmax ymax)*

    *Each coordinate value must be a floating point number in degree units compatible with the Geographic/SIRGAS2000 projection, EPSG:4674.
    """
    # location of this file, used as default data dir
    script_dir=os.path.realpath(os.path.dirname(__file__))
    # use the location of this script file as default when DATA_DIR is not provided
    data_dir=data_dir if data_dir is not None else os.getenv("DATA_DIR", script_dir)

    # input geotiff as reference grid
    filename = "{0}/grid_brasil_no_data.tif".format(data_dir)
    bbox=bbox.split(',')

    XMIN=float(bbox[0])
    YMIN=float(bbox[1])
    XMAX=float(bbox[2])
    YMAX=float(bbox[3])

    if not os.path.isfile(filename):
        print("Input file is missing", file=sys.stderr)
        print(f"{filename}", file=sys.stderr)
        return None
    else:
        dataset = gdal.Open(filename, gdal.GA_ReadOnly)
        transform = dataset.GetGeoTransform()

        xOrigin = transform[0]
        yOrigin = transform[3]
        pixelWidth = transform[1]
        pixelHeight = -transform[5]

        def adjust_x(x_value, xOrigin, pixelWidth):
            lon = float(x_value)
            col = int((lon - xOrigin) / pixelWidth)
            return xOrigin + pixelWidth * col

        
        def adjust_y(y_value, yOrigin, pixelHeight):
            lat = float(y_value)
            row = int((yOrigin - lat ) / pixelHeight)
            return yOrigin - pixelHeight * row

        upper_left_xmin=adjust_x(x_value=XMIN, xOrigin=xOrigin, pixelWidth=pixelWidth)
        upper_left_ymax=adjust_y(y_value=YMAX, yOrigin=yOrigin, pixelHeight=pixelHeight)
        lower_right_xmax=adjust_x(x_value=XMAX, xOrigin=xOrigin, pixelWidth=pixelWidth)
        lower_right_ymin=adjust_y(y_value=YMIN, yOrigin=yOrigin, pixelHeight=pixelHeight)

        dataset = None

        return f"{upper_left_xmin} {lower_right_ymin} {lower_right_xmax} {upper_left_ymax}"


# get BBOX from environment variable as input to adjust
bbox=os.getenv("BBOX", None)
bbox=aline_bbox(bbox=bbox, data_dir="/main/storage/exported/files")
if bbox is not None:
    print(bbox)
else:
    SystemExit().code=1