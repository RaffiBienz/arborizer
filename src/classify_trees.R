#------------------------------------------------------------------------------------------------------------------------#
#### Cut masks from orthophoto ####
#------------------------------------------------------------------------------------------------------------------------#
cut_ortho <- function(path_masks_geo, path_tree_masks, ortho, path_ortho, RGBI, ortho_split, ortho_df){
  masks_bind_clean <- st_read(dsn=path_masks_geo,layer = "masks_bind_clean2",quiet = T,promote_to_multi=F)
  
  for(i in 1:nrow(masks_bind_clean)){
    mask <- masks_bind_clean[i,]
    if (sf::st_is_empty(mask)){
      next
    }
    ext_fl <- terra::ext(mask)
    crs_mask <- crs(mask)
    
    if (!file.exists(paste0(path_tree_masks,"/ba_",mask$id,".png")) & abs(ext_fl[1]-ext_fl[2])>0){
      if (ext_fl[1]>2000000){
        
        if (ortho_split){
          within_y <- ext_fl[3] > ortho_df$y_min & ext_fl[4] < ortho_df$y_max
          
          ids_overlap_tot <- which(ext_fl[1] > ortho_df$x_min & ext_fl[2] < ortho_df$x_max &
                                     within_y)
          
          # Tiles with total overlap available
          if (length(ids_overlap_tot)>0){ # tiles with total overlap found
            if (length(ids_overlap_tot)==1){ # only one suitable ortho tile
              ortho_res <- as.numeric(ortho_df[ids_overlap_tot,]$resolution)
              ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[ids_overlap_tot,]$name_file))
              
              ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)

              
              if (round(ortho_res,2)==0.1){ # check resolution
                ras <- terra::mask(ras_crop, mask)
              } else { # If resolution to low -> resample
                r <- rast(xmin=xmin(ras_crop), xmax=xmax(ras_crop), ymin=ymin(ras_crop), ymax=ymax(ras_crop), resolution=0.1)
                ras_resamp <- resample(ras_crop, r, overwrite=T)
                ras <- terra::mask(ras_resamp, mask)
              }
              
              
            } else { # multiple suitable ortho tiles
              ortho_res <- round(as.numeric(ortho_df[ids_overlap_tot,]$resolution),2)
              ids_highres <- which(ortho_res==0.1)
              
              if (length(ids_highres)>0){ # high res is available
                if (length(ids_highres)==1){ # only one high res available
                  ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[ids_overlap_tot[ids_highres],]$name_file))
                  ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                  ras <- terra::mask(ras_crop, mask)
                } else { # multiple high res available
                  # select best tile by y mean
                  ymean_fl <- (ext_fl[3]+ext_fl[4])/2
                  ymean_orthos <- (as.numeric(ortho_df[ids_overlap_tot[ids_highres],]$y_min) +
                                     as.numeric(ortho_df[ids_overlap_tot[ids_highres],]$y_max))/2
                  
                  y_diff <- abs(ymean_orthos-ymean_fl)
                  y_diff_sort <- order(y_diff, decreasing = F)
                  id_ortho_miny <- y_diff_sort[1]
                  
                  ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[ids_overlap_tot[ids_highres][id_ortho_miny],]$name_file))
                  ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                  ras <- terra::mask(ras_crop, mask)
                  
                  # Check for spectral integrity
                  if (sum(ras[]==0, na.rm=T)>10000 & length(y_diff)>1){
                    id_ortho_miny <- y_diff_sort[2]
                    ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[ids_overlap_tot[ids_highres][id_ortho_miny],]$name_file))
                    ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                    ras <- terra::mask(ras_crop, mask)
                    
                  }
                }
                
              } else { # no high res available, but multiple low res
                # select best tile by y mean
                ymean_fl <- (ext_fl[3]+ext_fl[4])/2
                ymean_orthos <- (as.numeric(ortho_df[ids_overlap_tot,]$y_min) +
                                   as.numeric(ortho_df[ids_overlap_tot,]$y_max))/2
                
                y_diff <- abs(ymean_orthos-ymean_fl)
                y_diff_sort <- order(y_diff, decreasing = F)
                id_ortho_miny <- y_diff_sort[1]
                
                ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[ids_overlap_tot[id_ortho_miny],]$name_file))
                ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                
                # Check for spectral integrity
                if (sum(ras_crop[]==0, na.rm=T)>10000 & length(y_diff)>1){
                  id_ortho_miny <- y_diff_sort[2]
                  ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[ids_overlap_tot[id_ortho_miny],]$name_file))
                  ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                }
                
                r <- rast(xmin=xmin(ras_crop), xmax=xmax(ras_crop), ymin=ymin(ras_crop), ymax=ymax(ras_crop), resolution=0.1)
                ras_resamp <- resample(ras_crop, r, overwrite=T)
                ras <- terra::mask(ras_resamp, mask)
              }
            }
            # no tiles with total overlap found, check for partial overlap
          } else { 
            ids_overlap_part <- which((ext_fl[1] < ortho_df$x_min & ext_fl[2]  > ortho_df$x_min & within_y) | 
                                        (ext_fl[1] < ortho_df$x_max & ext_fl[2] > ortho_df$x_max & within_y))
            
            if (length(ids_overlap_part)>1){ # more than one partial overlap?
              ortho_res <- round(as.numeric(ortho_df[ids_overlap_part,]$resolution),2)
              ids_highres <- which (ortho_res==0.1)
              
              if (length(ids_highres)>1){ # enough high res available
                ras_sel <- list()
                
                for (j in ids_overlap_part[ids_highres]){
                  ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[j,]$name_file))
                  ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                  if (sum(ras_crop[]==0, na.rm = T)<10000){
                    ras_sel[[length(ras_sel)+1]] <- ras_crop
                  }
                }
                
                ras_sel_col <- sprc(ras_sel)
                ras_mos <- mosaic(ras_sel_col, fun="first")
                
                
              } else { # not enough high res, try low res partial
                if (length(ids_overlap_part) - length(ids_highres)>1){ # enough low res tiles?
                  ras_sel <- list()
                  
                  if (length(ids_highres>0)){
                    ids_overlap_part <- ids_overlap_part[-ids_highres]
                  }
                  
                  for (j in ids_overlap_part){
                    ortho_sel <- rast(paste0(path_ortho, "/", ortho_df[j,]$name_file))
                    ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                    if (sum(ras_crop[]==0)<10000){
                      ras_sel[[length(ras_sel)+1]] <- ras_crop
                    }
                  }
                  
                  ras_sel_col <- sprc(ras_sel)
                  ras_mos_low <- mosaic(ras_sel_col, fun="first")
                  
                  r <- rast(xmin=xmin(ras_mos_low), xmax=xmax(ras_mos_low), ymin=ymin(ras_mos_low), ymax=ymax(ras_mos_low), resolution=0.1)
                  ras_resamp <- resample(ras_mos_low, r, overwrite=T)
                  ras_mos <- terra::mask(ras_resamp, mask)

                } else {
                  print("Not enough image data available.")
                  next
                  }
              }
              
              ras <- terra::mask(ras_mos, mask)

            } else {
              print("Not enough image data available.")
              next
              }
          }
        } else {
          ortho_ext <- terra::crop(ortho,mask)
          ras <- terra::mask(ortho_ext,mask)
        }
        
        if (RGBI){
          cimg <- as.cimg(c(ras[][,4],ras[][,1],ras[][,2]),x=ncol(ras),y=nrow(ras),cc=3) # convert RGBI to IRG
        } else {
          cimg <- as.cimg(c(ras[][,1],ras[][,2],ras[][,3]),x=ncol(ras),y=nrow(ras),cc=3)
        } # convert IRGB to IRG
        
        cimg[is.na(cimg)] <- 0
        save.image(cimg, paste0(path_tree_masks,"/ba_",mask$id,".png"))
      }
    }
  }
  print("Cutting masks from orthophoto done")
}

