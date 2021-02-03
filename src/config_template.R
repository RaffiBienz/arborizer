### R
# Set the working directory (wd) in main.R

# Load packages or install if they do not exist
if (!require("rgdal")) install.packages("rgdal")
if (!require("rgeos")) install.packages("rgeos")
if (!require("raster")) install.packages("raster")
if (!require("imager")) install.packages("imager")
if (!require("doParallel")) install.packages("doParallel")
if (!require("foreach")) install.packages("foreach")
if (!require("sf")) install.packages("sf")

number_of_cores = 7 # Number of cores used for certain calculations
remove_tempfiles = TRUE # Should temporary files be removed?


### Python
# Install Python 3.6.7 (https://www.python.org/ftp/python/3.6.7/python-3.6.7-amd64.exe)
# Install packages mxnet (1.5.0) and gluoncv (0.4.0)
# pip install mxnet==1.5.0
# pip install gluoncv==0.4.0
# If a suitable GPU is available, set ctx=[mx.gpu(0)] in predict_masks_folder.py for faster instance segmentation.
# If no suitable GPU is available, set ctx=[mx.cpu(0)]
# Path to Python or Anaconda environment:
path_python = "C:\\Python36\\" # With double backslash!




### Fishnet
# Create a new fishnet (TRUE) or use existing (FALSE)?
# If a existing fishned is used location_perimeter and name_perimeter must not be defined.
# If a new fishnet is created location_fishnet and name_fishnet must not be defined.
new_fishnet = FALSE
location_fishnet = "data"
name_fishnet = "fishnet_30m"

### Vegetation height model (1x1m). Areas > 21m = 1 / Areas < 21m = 0
location_vhm = "data/vhm_recl_foc10.tif"

### Aerial imagery (RGBI, 10x10cm)
ortho_split = F # is orthophoto split in subtiles?
location_ortho = "data/test_area.tif" # single tif file oder folder with subtiles
RGBI = FALSE # If orthophoto RGBI set TRUE. If orthophoto is IRGB set FALSE.

### Forest delination (best with a buffer of 10m). Attribute "Id" must be present.
location_forest_delination = "data"
name_forest_delination = "wa_test_area"

















