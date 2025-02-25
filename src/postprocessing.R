#------------------------------------------------------------------------------------------------------------------------#
#### Tree species recognition for Swisstopo ADS100 aerial imagery - Postprocessing ####
# R.Bienz 05.11.2024
#------------------------------------------------------------------------------------------------------------------------#
dir.create("result/combined", showWarnings = F)

#------------------------------------------------------------------------------------------------------------------------#
#### Load data ####
vhm_high_res <- rast(path_vhm)

#------------------------------------------------------------------------------------------------------------------------#
#### Join all forest areas ####

path_combined <- "result/combined/masks_bind_ba.shp"
if (!file.exists(path_combined)){
  masks_bind <- NULL
  for (w in as.numeric(wa$Id)){
    path_wa <- file.path("result/",w)
    path_ba <- paste0(path_wa, "/masks_bind_ba_",w,".shp")
    if (file.exists(path_ba)){
      if (is.null(masks_bind)){
        masks_bind <- st_read(path_ba)
        masks_bind <- masks_bind[,c("id", "pred_ba", "r____2_", "geometry")]
      } else {
        masks_temp <- st_read (path_ba)
        masks_temp <- masks_temp[,c("id", "pred_ba", "r____2_", "geometry")]
        masks_bind <- rbind(masks_bind, masks_temp)
      }
      
    }
  }
  
  st_write(masks_bind, path_combined, append=F)
} else{
  masks_bind <- read_sf(path_combined)
}
print("All forest areas joined.")


#------------------------------------------------------------------------------------------------------------------------#
#### Calculate Tree height ####
# Remove false areas
path_valid <- "result/combined/masks_bind_ba_valid.shp"

if (!file.exists(path_valid)){
  area_bk <- as.numeric(st_area(masks_bind))
  id_area_invalid <- which(is.na(area_bk) | area_bk<=0)
  if (length(id_area_invalid)>0){
    masks_bind_valid <- masks_bind[-id_area_invalid,]
  } else {
    masks_bind_valid <- masks_bind
  }
  write_sf(masks_bind_valid, paste0(path_valid), overwrite=T)
} else {
  masks_bind_valid <- read_sf(path_valid)
}
print("Faulty geometries removed.")

# Calculate height per tree
path_heights <- "result/combined/masks_bind_ba_heights.shp"
if (!file.exists(path_heights)){
  q95 <- function(x){quantile(x,probs=0.95, na.rm=T)}
  
  for (i in seq(1,nrow(masks_bind_valid), by=100000)){
    ids <- i:min(i+99999, nrow(masks_bind_valid))
    bk_sel <- masks_bind_valid[ids,]
    heights <- terra::extract(vhm_high_res, bk_sel, fun=q95)
    masks_bind_valid[ids,"Height"] <- round(heights[,2],1)
    write_sf(masks_bind_valid, path_heights, overwrite=T)
    gc()
    cat("\r", i, "/", nrow(masks_bind_valid))
  }
} 

masks_bind_valid <- read_sf(path_heights)

print("Tree height calculated.")

# Calculate crown area
# Calculate height per tree
path_final_output <- "result/Tree_map.shp"
if (!file.exists(path_final_output)){
  cr_area <- st_area(masks_bind_valid)
  print("a")
  
  masks_bind_valid$Cr_area <- cr_area
  print(names(masks_bind_valid))
  
  names(masks_bind_valid) <- c("ID" ,"Tree_Species", "Confidence", "Height", "geometry", "Crown_area")
  print("c")
  write_sf(masks_bind_valid, path_final_output)
  print("d")
} 

masks_bind_valid <- read_sf(path_final_output)
print("Crown area calculated.")

#------------------------------------------------------------------------------------------------------------------------#
#### Rasterize results ####
path_raster <- "result/Tree_map.tif"
if (!file.exists(path_raster)){
  r <- rast(ext(masks_bind_valid), resolution=1)
  tree_ras <- terra::rasterize(masks_bind_valid, r, field="Tr_Spcs")
  crs(tree_ras) <- crs(masks_bind_valid)
  writeRaster(tree_ras, path_raster,datatype='INT1U', overwrite=T)    
}
print("Rasterized results.")

#------------------------------------------------------------------------------------------------------------------------#
#### Analysis ####
# Calculate proportion of each tree species

ba_tab <- table(masks_bind_valid$Tr_Spcs)
prop_stem <- round(ba_tab / sum(ba_tab)*100,1)


area_tot <- sum(masks_bind_valid$Crown_r)

prop_crown <- c()
for (ba in names(ba_tab)){
  ba_sel <- masks_bind_valid[masks_bind_valid$Tr_Spcs==ba,]
  area_ba <- sum(ba_sel$Crown_r)
  area_rel <- round(area_ba/area_tot*100,2)
  prop_crown <- c(prop_crown,area_rel)
}

print("Final results:")
results <- data.frame(Tree_species = names(ba_tab), Proportion_stem=as.numeric(prop_stem), Proportion_crown=prop_crown)
print(results)    
    
    