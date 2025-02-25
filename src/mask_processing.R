#------------------------------------------------------------------------------------------------------------------------#
#### Read Masks, georeference, aggregate and convert to polygon ####
#------------------------------------------------------------------------------------------------------------------------#
mask_converter <- function(path_masks, path_masks_geo, fish){
  if (file.exists(paste0(path_masks_geo,"/masks_bind.shp"))){
    print("Masks already existing and binded")
  } else {
    files <- list.files(path=path_masks,pattern = ".png$")

    n_files <- length(files)
    
    if(n_files>0){
      step_seq <- 1000
      seq_files <- seq(1,n_files,step_seq)
      
      mask_ras <- terra::rast(paste0(path_masks,"/",files[1]))
      mask_agg <- terra::aggregate(mask_ras,10,max)
      mask_cutout <- mask_agg
      mask_cutout[] <- 0
      mask_cutout[11:40,11:40] <- 1
      
      print("start conversion to polygon")
      for (s in seq_files) {
        mask_polygon_list <- sf::st_sf(sf::st_sfc(), crs=sf::st_crs("EPSG:2056"))
        name_output <-  paste0("mask_geo_combine_",s)
        if (!file.exists(paste0(path_masks_geo, "/", name_output, ".shp"))){
          files_sel <- files[s:min((s+step_seq-1),n_files)]
          for (file in files_sel){
            mask_id <- as.numeric(unlist(strsplit(unlist(strsplit(file,".png")),"_"))[2])
            mask_ras <- terra::rast(paste0(path_masks,"/",file))#
            
            if (TRUE){
              mask_agg <- terra::aggregate(mask_ras,10,max)
              mask_agg_inner <- mask_agg * mask_cutout
              sum_maks_inner <- sum(terra::values(mask_agg_inner))
              sum_maks_tot <- sum(terra::values(mask_agg))
              
              percentage_in_pos <- sum_maks_inner/max(sum_maks_tot,1)
      
              if (percentage_in_pos>0.3){
                mask_poly <- terra::as.polygons(mask_agg)#
                mask_dis <- terra::disagg(mask_poly)
                mask_sf <- sf::st_as_sf(mask_dis)#
                mask_sf <- mask_sf[mask_sf[[1]]>0,]
      
                if (nrow(mask_sf)>1){
                  mask_poly <- mask_sf[order(sf::st_area(mask_sf),decreasing = T)[1],]
                } else {
                  mask_poly <- mask_sf[1,]
                }
                
                mask_poly <- sfheaders::sf_remove_holes(mask_poly)
                
                pos <- fish[fish$ID==mask_id,]
                coords <- sf::st_coordinates(mask_poly)
                coords[,1] <- coords[,1]/10+sf::st_bbox(pos)$xmin-10
                coords[,2] <- coords[,2]/10+sf::st_bbox(pos)$ymin-10
                
                mask_georef <- sf::st_sfc(sf::st_polygon(list(coords[,1:2])))
                
                sf::st_crs(mask_georef) <- sf::st_crs(pos)
                tryCatch({
                  mask_poly_pos <- sf::st_crop(mask_georef,pos)#
                  mask_poly_sf <- sf::st_sf(mask_georef)
                  mask_poly_sf$fishnet_id <- mask_id
                  
                  if (!is.null(mask_poly_pos)){
                      mask_polygon_list <- rbind(mask_polygon_list, mask_poly_sf)
                      
                  }
                },error=function(e){})
              }
            }
          }
          sf::st_write(mask_polygon_list,dsn=paste0(path_masks_geo),layer = name_output,driver = "ESRI Shapefile",quiet = T)
        }
      }
    }
  }
}


#------------------------------------------------------------------------------------------------------------------------#
#### Join masks ####
#------------------------------------------------------------------------------------------------------------------------#
mask_join <- function(path_masks_geo){
  if (file.exists(paste0(path_masks_geo,"/masks_bind.shp"))){
    print("Masks already existing and binded")
  } else {
    
    files <- list.files(path=path_masks_geo,pattern = ".shp$",recursive = T)
    if (length(files) > 0){
      mask_name <- unlist(strsplit(unlist(strsplit(files[1],".shp")),"/")) # name of first mask
      masks_bind <- st_read(dsn=path_masks_geo,layer = mask_name,quiet=T) # read first mask
      if (nrow(masks_bind)>0){
        names(masks_bind) <- c("fishnet_id","geometry")
        
        # first bind masks per folder
        for (file in files[-1]){
          mask_name <- unlist(strsplit(unlist(strsplit(file,".shp")),"/"))
          mask_new <- st_read(dsn=path_masks_geo,layer = mask_name,quiet = T)
          
          if (nrow(mask_new)>0){
            names(mask_new) <- names(masks_bind)
            masks_bind <- rbind(masks_bind,mask_new)
          }
        }
        masks_bind$id <- c(1:nrow(masks_bind))
        st_write(masks_bind,dsn=path_masks_geo,layer = "masks_bind",driver = "ESRI Shapefile", quiet = T, overwrite=T)
      }
    } 
    print("Polygons joined")
  }
}