#------------------------------------------------------------------------------------------------------------------------#
#### Append species prediction to shapefile ####
#------------------------------------------------------------------------------------------------------------------------#
classify_trees <- function(path_wa, path_masks_geo, path_tree_masks, wa_id){
  if (file.exists(paste0(path_wa,"/masks_bind_ba_",wa_id,".shp"))){
    print("Trees already classified")
  } else {
    if (file.exists(paste0(path_masks_geo,"/masks_bind_clean2",".shp"))){
      masks_bind_clean <- st_read(dsn=path_masks_geo,layer = "masks_bind_clean2",quiet = T,promote_to_multi=F)
      pred_table <- read.table(paste0(path_tree_masks,"/","predictions.txt"), sep=" ")
      masks_bind_ba <- masks_bind_clean
      pred <- pred_table[match(masks_bind_ba$id, pred_table[,1]),2:3]
      
      table_ba <- data.frame(id=0:11,ba=c("ah","bu","ei","es","fe","fi","fo","la","ta","ul","un","vb"))
      pred_ba <- table_ba[match(pred[,1],table_ba[,1]),2]
      masks_bind_ba <- cbind(masks_bind_ba,pred_ba,round(pred[,2],2))
      st_write(masks_bind_ba, dsn=path_wa, layer = paste0("masks_bind_ba_",wa_id),driver = "ESRI Shapefile",  delete_layer = T)
      print("Tree species classified")
    }
  }
}






















