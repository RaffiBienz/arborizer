#------------------------------------------------------------------------------------------------------------------------#
#### Create 30x30m fishnet for area of interest ####
#------------------------------------------------------------------------------------------------------------------------#
create_fishnet <- function(peri,resolution,dir){
  fishnet_ras <- raster()
  extent(fishnet_ras) <- extent(peri)
  res(fishnet_ras) <- resolution
  crs(fishnet_ras) <- crs(peri)
  print(paste("Fishnet raster created with",ncell(fishnet_ras),"cells."))

  # Convert and export as polygon
  fishnet <- rasterToPolygons(fishnet_ras)
  print("Fishnet converted to polygons")
  fishnet_in_peri <- over(fishnet,peri)
  fishnet_peri <- fishnet[!is.na(fishnet_in_peri[,1]),]
  print("Cells in perimeter selected")
  fishnet_peri@data <- data.frame(ID = 1:nrow(fishnet_peri))
  writeOGR(fishnet_peri,dsn = dir, layer = "fishnet_30m", driver = "ESRI Shapefile",overwrite = T)
  print("Fishnet exported as fishnet_30m.tif")
}


#------------------------------------------------------------------------------------------------------------------------#
#### Clip orthofoto to cells of fishnet ####
#------------------------------------------------------------------------------------------------------------------------#
clip_fishcells <- function(wa_id,fl,ortho,vhm,RGBI,ortho_split,ortho_list){
  if (!file.exists(paste0("result/",wa_id, "/pics/pic_",fl$ID,".jpg"))){
    ext <- extent(fl)+20

    if (is.null(intersect(ext,extent(vhm)))){
      print("Cell not overlapping vhm")
      
    } else {
      
      vhm_temp <- crop(vhm,ext)
      
      if(sum(vhm_temp[],na.rm=T)>10 & dim(vhm_temp)[1]==dim(vhm_temp)[2] ){ #With areas heigher than 21m (BH1)?
        
        if (ortho_split){
          ras_sel <- list()
          for (i in 1:length(ortho_list)){
            inter <- intersect(ext,ortho_list[[i]])
            if (!is.null(inter))
              ras_sel <- append(ras_sel,crop(ortho_list[[i]],ext))}
          
          if (length(ras_sel)==0){
            print("Cell not overlapping orthophoto")
            break
          } else if (length(ras_sel)==1){
            ras <- ras_sel[[1]]
          } else if (extent(ras_sel[[1]])==extent(ras_sel[[2]])){
            ras <- ras_sel[[1]]
          } else if (length(ras_sel)>1){
            ras_sel$fun <- max
            ras <- do.call(mosaic, ras_sel)}
          
        } else {
            if (is.null(intersect(ext,extent(ortho)))){
              print("Cell not overlapping orthophoto or VHM")
              break
            } else {ras <- crop(ortho,ext)}
          }
        
        
        if (nrow(ras)==ncol(ras)){
          vhm_temp_01 <- disaggregate(vhm_temp,10)
          extent(vhm_temp_01) <- extent(ras)
          origin(vhm_temp_01) <- c(0,0)
          origin(ras) <- c(0,0)
          
          ras <- ras * vhm_temp_01 # cut out areas with height < 21m
          
          if (RGBI){
            cimg <- as.cimg(c(ras[][,4],ras[][,1],ras[][,2]),x=ncol(ras),y=nrow(ras),cc=3) # convert RGBI to IRG
          } else {cimg <- as.cimg(c(ras[][,1],ras[][,2],ras[][,3]),x=ncol(ras),y=nrow(ras),cc=3)} # convert IRGB to IRG
          cimg[is.na(cimg)] <- 0
          save.image(cimg, paste0("result/",wa_id, "/pics/pic_",fl$ID,".jpg"))
        } else {print("cell not square")}
      }
    }
  }
}
























