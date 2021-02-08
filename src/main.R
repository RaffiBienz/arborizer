#------------------------------------------------------------------------------------------------------------------------#
#### Tree species recognition for Swisstopo ADS100 aerial imagery ####
# R.Bienz 19.01.2021
#------------------------------------------------------------------------------------------------------------------------#


#------------------------------------------------------------------------------------------------------------------------#
#### Configurations ####
# Set working directory and create necessary folders
wd <- "C:/Auswertungen/baumarten_2019/src/arborizer/"
setwd(wd)
dir.create(paste0(wd,"wd"), showWarnings = FALSE)
dir.create(paste0(wd,"temp"), showWarnings = FALSE)
dir.create(paste0(wd,"data"), showWarnings = FALSE)
dir.create(paste0(wd,"result"), showWarnings = FALSE)


#------------------------------------------------------------------------------------------------------------------------#
#### Load libraries ####
source("src/config.R")
source("src/create_fishnet.R")
source("src/mask_processing.R")
source("src/classify_trees.R")

rasterOptions(tmpdir = paste0(wd,"/temp"),todisk = TRUE, progress = "")


#------------------------------------------------------------------------------------------------------------------------#
#### Create fishnet ####
if(new_fishnet){
  perimeter <- readOGR(dsn=location_forest_delination,layer = name_forest_delination,encoding = "ESRI Shapefile",stringsAsFactors = F)
  dir <- "data"
  resolution <- 30 # Model was calibrated for this resolution
  create_fishnet(perimeter,resolution,dir)
  location_fishnet <- dir
  name_fishnet <- "fishnet_30m"
}


#------------------------------------------------------------------------------------------------------------------------#
#### Load data ####
fishnet <- readOGR(dsn=location_fishnet,layer = name_fishnet,encoding = "ESRI Shapefile",stringsAsFactors = F)
vhm <- raster(location_vhm)
wa <- readOGR(dsn=location_forest_delination,layer = name_forest_delination,encoding = "ESRI Shapefile",stringsAsFactors = F)
crs(fishnet) <-  crs(wa)

if (ortho_split){
  tiles <- list.files(location_ortho, pattern=".tif$")
  ortho_list_tot <- list()
  for(i in 1:length(tiles)) {
    ortho_list_tot <- append(ortho_list_tot,brick(paste0(location_ortho,"/",tiles[i])))
  } 
  print("Ortho subtiles loaded")
} else{ortho <- brick(location_ortho)}




#------------------------------------------------------------------------------------------------------------------------#
#### Calculation ####
registerDoParallel(number_of_cores)
for (w in as.numeric(wa$Id)) {
  if (file.exists(paste0("result/",w,"/masks_bind_ba_",w,".shp"))){
    print(paste(w,"already existing"))
    next
  }
  ## Preparations ##
  print(paste0("Starting: ",w))
  wa_sel <- wa[wa$Id==w,]
  fish_sel_list <- over(wa_sel,fishnet,returnList = T)
  fish_sel_id <- fish_sel_list[[1]]$ID
  fish_sel <- fishnet[fishnet@data$ID %in% fish_sel_id,] # select areas for wa element
  print(paste0("Number of cells: ", nrow(fish_sel)))
  path_wa <- paste0("result/",w)
  dir.create(path_wa, showWarnings = FALSE)
  path_pics <- paste0("result/",w,"/pics")
  dir.create(path_pics, showWarnings = FALSE)
  path_masks <- paste0("result/",w,"/masks")
  dir.create(path_masks, showWarnings = FALSE)
  path_masks_geo <- paste0("result/",w,"/masks_geo")
  dir.create(path_masks_geo, showWarnings = FALSE)
  path_tree_masks <- paste0("result/",w,"/tree_masks")
  dir.create(path_tree_masks, showWarnings = FALSE)
  
  if (ortho_split){
    ortho_list <- list()
    for (i in 1:length(ortho_list_tot)){
      inter <- intersect(extent(fish_sel),ortho_list_tot[[i]])
      if (!is.null(inter))
        ortho_list <- append(ortho_list,ortho_list_tot[[i]])
    }
  }
  
  print("Preparations done")
  

  
  ## Clip ortho to fishcells ##
  foreach (i = 1:nrow(fish_sel), .packages = c("raster","rgdal","rgeos","imager")) %dopar% {
  #for (i in 1:nrow(fish_sel)){ # If warnings are desired, use for instead of foreach. But it's much slower.
    fl <- fish_sel[i,]
    if (ortho_split){
      clip_fishcells(w,fl,NULL,vhm,RGBI,ortho_split,ortho_list)
    } else {
      clip_fishcells(w,fl,ortho,vhm,RGBI, ortho_split, NULL)}
  }
  print("Pics exported")

  
  
  ## Create masks with instance segmentation ##
  # Execute py script for instance segmentation:
  print("Starting instance segmentation")
  command <- paste0(path_python,"python.exe ", gsub("/", "\\\\", wd), "\\src\\predict_masks_folder.py")
  system(paste(command, w, gsub("/", "\\\\", wd)),wait=T,invisible = T)
  print("Instance segmentation (tree crown delination) completed")
  
  
  ## Read masks, georeference, aggregate and convert to polygon ##
  mask_converter(path_masks, path_masks_geo, number_of_cores, fish_sel)
  
  n_masks <- length(list.files(path_masks))
  
  if (n_masks > 0){
    ## Combine masks ##
    mask_join(path_masks_geo)
    
  
    ## Clean overlaps ##
    clean_overlaps(path_masks_geo,1)
    
  
    ## Clean overlaps again ##
    clean_overlaps(path_masks_geo,2)
    
    
    ## Cut masks from orthophoto ##
    print("Start cutting masks from orthophoto")
    if (ortho_split){
      cut_ortho(path_masks_geo, path_tree_masks, NULL, wd, RGBI,ortho_split,ortho_list)
    } else {
      cut_ortho(path_masks_geo, path_tree_masks, ortho, wd, RGBI,ortho_split,NULL)}
  
    
    
    ## Predict tree species per mask ##
    print("Start tree species classification")
    classify_trees(path_python, path_wa, path_masks_geo, path_tree_masks, w)
    
  } else {print(paste("No trees detected in",w))}
    
  ## Remove temporary files ##
  if (remove_tempfiles){
    unlink(path_pics, recursive=TRUE)
    unlink(path_masks, recursive=TRUE)
    unlink(path_masks_geo, recursive=TRUE)
    unlink(path_tree_masks, recursive=TRUE)
    print("Tempfiles removed")
  }
  
  
  ## Clean global environment ##
  rm(path_wa, path_pics, path_masks, path_masks_geo, path_tree_masks, wa_sel, fish_sel, fish_sel_id, fish_sel_list, fl, pics, pics_done, fl_id, command)
  removeTmpFiles(h=0)
  gc()
  print(paste(w,"done"))
}
































