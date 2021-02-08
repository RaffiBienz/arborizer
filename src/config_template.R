### R
# Set the working directory (wd) in main.R

# Load packages or install if they do not exist
source("src/install_packages.R")

### General setup
number_of_cores = 7 # Number of cores used for certain calculations
remove_tempfiles = TRUE # Should temporary files be removed?


### Python
# Install Python and requirements.txt
# Path to Python or Anaconda environment:
path_python = file.path("C:/Python36/python.exe") # Path to python.exe or just "python" if defined as environment variable


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

















