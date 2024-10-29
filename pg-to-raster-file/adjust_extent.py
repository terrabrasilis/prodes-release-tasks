import os

def adjust_xmax(xmax, xmin, pixel_size, keep_exact_cols=False):
    # distance between max and min in X
    XDIST=xmax - xmin
    # if distance is negative value, change to positive
    XDIST=XDIST*-1 if XDIST<0 else XDIST
    # calculate the number of columns using the pixel size
    COLS=int(XDIST / pixel_size) + 1 if not keep_exact_cols else int(XDIST / pixel_size)
    # calculate the XMAX based on number of columns to match with raster grid.
    XMAX=xmin + COLS * pixel_size
    return XMAX

def adjust_xmin(xmin_br, xmin, pixel_size):
    XDIST=xmin - xmin_br
    XDIST=XDIST*-1 if XDIST<0 else XDIST
    COLS=int(XDIST / pixel_size) - 1
    XMIN=xmin_br + COLS * pixel_size
    return XMIN

def adjust_ymax(ymax_br, ymax, pixel_size):
    
    YDIST=ymax_br - ymax
    # if distance is negative value, change to positive
    YDIST=YDIST*-1 if YDIST<0 else YDIST
    # calculate the number of rows using the pixel size
    ROWS=int(YDIST / pixel_size) - 1
    # calculate the YMAX based on number of columns to match with raster grid.
    YMAX=ymax_br - ROWS * pixel_size
    return YMAX

def adjust_ymin(ymax, ymin, pixel_size, keep_exact_rows=False):
    # distance between max and min in Y
    YDIST=ymax - ymin
    # if distance is negative value, change to positive
    YDIST=YDIST*-1 if YDIST<0 else YDIST
    # calculate the number of rows using the pixel size
    ROWS=int(YDIST / pixel_size) + 1 if not keep_exact_rows else int(YDIST / pixel_size)
    # calculate the YMIN based on number of columns to match with raster grid.
    YMIN=ymax - ROWS * pixel_size
    return YMIN

BBOX=os.getenv("BBOX", None)
BBOX_BR=os.getenv("BBOX_BR", "-73.98318215899995 -33.751035966999964 -28.847779358999958 5.269580833000035")
PIXEL_SIZE=os.getenv("PIXEL_SIZE", "0.0002689")

if BBOX is None:
    # BBOX BIOME (pampa)
    BBOX="-57.64957541999996 -33.75117799399993 -50.05266419299994 -27.46155951099996"

BBOX=BBOX.split(" ")
BBOX_BR=BBOX_BR.split(" ")
PIXEL_SIZE=float(PIXEL_SIZE)

"""
The reference coordinates
"""
# upper left
XMIN_BR=float(BBOX_BR[0])
YMAX_BR=float(BBOX_BR[3])

# we use it to adjust the BBOX of BR
## # lower right
## YMIN_BR=float(BBOX_BR[1])
## XMAX_BR=float(BBOX_BR[2])
## # only once to adjust the BBOX of BR
## XMAX_BR=adjust_xmax(xmax=XMAX_BR, xmin=XMIN_BR, pixel_size=PIXEL_SIZE, keep_exact_cols=True)
## YMIN_BR=adjust_ymin(ymax=YMAX_BR, ymin=YMIN_BR, pixel_size=PIXEL_SIZE, keep_exact_rows=True)
## print(f"{XMIN_BR} {YMIN_BR} {XMAX_BR} {YMAX_BR}")

"""
Adjust input coordinates
"""
# upper left
XMIN=float(BBOX[0])
YMAX=float(BBOX[3])
# coord to adjust
YMIN=float(BBOX[1])
XMAX=float(BBOX[2])

# first we must adjust the upper left based into reference upper left coordinate
XMIN=adjust_xmin(xmin_br=XMIN_BR, xmin=XMIN, pixel_size=PIXEL_SIZE)
YMAX=adjust_ymax(ymax_br=YMAX_BR, ymax=YMAX, pixel_size=PIXEL_SIZE)

# and then we must adjust the lower right reference coordinate
XMAX=adjust_xmax(xmax=XMAX, xmin=XMIN, pixel_size=PIXEL_SIZE)
YMIN=adjust_ymin(ymax=YMAX, ymin=YMIN, pixel_size=PIXEL_SIZE)

print(f"{XMIN} {YMIN} {XMAX} {YMAX}")
