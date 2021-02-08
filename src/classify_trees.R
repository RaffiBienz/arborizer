#------------------------------------------------------------------------------------------------------------------------#
#### Cut masks from orthophoto ####
#------------------------------------------------------------------------------------------------------------------------#
cut_ortho <- function(path_masks_geo, path_tree_masks, ortho, wd,RGBI,ortho_split,ortho_list){
  masks_bind_clean <- st_read(dsn=path_masks_geo,layer = "masks_bind_clean2",quiet = T,promote_to_multi=F)
  
  foreach (i = 1:nrow(masks_bind_clean), .packages = c("raster","sf","rgdal","rgeos","imager"),.combine = c, .verbose = F) %dopar% {
    rasterOptions(tmpdir= paste0(wd,"temp"),todisk=TRUE, progress="")
    mask <- masks_bind_clean[i,]
    
    if (!file.exists(paste0(path_tree_masks,"/ba_",mask$id,".png")) & st_area(mask)>0){
      if (extent(mask)[1]>2000000){
        
        if (ortho_split){
          ras_sel <- list()
          for (i in 1:length(ortho_list)){
            inter <- intersect(extent(mask),ortho_list[[i]])
            if (!is.null(inter))
              ras_sel <- append(ras_sel,crop(ortho_list[[i]],extent(mask)))}
          
          if (length(ras_sel)==0){
            print("Mask not overlapping orthophoto")
            break
          } else if (length(ras_sel)==1){
            ortho_ext <- ras_sel[[1]]
          } else if (extent(ras_sel[[1]])==extent(ras_sel[[2]])){
            ortho_ext <- ras_sel[[1]]
          } else if (length(ras_sel)>1){
            ras_sel$fun <- max
            ortho_ext <- do.call(mosaic, ras_sel)}
          
        } else {
          ortho_ext <- crop(ortho,mask[1,])
        }
        
        ortho_mask <- mask(ortho_ext,mask[1,])

        if (RGBI){
          cimg <- as.cimg(c(ortho_mask[][,4],ortho_mask[][,1],ortho_mask[][,2]),x=ncol(ortho_mask),y=nrow(ortho_mask),cc=3) # convert RGBI to IRG
        } else {cimg <- as.cimg(c(ortho_mask[][,1],ortho_mask[][,2],ortho_mask[][,3]),x=ncol(ortho_mask),y=nrow(ortho_mask),cc=3)} # convert IRGB to IRG
        
        cimg[is.na(cimg)] <- 0
        save.image(cimg, paste0(path_tree_masks,"/ba_",mask$id,".png"))
      }
    }
  }
  print("Cutting masks from orthophoto done")
}


#------------------------------------------------------------------------------------------------------------------------#
#### Predict tree species ####
#------------------------------------------------------------------------------------------------------------------------#
classify_trees <- function(path_python, path_wa, path_masks_geo, path_tree_masks, wa_id){

  if (file.exists(paste0(path_wa,"/masks_bind_ba_",wa_id,".shp"))){
    print("Trees already classified")
  
  } else {
    
    masks_bind_clean <- st_read(dsn=path_masks_geo,layer = "masks_bind_clean2",quiet = T,promote_to_multi=F)
    
    command <- paste0(path_python,"python.exe ", gsub("/", "\\\\", wd), "\\src\\predict_ba_for_wa_folder.py")
    system(paste(command, w, gsub("/", "\\\\", wd)),wait=T,invisible = F)
    
    pred_table <- read.table(paste0(path_tree_masks,"/","predictions.txt"), sep=" ")
    
    masks_bind_ba <- masks_bind_clean
    pred <- pred_table[match(masks_bind_ba$id, pred_table[,1]),2:3]
    
    table_ba <- data.frame(id=0:13,ba=c("ah","bu","do","ei","es","fi","fo","ki","la","li","rei","ta","ul","un"))
    pred_ba <- table_ba[match(pred[,1],table_ba[,1]),2]
    
    masks_bind_ba <- cbind(masks_bind_ba,pred_ba,round(pred[,2],2))
    
    st_write(masks_bind_ba, dsn=path_wa, layer = paste0("masks_bind_ba_",wa_id),driver = "ESRI Shapefile",  delete_layer = T)
    
    print("Tree species classified")
  }
}























