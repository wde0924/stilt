# script to plot dXCO2.anthro and dXCO2.bio, DW
# add xco2print map, 06/12/2017
# originate from 'OCO-2_proj/dxco2_xco2/ggplot2_dXCO2_xco2v2.r'
# use raster instead, DW, 06/19/2018

homedir <- '/uufs/chpc.utah.edu/common/home'
workdir <- file.path(homedir, 'lin-group5/wde/github/stilt')
plotdir <- file.path(workdir, 'plot')
setwd(workdir)
source(file.path(workdir, 'r/dependencies.r'))

####
cpTF <- F  # whether copy files
indx <- 1
site <- c(
  'Riyadh', 'Medina',  'Mecca', 'Cairo',   'Jerusalem',    # 1-5
  'PRD',    'Beijing', 'Xian',  'Lanzhou', 'Mumbai',       # 6-10
  'Indy',   'Phoenix', 'SLC',   'Denver',  'LA',           # 11-15
  'Seattle' )[indx]                                        # 16-more

stilt.ver <- 2  # for STILT version
nhrs.back <- c(-24, -36, -48, -72)[4]  # hours back for trajec
dpar      <- c(10, 50, 100)[3]  # number of particles per level
oco2.ver  <- c('b7rb', 'b8r')[1]  # for oco2 version
met       <- c('1km', 'gdas', 'gdas0p5')[3]
oco2.path <- file.path(homedir, 'lin-group5', 'wde', 'input_data', 'OCO-2', 'L2',
  paste0('OCO2_lite_', oco2.ver))

# lon.lat: minlon, maxlon, minlat, maxlat, city.lon, city.lat
site.info <- get.site.track(site, oco2.ver, oco2.path, workdir, searchTF = F,
  date.range = c('20140901', '20171231'), thred.per.count = 200, lon.lat = NULL,
  urbanTF = T, dlon = 0.5, dlat = 0.5)

lon.lat <- site.info$lon.lat
oco2.track <- site.info$oco2.track %>% filter(tot.urban.count > 200)
all.timestr <- oco2.track$timestr

### select which overpass to work with
tt <- 4
timestr <- all.timestr[tt]
cat(paste('Working on:', timestr, 'for city/region:', site, '...\n'))

### grab receptor info
### for STILT-R v2 ---------------
xco2.path <- file.path(workdir, 'plot/foot_emiss',
  paste0(abs(nhrs.back), 'hrs_back'), paste0(dpar, 'dpar'), site)
#xco2.path <- file.path(homedir, 'lin-group5/wde/STILT_output/OCO-2/')
print(xco2.path)

# read all file names
xco2.file <- list.files(path = xco2.path, pattern = as.character(timestr))
xco2.name <- gsub('_X_foot_emiss.nc', '', xco2.file)
recp.info <- data.frame(matrix(unlist(strsplit(xco2.name, '_')), byrow = T,
  ncol = 3), stringsAsFactors = F)
colnames(recp.info) <- c('timestr', 'recp.lon', 'recp.lat')

# order as lat increased
order.index <- order(recp.info$recp.lat)
recp.info <- recp.info[order.index , ]
xco2.file <- xco2.file[order.index ]
recp.lat <- as.numeric(recp.info$recp.lat)
recp.lon <- as.numeric(recp.info$recp.lon)
uni.timestr <- unique(recp.info$timestr)
print(uni.timestr)

# select receptors to plot
if (site == 'Riyadh') find.lat <- c(seq(24, 26, 0.3), 24.5444+0.01)
if (site == 'Phoenix') find.lat <- seq(31.9, 34, 0.2)
sel <- findInterval(find.lat, recp.lat)
sel.lat <- recp.lat[sel]
sel.lon <- recp.lon[sel]
sel.xco2.file <- xco2.file[sel]
print(sel.xco2.file)

## looping over track times
xco2.sig <- 1E-10
xco2.all <- NULL; xco2.count <- NULL

