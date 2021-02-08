# Tree species segmentation and classification algorithm for SwissimageRS 2018 (Swisstopo)
Created by Raffael Bienz

The example orthophoto (test_area.tif) was kindly provided by Federal Office of Topography swisstopo (©swisstopo).

The other example data was kindly provided by the Kanton of Aargau.

## Algorithms
Two different neural networks are used: One for the segmentation of the tree crowns and one for the classification of the segmented crowns by tree species.

### Tree crown segmentation
- Model: resnet50_v1b pretrained on the coco dataset. 
- To train the model, for 260 plots tree crowns were manually segmented.

### Tree crown classification
- Model: mobilenet1.0 pretrained on ImageNet.
- To train the model, data of 3500 trees was collected in the field.
- The following groups of tree species are differentiated:
    - Ahorne (Acer spp.)
    - Buche (Fagus sylvatica)
    - Douglasie (Pseudotsuga menziesii)
    - Eichen (Querqus robur + petraea)
    - Gemeine Esche (Fraxinus excelsior)
    - Fichte (Picea abies)
    - Waldföhre (Pinus sylvestris)
    - Kirschen (Prunus avium + padus)
    - Lärche (Larix decidua)
    - Linden (Tilia cordata + platyphyllos)
    - Roteiche (Quercus rubra)
    - Tanne (Abies alba)
    - Übriges Laubholz
    - Übriges Nadelholz

## Usage

### Clone repository
```
git clone https://github.com/RaffiBienz/arborizer.git
git lfs install # if not already installed
git lfs pull # to download large files
```

### Setup Python
- Install Python or Anaconda
- Add the path to the python or an anaconda environment in config.R. If python is defined as a environment variable just type "pyhton" in config.R.
- Install packages mxnet (1.5.0) and gluoncv (0.4.0) -> see requirements.txt
- If a suitable GPU is available and the CUDA-environemnt is installed, instance segmentation should automatically use the GPU. Otherwise the CPU is used, which is much slower. If problems occur, set ctx=[mx.cpu(0)] in predict_masks_folder.py (line 13) manually.

**Example setup with Anaconda**

Open Anaconda Powershell Prompt and type:
```
conda create -y -n arborizer
conda activate arborizer
pip install -r .\requirements.txt
```
Add the path to the conda environment in config.R. Typically: C:/Users/USERNAME/.conda/envs/arborizer/python.exe

### Setup R
- Install R and if desired RStudio
- Required packages: rgdal, rgeos, raster, imager, doParallel, foreach, sf (see install_packages.R)
- These packages are automatically installed when main.R is run.

### Docker
Alternatively to the above setup you can also use the Dockerfile provided.

### Required data
- Swissiamge RS (10x10 cm / RGBI or IRGB / Federal Office of Topography swisstopo) with trees in leaf.
- Vegetation height model (1x1m / raster) where areas >= 21 m = 1 and areas < 21 m = 0 (model works only for tall trees, areas < 21 m are excluded from calculations).
- Forest delineation (shapefile)
- Fishnet of the area (30x30 m / shapefile). This can be generated with main.R based on the forest delineation (set new_fishnet = True in config.R)

### Execute script
- Open config_template.R, set variables (at least python_path) and save as config.R.
- Open main.R and set the working directory to arborizer folder.
- Run main.R (in a shell or via RStudio)

## Performance
Segmentation achieved a mean average precision of 33.4 on the validation dataset. Evergreen trees are not detected as well as deciduous trees. This may be due to the relatively small crowns of evergreen trees. Regaring deciduous trees, the algorithm has the tendency to conjoin the crowns of multiple trees.

Classification achieved an accuracy of 85 % on the validation dataset. However, the algorithm works better for evergreen trees than for deciduous trees.