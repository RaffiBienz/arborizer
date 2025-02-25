#------------------------------------------------------------------------------------------------------------------------#
#### Tree species recognition for Swisstopo ADS100 aerial imagery ####
# R.Bienz 05.11.2024
#------------------------------------------------------------------------------------------------------------------------#

#------------------------------------------------------------------------------------------------------------------------#
#### Configurations ####
# Set working directory and create necessary folders
wd <- file.path("")
setwd(wd)

dir.create(file.path(wd,"wd"), showWarnings = FALSE)
dir.create(file.path(wd,"temp"), showWarnings = FALSE)
dir.create(file.path(wd,"data"), showWarnings = FALSE)
dir.create(file.path(wd,"result"), showWarnings = FALSE)

#------------------------------------------------------------------------------------------------------------------------#
#### Load libraries ####
source("src/config.R")
source("src/create_fishnet.R")
source("src/mask_processing.R")
source("src/classify_trees.R")

terraOptions(tempdir = file.path(wd,"temp"),todisk = F)

#------------------------------------------------------------------------------------------------------------------------#
#### Prepare input data ####
source("src/preparations.R")

#------------------------------------------------------------------------------------------------------------------------#
#### Calculation ####
selected_wa_ids <- as.numeric(wa$Id)

## Clip orthofoto to fishnetcells ##
for (w in selected_wa_ids){
  if (file.exists(paste0("result_mask/",w,"/masks_bind_ba_",w,".shp"))){
    print(paste(w,"already existing"))
    next
  }
  fish_sel <- preparations(w, ortho_split)
  
  for (i in 1:nrow(fish_sel)){ 
    fl <- fish_sel[i,]
    
    if (ortho_split){
      clip_fishcells(w,fl,path_ortho, vhm,RGBI,ortho_split, ortho_df)
    } else {
      ortho <- rast(path_ortho)
      clip_fishcells(w,fl,path_ortho,vhm,RGBI, ortho_split, NULL)
    }
    cat("\r",i)
  }
  print("Pics exported")
}

## Create masks with instance segmentation ##
# Execute py script for instance segmentation:
print("Starting instance segmentation")
system(paste0('"', path_python, '" ', file.path(wd, "src/predict_masks_all_folders.py"), " ", wd),wait=T,invisible = F)
print("Instance segmentation (tree crown delination) completed")


## Read masks, georeference, aggregate, convert to polygon and export pictures of each tree ##
for (w in selected_wa_ids){
  if (file.exists(paste0("result/",w,"/masks_bind_ba_", w, ".shp"))){
    print(paste(w,"already existing"))
    next
  }
  
  ## Convert masks to polygons ##
  fish_sel <- preparations(w)
  mask_converter(path_masks, path_masks_geo, fish_sel)

  n_geo_files <- list.files(path_masks_geo)
  if (length(n_geo_files)<1){
    next
  }
  
  n_masks <- nrow(read_sf(paste0(path_masks_geo,"/mask_geo_combine_1.shp")))
  
  if (n_masks > 1){
    ## Combine masks ##
    mask_join(path_masks_geo)

    ## Clean overlaps ##
    clean_overlaps(path_masks_geo,1)

    ## Clean overlaps again ##
    clean_overlaps(path_masks_geo,2)
    
    ## Cut masks from orthophoto ##
    print("Start cutting masks from orthophoto")
    system.time({
    if (ortho_split){
      cut_ortho(path_masks_geo, path_tree_masks, NULL, path_ortho, RGBI,ortho_split,ortho_df)
    } else {
      cut_ortho(path_masks_geo, path_tree_masks, ortho, NULL, RGBI, ortho_split, NULL)}
    })

  } else {print(paste("No trees detected in",w))}
}


## Predict tree species per mask ##
# Execute python file for species classification
system(paste0('"', path_python, '" ', file.path(wd, "src/predict_ba_all_folders.py"), " ", wd),wait=T,invisible = F) ### separate python path

## Append tree species classification to shapefile
for (w in selected_wa_ids){
  if (file.exists(paste0("result/",w,"/masks_bind_ba_", w, ".shp"))){
    print(paste(w,"already existing"))
    next
  }
  fish_sel <- preparations(w)
  classify_trees(path_wa, path_masks_geo, path_tree_masks, w)
}

## Postprocessing ##
source("src/postprocessing.R")

## Remove temporary files ##
if (remove_tempfiles){
  for (w in selected_wa_ids){
    fish_sel <- preparations(w)
    unlink(path_pics, recursive=TRUE)
    unlink(path_masks, recursive=TRUE)
    unlink(path_masks_geo, recursive=TRUE)
    unlink(path_tree_masks, recursive=TRUE)
    print("Tempfiles removed")
  }
}


