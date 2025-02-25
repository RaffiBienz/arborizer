### R
# Set the working directory (wd) in main.R

# Load packages or install if they do not exist
source("src/install_packages.R")

### General setup
remove_tempfiles = TRUE # Should temporary files be removed?

### Python
# Install Python and requirements.txt
# Path to Python or Anaconda environment:
path_python = "python" # Path to python.exe or just "python" if defined as environment variable


### Vegetation height model (1x1m).
path_vhm = "data/VHM_example.tif"
vhm_height_threshold = 15


### Aerial imagery (RGBI, 10x10cm)
ortho_split = FALSE # is the orthophoto split in subtiles?
path_ortho = "data/ortho_example.tif" # Path to folder with tiles or path to single file
RGBI = FALSE # If orthophoto RGBI set TRUE. If orthophoto is IRGB set FALSE.


### Forest delination (best with a buffer of 10m).
path_forest_delination = "data/wa_example.shp"


