for (s in 1:length(sel)) {
  cat('Working on latitude', sel.lat[s], 'N...\n')
  xco2.dat <- raster(file.path(xco2.path, sel.xco2.file[s]))
  melt.xco2 <- raster::as.data.frame(x = xco2.dat, xy = T)
  colnames(melt.xco2) <- c('lon', 'lat', 'xco2')

  melt.xco2 <- melt.xco2 %>% filter(xco2 > xco2.sig)

  # storing
  xco2.all <- rbind(xco2.all, melt.xco2)
  xco2.count <- c(xco2.count, nrow(melt.xco2))
} # end for s
sel.xco2 <- xco2.all %>% mutate(fac = rep(sel.lat, xco2.count))
### end of XSTILTv2 ---------------


### for STILTv1 ---------------
v1TF <- T
if (v1TF) {
  xco2.path1 <- paste0(homedir, '/lin-group4/wde/STILT_output/OCO-2/NetCDF/',
    site, '/', met, '/multi_agl/akpw_foot_emiss/')
  xco2.file1 <- list.files(xco2.path1, 'foot_anthro')
  xco2.name1 <- substr(xco2.file1, 13, nchar(xco2.file1) - 4)
  recp.info1 <- ident.to.info(xco2.name1, aglTF = F)[[1]]

  # select receptors to plot
  sel.xco2.file1 <- xco2.file1[findInterval(sel.lat, recp.info1$recp.lat)]
  print(sel.xco2.file1)

  xco2.all1 <- NULL; xco2.count1 <- NULL; xco2.sig <- 1E-10

  for (s in 1:length(sel.xco2.file1)) {
    cat('Working on latitude', sel.lat[s], 'N...\n')

    xco2.dat1 <- nc_open(file.path(xco2.path1, sel.xco2.file1[s]))
    tmp.xco2 <- ncvar_get(xco2.dat1, 'foot_anthro')
    tmp.lat  <- ncvar_get(xco2.dat1, 'Lat')  # already centered lat, lon
    tmp.lon  <- ncvar_get(xco2.dat1, 'Lon')
    dimnames(tmp.xco2) <- list(tmp.lat, tmp.lon)

    # reshape
    melt.xco2 <- melt(t(tmp.xco2))
    colnames(melt.xco2) <- c('lon', 'lat', 'xco2')
    melt.xco2 <- melt.xco2 %>% filter(xco2 > xco2.sig)

    # storing
    xco2.all1 <- rbind(xco2.all1, melt.xco2)
    xco2.count1 <- c(xco2.count1, nrow(melt.xco2))

    nc_close(xco2.dat1)
  }
  sel.xco2.v1 <- xco2.all1 %>% mutate(fac = rep(sel.lat, xco2.count1))
  sel.xco2.v1$lat <- sel.xco2.v1$lat + 1/240
  sel.xco2.v1$lon <- sel.xco2.v1$lon + 1/240
}
### end of XSTILTv1 ---------------


#### plot xco2
if (met == '1km') met <- 'wrf'
facet.nrow <- 2
zoom <- 10

# load google map
mm <- ggplot.map(map = 'ggmap', center.lat = lon.lat[6],
  center.lon = lon.lat[5] + 0.1, zoom = zoom)
print(mm[[3]]) # shift in lon
print(mm[[2]])

#sel.xco2$xco2 <- as.numeric(formatC(sel.xco2$xco2, format = "e", digits = 4))
#sel.xco2.v1$xco2 <- as.numeric(formatC(sel.xco2.v1$xco2, format = "e", digits = 4))

source(file.path(workdir, 'r/dependencies.r'))

## for XSTILTv2
picname <- file.path(plotdir, paste0('xco2_', site, '_', uni.timestr, '_', met,
  '_STILTv2_zoom', zoom, '_', nhrs.back, 'hrs_', dpar, 'dpar.png'))
pp <- ggmap.xco2.obs(mm, lon.lat, site, facet.nrow, nhrs.back, dpar,
  stilt.ver = 2, timestr, font.size = rel(0.9), recp.lon = sel.lon,
  recp.lat = sel.lat, obs = obs, xco2 = sel.xco2[sel.xco2$fac == sel.lat[8],],
  picname, storeTF = T, width = 9, height = 10)

## for XSTILTv1
#if (v1TF) {
picname1 <- file.path(plotdir, paste0('xco2_', site, '_', uni.timestr, '_',
  met, '_STILTv1_zoom', zoom, '_72hrs_', dpar, 'dpar.png'))