#------------------------------------------------------------------------------------------------------------------------#
#### Clean overlaps ####
#------------------------------------------------------------------------------------------------------------------------#

clean_overlaps <- function(path_masks_geo, number_of_cleanup){
  
  if (file.exists(paste0(path_masks_geo,"/masks_bind_clean",number_of_cleanup,".shp"))){
    print(paste("Overlaps already cleaned",number_of_cleanup,"time(s)."))
  } else if (file.exists(paste0(path_masks_geo,"/masks_bind.shp"))){
    
    if (number_of_cleanup == 1){
      masks_bind <- st_read(dsn=path_masks_geo,layer = "masks_bind",quiet = T,promote_to_multi=F)
    } else {
      masks_bind <- st_read(dsn=path_masks_geo,layer = paste0("masks_bind_clean",number_of_cleanup-1),quiet = T,promote_to_multi=F)
    }
    
    mask_buf <- st_buffer(masks_bind,-2)
    mask_over <- st_intersects(mask_buf,mask_buf)
    
    bol_over <- unlist(lapply(mask_over,function(x){length(x) >1 })) # Masks which overlap more than 2m with other masks.
    masks_bind_ok <- masks_bind[!bol_over,] # Masks which do not overlap are ok
    masks_bind_ok2 <- masks_bind_ok[0,]
    done <- masks_bind_ok$id
    stand_alt <- 0 # For progress output
    
    ids_to_do <- masks_bind$id[order(st_area(masks_bind),decreasing = T)] # Order masks by size
    ids_to_do <- ids_to_do[!ids_to_do %in% done]
    
    for (i in ids_to_do){
      sel_id <- mask_over[][[i]]
      sel_id <- sel_id[!sel_id %in% done]
      
      if (length(sel_id)>1){
        agg_tot <- st_sf(data.frame(st_union(masks_bind[sel_id,]))) # Overlapping masks are aggregated
        a_tot <- as.numeric(st_area(agg_tot))
        sel_id_order <- sel_id[order(st_area(masks_bind[sel_id,]))]
        
        for (sub_id in sel_id_order[-length(sel_id_order)] ){
          a_tot <- as.numeric(st_area(agg_tot))
          smallest <- masks_bind[sub_id,]
          fishnet_ids <- unique(masks_bind[sel_id,]$fishnet_id)
          
          if (as.numeric(st_area(smallest))/a_tot > 0.6){ # If the smallest mask covers more than 60% of the aggregated mask, the aggregated mask is saved
            fishnet_ids <- unique(masks_bind[sel_id,]$fishnet_id)
            agg_tot <- st_sf(data.frame(id=sel_id[1], fishnet_id=paste(fishnet_ids, collapse = ","),geometry=agg_tot$geometry))
            break
          } else{
            masks_bind_ok2 <- rbind(masks_bind_ok2,smallest) # If not, smallest is saved
            inter <- st_sf(data.frame(st_difference(agg_tot,smallest)))
            inter <- inter[1,1]
            inter_buf <- st_buffer(inter,-1)
            inter_buf2 <- st_buffer(inter_buf,1)
            inter_multy <- st_cast(inter_buf2, "POLYGON")
            agg_tot <- inter_multy[order(st_area(inter_multy),decreasing = T),][1,]
            agg_tot$fishnet_id <- paste(fishnet_ids, collapse = ",") 
            agg_tot$id <- masks_bind[sel_id,]$id[1]
          }
        }
        masks_bind_ok2 <- rbind(masks_bind_ok2,agg_tot) # Aggregated mask - smallest mask is saved
      }
      
      if (length(sel_id)==1){
        masks_bind_ok2 <- rbind(masks_bind_ok2,masks_bind[sel_id,])
      }
      
      done <- c(done,sel_id)
      stand <- round(length(done)/length(masks_bind$id)*10)
      if (stand>stand_alt){
        print(paste(stand*10,"% done"))
        stand_alt <- stand
      }
      
    }
    masks_bind_ok3 <- rbind(masks_bind_ok,masks_bind_ok2)
    masks_bind_ok3$id <- 1:length(masks_bind_ok3$id)
    st_write(masks_bind_ok3,dsn=path_masks_geo,layer = paste0("masks_bind_clean",number_of_cleanup),driver = "ESRI Shapefile", quiet = T)
    print(paste("Overlaps cleaned",number_of_cleanup,"time(s)."))
  }
}















