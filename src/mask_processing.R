#------------------------------------------------------------------------------------------------------------------------#
#### Read Masks, georeference, aggregate and convert to polygon ####
#------------------------------------------------------------------------------------------------------------------------#

mask_converter <- function(path_masks, path_masks_geo, number_of_cores, fish){
  if (file.exists(paste0(path_masks_geo,"/masks_bind.shp"))){
    print("Masks already existing and binded")
  } else {
    files <- list.files(path=path_masks,pattern = ".png$")
    files_geo <- list.files(path=path_masks_geo,pattern = ".shp$",recursive = T)
    if (length(files_geo)>0){
      files_geo_ids <- unlist(strsplit(unlist(strsplit(unlist(strsplit(files_geo,"/")),"mask_geo_")),".shp"))
      files_ids <- unlist(strsplit(substr(files,6,100),".png"))
      max_id <- max(which(files_ids %in% files_geo_ids))
      files <- files[(max_id+1):length(files)]
    }
    foldername <- 1 # Files are distributed to differnt folders -> writing & reading is faster
    counter <- 1
    step <- 1000 # After which a new folder is created
    
    dirs <- as.numeric(list.dirs(path_masks_geo,recursive = F,full.names = F))
    if (length(dirs)>0){
      foldername <- max(dirs)+step
    }
    
    print("start conversion to polygon")
    foreach (file = files, .packages = c("raster","sf","rgdal","rgeos")) %dopar% {
      mask_ras <- raster(paste0(path_masks,"/",file))
      
      mask_name <- unlist(strsplit(unlist(strsplit(file,".png")),"mask_"))[2]
      mask_id <- as.numeric(unlist(strsplit(unlist(strsplit(file,".png")),"_"))[2])
      
      dir.create(paste0(path_masks_geo,"/",foldername), showWarnings = FALSE)
      
      filename <- paste0(path_masks_geo,"/",foldername,"/mask_geo_",mask_name,".shp")
      
      if (!file.exists(filename)){
        mask_agg <- aggregate(mask_ras,10,max)
        if (max(mask_agg[])>0){
          mask_poly <- rasterToPolygons(mask_agg,dissolve = T,fun=function(x){x>0})
          mask_dis <- disaggregate(mask_poly)
          if (nrow(mask_dis)>1){
            mask_poly <- mask_dis[order(area(mask_dis),decreasing = T)[1],]
          } else {
            mask_poly <- mask_poly[1,]
          }
          
          
          pos <- fish[fish@data$ID==mask_id,]
          mask_poly@polygons[[1]]@Polygons[[1]]@coords[,1] <- mask_poly@polygons[[1]]@Polygons[[1]]@coords[,1]/10+xmin(pos)-10
          mask_poly@polygons[[1]]@Polygons[[1]]@coords[,2] <- mask_poly@polygons[[1]]@Polygons[[1]]@coords[,2]/10+ymin(pos)-10

          crs(pos) <- crs(mask_poly)
          tryCatch({
            mask_poly_pos <- crop(mask_poly,pos)
            if (!is.null(mask_poly_pos)){
              percentage_in_pos <- area(mask_poly_pos)/area(mask_poly)
              if(percentage_in_pos>0.3){
                
                mask_poly_st <- as(mask_poly,"sf")
                st_write(mask_poly_st,dsn=paste0(path_masks_geo,"/",foldername),layer = paste0("mask_geo_",mask_name),driver = "ESRI Shapefile",quiet = T)
                
              }
            }
            },error=function(e){})
          

        }
      }
      if (counter%%step==0){
        foldername <- foldername+step
      }
      counter <- counter+1

    }
    print("Masks georeferenced and converted to polygon")
  }
}

#------------------------------------------------------------------------------------------------------------------------#
#### Bind masks ####
#------------------------------------------------------------------------------------------------------------------------#

mask_join <- function(path_masks_geo){
  if (file.exists(paste0(path_masks_geo,"/masks_bind.shp"))){
    print("Masks already existing and binded")
  } else {
    folders <- list.dirs(path=path_masks_geo,recursive = F)
    
    for (fold in folders){
      if (!file.exists(paste0(fold,"/","masks_bind.shp"))){
        files <- list.files(path=fold,pattern = ".shp$",recursive = T)
        
        mask_name <- unlist(strsplit(unlist(strsplit(files[1],".shp")),"/")) # name of first mask
        masks_bind <- st_read(dsn=fold,layer = mask_name,quiet=T) # read first mask
        names(masks_bind) <- c("id","geometry")
        
        # first bind masks per folder
        for (file in files[-1]){
          mask_name <- unlist(strsplit(unlist(strsplit(file,".shp")),"/"))
          mask_new <- st_read(dsn=fold,layer = mask_name,quiet = T)
          #if (extent(mask_new)[1]<1000000 | extent(mask_new)[3]<1000000){
          #  next}
          names(mask_new) <- names(masks_bind)
          masks_bind <- rbind(masks_bind,mask_new)
        }
        masks_bind$id <- c(1:nrow(masks_bind))
        st_write(masks_bind,dsn=fold,layer = "masks_bind",driver = "ESRI Shapefile", quiet = T)
        
      }
    }
    
    # combine all files from all folders
    masks_bind <- st_read(dsn=folders[1],layer = "masks_bind",quiet=T)
    names(masks_bind) <- c("id","geometry")
    
    for (fold in folders[-1]){
      mask_new <- st_read(dsn=fold,layer = "masks_bind",quiet = T)
      names(mask_new) <- names(masks_bind)
      masks_bind <- rbind(masks_bind,mask_new)
    }
    
    masks_bind$id <- c(1:nrow(masks_bind))
    st_write(masks_bind,dsn=path_masks_geo,layer = "masks_bind",driver = "ESRI Shapefile", quiet = T)
    
    print("Polygons joined")
  }
}

#------------------------------------------------------------------------------------------------------------------------#
#### Clean overlaps ####
#------------------------------------------------------------------------------------------------------------------------#

clean_overlaps <- function(path_masks_geo, number_of_cleanup){
  
  if (file.exists(paste0(path_masks_geo,"/masks_bind_clean",number_of_cleanup,".shp"))){
    print(paste("Overlaps already cleaned",number_of_cleanup,"time(s)."))
  } else{
    
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
        a_tot <- st_area(agg_tot)
        sel_id_order <- sel_id[order(st_area(masks_bind[sel_id,]))]
        
        for (sub_id in sel_id_order[-length(sel_id_order)] ){
          a_tot <- st_area(agg_tot)
          smallest <- masks_bind[sub_id,]
          
          if (st_area(smallest)/a_tot > 0.6){ # If the smallest mask covers more than 60% of the aggregated mask, the aggregated mask is saved
            agg_tot <- st_sf(data.frame(id=sel_id[1],geometry=agg_tot$geometry))
            break
          } else{
            masks_bind_ok2 <- rbind(masks_bind_ok2,smallest) # If not, smallest is saved
            inter <- st_sf(data.frame(st_difference(agg_tot,smallest)))
            inter <- inter[1,1]
            inter_buf <- st_buffer(inter,-1)
            inter_buf2 <- st_buffer(inter_buf,1)
            inter_multy <- st_cast(inter_buf2, "POLYGON")
            agg_tot <- inter_multy[order(st_area(inter_multy),decreasing = T),][1,]
            
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















