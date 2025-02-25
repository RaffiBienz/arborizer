#------------------------------------------------------------------------------------------------------------------------#
#### Create 30x30m fishnet for area of interest ####
#------------------------------------------------------------------------------------------------------------------------#
create_fishnet <- function(peri,resolution,dir){
  fishnet <- st_make_grid(peri, cellsize = 30)
  fishnet_in_peri <- st_intersects(fishnet,peri)
  
  not_forest <- c()
  for (i in 1:nrow(fishnet_in_peri)){
    if (identical(fishnet_in_peri[[i]], integer(0))){
      not_forest <- c(not_forest,i)
    }
  }

  fishnet_peri <- fishnet[-not_forest]
  fishnet_sf <- st_sf(geom=fishnet_peri)
  print("Cells in perimeter selected")
  fishnet_sf$ID <- 1:length(fishnet_peri)
  write_sf(fishnet_sf, paste0(dir,"/fishnet_", resolution,"m.shp"), delete_layer = T)
  print("Fishnet exported.")
}

#------------------------------------------------------------------------------------------------------------------------#
#### Clip orthofoto to cells of fishnet ####
#------------------------------------------------------------------------------------------------------------------------#
clip_fishcells <- function(wa_id,fl,location_ortho,vhm,RGBI,ortho_split,ortho_df){
  if (!file.exists(paste0("result/",wa_id, "/pics/pic_",fl$ID,".jpg"))){
    ext_fl <- terra::ext(fl)+10
    
    if (is.null(terra::intersect(ext_fl,terra::ext(vhm)))){
      print("Cell not overlapping vhm")
      
    } else {
      
      vhm_temp <- terra::crop(vhm, ext_fl,overwrite=T)
      
      if(sum(vhm_temp[],na.rm=T)>10 & dim(vhm_temp)[1]==dim(vhm_temp)[2] ){ #With areas higher than 10m (BH1)?
        
        if (ortho_split){
          res_025 <- FALSE
          
          within_y <- ext_fl[3] > ortho_df$y_min & ext_fl[4] < ortho_df$y_max
          
          ids_overlap_tot <- which(ext_fl[1] > ortho_df$x_min & ext_fl[2] < ortho_df$x_max &
                                     within_y)
          
          # Tiles with total overlap available
          if (length(ids_overlap_tot)>0){ # tiles with total overlap found
            if (length(ids_overlap_tot)==1){ # only one suitable ortho tile
              ortho_res <- as.numeric(ortho_df[ids_overlap_tot,]$resolution)
              ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[ids_overlap_tot,]$name_file))
              
              ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
              
              if (round(ortho_res,2)==0.1){ # check resolution
                ras <- ras_crop
              } else { # If resolution to low -> resample
                r <- rast(nrows=500, ncols=500, xmin=xmin(ras_crop), xmax=xmax(ras_crop), ymin=ymin(ras_crop), ymax=ymax(ras_crop))
                ras_resamp <- resample(ras_crop, r, overwrite=T)
                ras <- ras_resamp
                res_025 <- TRUE
              }
              
            } else { # multiple suitable ortho tiles
              ortho_res <- round(as.numeric(ortho_df[ids_overlap_tot,]$resolution),2)
              ids_highres <- which (ortho_res==0.1)
              
              if (length(ids_highres)>0){ # high res is available
                if (length(ids_highres)==1){ # only one high res available
                  ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[ids_overlap_tot[ids_highres],]$name_file))
                  ras <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                } else { # multiple high res available
                  # select best tile by y mean
                  ymean_fl <- (ext_fl[3]+ext_fl[4])/2
                  ymean_orthos <- (as.numeric(ortho_df[ids_overlap_tot[ids_highres],]$y_min) +
                                     as.numeric(ortho_df[ids_overlap_tot[ids_highres],]$y_max))/2
                  
                  y_diff <- abs(ymean_orthos-ymean_fl)
                  y_diff_sort <- order(y_diff, decreasing = F)
                  id_ortho_miny <- y_diff_sort[1]
                  
                  ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[ids_overlap_tot[ids_highres][id_ortho_miny],]$name_file))
                  ras <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                  
                  if (sum(ras[]==0, na.rm=T)>10000 & length(y_diff)>1){
                    id_ortho_miny <- y_diff_sort[2]
                    ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[ids_overlap_tot[ids_highres][id_ortho_miny],]$name_file))
                    ras <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                    
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

                ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[ids_overlap_tot[id_ortho_miny],]$name_file))
                ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                
                if (sum(ras_crop[]==0, na.rm=T)>10000 & length(y_diff)>1){
                  id_ortho_miny <- y_diff_sort[2]
                  ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[ids_overlap_tot[id_ortho_miny],]$name_file))
                  ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                }
                
                r <- rast(nrows=500, ncols=500, xmin=xmin(ras_crop), xmax=xmax(ras_crop), ymin=ymin(ras_crop), ymax=ymax(ras_crop))
                ras_resamp <- resample(ras_crop, r, overwrite=T)
                ras <- ras_resamp
                res_025 <- TRUE
              }
            }
            # no tiles with total overlap found, check for partial overlap
          } else { 
            ids_overlap_part <- which((ext_fl[1] < ortho_df$x_min & ext_fl[2]  > ortho_df$x_min & within_y) | 
                                        (ext_fl[1] < ortho_df$x_max & ext_fl[2] > ortho_df$x_max & within_y))
            
            if (length(ids_overlap_part)>1){ # more than one partial ovrlap?
              ortho_res <- round(as.numeric(ortho_df[ids_overlap_part,]$resolution),2)
              ids_highres <- which (ortho_res==0.1)
              
              if (length(ids_highres)>1){ # enough high res available
                ras_sel <- list()
                
                for (j in ids_overlap_part[ids_highres]){
                  ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[j,]$name_file))
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
                    ortho_sel <- rast(paste0(location_ortho, "/", ortho_df[j,]$name_file))
                    ras_crop <- terra::crop(ortho_sel, ext_fl,overwrite=T)
                    if (sum(ras_crop[]==0)<10000){
                      ras_sel[[length(ras_sel)+1]] <- ras_crop
                    }
                  }
                  
                  ras_sel_col <- sprc(ras_sel)
                  ras_mos_low <- mosaic(ras_sel_col, fun="first")
                  
                  r <- rast(nrows=500, ncols=500, xmin=xmin(ras_mos_low), xmax=xmax(ras_mos_low), ymin=ymin(ras_mos_low), ymax=ymax(ras_mos_low))
                  ras_mos <- resample(ras_mos_low, r, overwrite=T)

                  res_025 <- TRUE
                  
                } else {
                  ras <- matrix(c(1,2)) # asymetric ras -> stops further down
                  print("Not enough image data available.")}
              }
              
              if (nrow(ras_mos)==500 & ncol(ras_mos)==500){
                ras <- ras_mos
              } else {
                ras <- matrix(c(1,2))
                print("Cell not square.")
                }
              
            } else {
              ras <- matrix(c(1,2)) # asymetric ras -> stops further down
              print("Not enough image data available.")}
          }
       
        } else {
          if (is.null(terra::intersect(ext_fl,terra::ext(ortho)))){
            print("Cell not overlapping orthophoto or VHM")
            ras <- matrix(c(1,2)) # asymetric ras -> stops further down
          } else {
            ras <- terra::crop(ortho,ext_fl)
            #ras <- brick(ras)
            res_025 <- FALSE
          }
        }
        
        if (nrow(ras)==ncol(ras)){
          extent_ras <- ext(ras)
          vhm_temp_01 <- disagg(vhm_temp,10)
          ext(vhm_temp_01) <- extent_ras
          origin(vhm_temp_01) <- c(0,0)
          origin(ras) <- c(0,0)
          crs(vhm_temp_01) <- crs(ras)
          
          ras <- ras * vhm_temp_01 # cut out areas with height < 10m #120s
          
          if (RGBI){
            cimg <- as.cimg(c(ras[][,4],ras[][,1],ras[][,2]),x=ncol(ras),y=nrow(ras),cc=3) # convert RGBI to IRG
          } else {
            cimg <- as.cimg(c(ras[][,1],ras[][,2],ras[][,3]),x=ncol(ras),y=nrow(ras),cc=3)
          } # convert IRGB to IRG
          cimg[is.na(cimg)] <- 0
          save.image(cimg, paste0("result/",wa_id, "/pics/pic_",fl$ID,".jpg"))
          if (res_025){
            write(fl$ID,file=paste0("result/",wa_id, "/pics/pics_w_025res.txt"),append=TRUE)
          }
        } else {print("cell not square")}
      } else {print("vhm unplausible")}
    }
  }
}


















