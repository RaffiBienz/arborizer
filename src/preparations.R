#------------------------------------------------------------------------------------------------------------------------#
#### Tree species recognition - Preparations for the main calculations ####
# R.Bienz 05.11.2024
#------------------------------------------------------------------------------------------------------------------------#

#------------------------------------------------------------------------------------------------------------------------#
#### Function to setup paths and select fishnetcells ####
preparations <- function(w, ortho_split){
  ## Preparations ##
  print(paste0("Starting: ",w))
  fish_sel_id <- read.csv(paste0(path_ids, w, ".csv"))$x
  fish_sel <- fishnet[fish_sel_id,] # select areas for wa element
  print(paste0("Number of cells: ", nrow(fish_sel)))
  path_wa <<- file.path("result/",w)
  dir.create(path_wa, showWarnings = FALSE)
  path_pics <<- file.path("result/",w,"/pics")
  dir.create(path_pics, showWarnings = FALSE,recursive = T)
  path_masks <<- file.path("result/",w,"/masks")
  dir.create(path_masks, showWarnings = FALSE)
  path_masks_geo <<- file.path("result/",w,"/masks_geo")
  dir.create(path_masks_geo, showWarnings = FALSE)
  path_tree_masks <<- file.path("result/",w,"/tree_masks")
  dir.create(path_tree_masks, showWarnings = FALSE)
  
  return(fish_sel)  
  print("Preparations done")
  
}

#### Create fishnet of area of interest ####
path_fishnet <- "wd/fishnet_30m.shp"
if (!file.exists(path_fishnet)){
  perimeter <- read_sf(path_forest_delination)
  dir <- "wd"
  resolution <- 30 # Model was calibrated for this resolution
  create_fishnet(perimeter,resolution,dir)
}
fishnet <- read_sf(path_fishnet)

#### Create VHM with focal statistics ####
path_vhm_mask <- "wd/vhm_mask.tif"
if (!file.exists(path_vhm_mask)){
  vhm <- rast(path_vhm)
  recl <- matrix(c(-Inf, vhm_height_threshold, 0, vhm_height_threshold, Inf, 1), ncol = 3, byrow = T)
  vhm_recl <- classify(vhm, recl)
  vhm_foc <- terra::focal(vhm_recl,w=11,fun=mean) # Mean+reclassification is much faster than modal
  recl <- matrix(c(0,0.1,0,0.1,1,1),ncol=3, byrow=T)
  vhm_recl2 <- classify(vhm_foc, recl)
  writeRaster(vhm_recl2, path_vhm_mask, datatype='INT1U', overwrite=T)
}
vhm <- rast(path_vhm_mask)

#### Prepare forest delineation ####
path_fd_prep <- "wd/forest_delineation.shp"
if (!file.exists(path_fd_prep)){
  wa <- read_sf(path_forest_delination)
  wa <- wa[,!names(wa) %in% c("id", "Id", "ID")]
  wa <- wa[as.numeric(st_area(wa))>100,]
  wa$Id <- 1:nrow(wa)
  wa <- st_zm(wa) # drop Z dimension
  st_write(wa, path_fd_prep)
}
wa <- read_sf(path_fd_prep)

#### Create DF with orthophoto information ####
if (ortho_split){
  path_ortho_df <- "wd/ortho_df_bbox.csv"
  tiles <- list.files(path_ortho, pattern=".tif$", full.names = T)
  
  if (!file.exists(path_ortho_df) & ortho_split){
    ortho_df <- data.frame(id=numeric(), x_min=numeric(), x_max=numeric(),
                           y_min=numeric(), y_max=numeric(), resolution=numeric(), name_file = character())
    ras_extents <- vect()
    
    for(i in 1:length(tiles)) {
      ras <- rast(tiles[i])
      ras_ext <- terra::ext(ras)
    
      ras_reso <- res(ras)[1]
      ortho_df[i,] <- c(i, ras_ext[1], ras_ext[2], ras_ext[3], ras_ext[4], ras_reso,
                         basename(tiles[i]))
      p <- as.polygons(ras_ext)
      p$file <- tiles[i]
      p$x_min <- ras_ext[1]
      p$x_max <- ras_ext[2]
      p$y_min <- ras_ext[3]
      p$y_max <- ras_ext[4]
      p$resolution <- ras_reso
      ras_extents <- rbind(ras_extents,p)
      
      print(i)
    }
    write.csv2(ortho_df, path_ortho_df, row.names = F)
    writeVector(ras_extents, "wd/raster_extents_bbox.shp", overwrite=T)
    rm(ras, ras_ext)
    gc()
  }
  ortho_df <- read.csv2(path_ortho_df)
} else {
  ortho <- rast(path_ortho)
}


#### Create files with fishnet IDs per forest delineation element ####

path_ids <- "wd/ids_fishnet/"
dir.create(path_ids, showWarnings = FALSE)

for (w in as.numeric(wa$Id)){
  path_id_file <- paste0(path_ids, w, ".csv")
  if (!file.exists(path_id_file)){
    wa_sel <- wa[wa$Id==w,]
    fish_sel_list <- st_intersects(wa_sel,fishnet,returnList = T)
    fish_sel_id <- fish_sel_list[[1]]
    write.csv2(fish_sel_id, paste0(path_ids, w, ".csv"), row.names = F)
  }
  cat('\r',w)
}