pp1 <- ggmap.xco2.obs(mm, lon.lat, site, facet.nrow, nhrs.back = -72, dpar,
  stilt.ver = 1, timestr, font.size = rel(0.9), recp.lon = sel.lon,
  recp.lat = sel.lat, obs = obs, xco2 = sel.xco2.v1[sel.xco2.v1$fac == sel.lat[8],],
  picname1, storeTF = T, width = 9, height = 10)
#}



### subtract near-field influence from X-STILT v1
# it should include contribution from both faraway sources and beyond 1 day
if (v1TF) {
  #for (f in 1:length(sel.lat)) {
    f = 8
    # convert version 2 to raster
    raster.xco2 <- sel.xco2[sel.xco2$fac == sel.lat[f], ]
    coordinates(raster.xco2) <- ~lon + lat # create spatial point
    gridded(raster.xco2) <- TRUE  # coerce to SpatialPixelsDataFrame
    raster.xco2 <- raster(raster.xco2)  # coerce to raster
    crs(raster.xco2) <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

    # convert version 1 to raster, move lower left to center lat.lon
    raster.xco2.v1 <- sel.xco2.v1[sel.xco2.v1$fac == sel.lat[f], ]
    #raster.xco2.v1$lat <- raster.xco2.v1$lat + 1/240
    #raster.xco2.v1$lon <- raster.xco2.v1$lon + 1/240
    coordinates(raster.xco2.v1) <- ~lon + lat # create spatial point
    gridded(raster.xco2.v1) <- TRUE  # coerce to SpatialPixelsDataFrame
    raster.xco2.v1 <- raster(raster.xco2.v1)  # coerce to raster
    crs(raster.xco2.v1) <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

    # grab only nearfield for v1
    ext.r1 <- raster.xco2.v1
    ext.r2 <- raster.xco2
    diff.total <- sum(getValues(ext.r1), na.rm =T) - sum(getValues(ext.r2), na.rm =T)
    print(diff.total)

    nf.r1 <- crop(ext.r1, extent(ext.r2))
    nf.r2 <- crop(ext.r2, extent(nf.r1))
    diff.nf <- sum(getValues(nf.r1), na.rm =T) - sum(getValues(nf.r2), na.rm =T)
    print(diff.nf)

    hnf.r1 <- crop(nf.r1, extent(46, 48, 23.5, 26))
    hnf.r2 <- crop(nf.r2, extent(46, 48, 23.5, 26))
    diff.hnf <- sum(getValues(hnf.r1), na.rm =T) - sum(getValues(hnf.r2), na.rm =T)
    print(diff.hnf)

    nf.diff.xco2 <- overlay(x = nf.r1, y = nf.r2, fun = function(x, y){
        x[is.na(x[])] <- 0
        y[is.na(y[])] <- 0
        return(x - y)
      })  # xco2 beyond 2 days and near-field

    # extend domain and fill with NA to v2
    ext.r2 <- extend(ext.r2 , extent(ext.r1), value = NA)
    ext.r2 <- crop(ext.r2, extent(ext.r1))

    total.diff.xco2 <- overlay(x = ext.r1, y = ext.r2, fun = function(x, y){
        x[is.na(x[])] <- 0
        y[is.na(y[])] <- 0
        return(x - y)
      })  # xco2 beyond 2 days and near-field

    # convert back to df
    total.diff.xco2.df <- raster::as.data.frame(total.diff.xco2, xy = T) %>%
      filter(layer > 0)
    colnames(total.diff.xco2.df) <- c('lon', 'lat', 'xco2')
    total.diff.xco2.df$fac <- 'diff'

    # find out where is the diff
    zoom <- 10
    facet.nrow <- 1
    picname2 <- file.path(plotdir, paste0('xco2_', site, '_', uni.timestr, '_',
      met, '_diff_zoom', zoom, '_', dpar, 'dpar.png'))

    source(file.path(workdir, 'r/dependencies.r'))
    pp2 <- ggmap.xco2.obs(mm, lon.lat, site, facet.nrow,
      nhrs.back = '72 vs. 72', dpar, stilt.ver = 'v1 vs. v2', timestr,
      font.size = rel(0.9), recp.lon = sel.lon, recp.lat = sel.lat, obs = obs,
      xco2 = total.diff.xco2.df, picname2, storeTF = T, width = 8, height = 9)

    print(sel.lat[f])

  #}
}





# end of script
