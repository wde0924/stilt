# script to plot spatial footprint, DW
# add footprint map, 06/12/2017

homedir <- '/uufs/chpc.utah.edu/common/home'
plotdir <- file.path(homedir, 'lin-group5/wde/github/plot')
source('r/dependencies.r')

####
site      <- 'Riyadh'
stilt.ver <- 2  # for STILT version
dmassTF   <- F  # if using STILTv1
nhrs      <- c(-12, -24, -36, -48, -72)[2]  # hours back for trajec
dpar      <- c(10, 50, 100, 2500)[3]        # number of particles per level
sf        <- c(0, 1, 2)[2]                  # smooth factor for footprints
ziscale   <- c(NULL, 0.8, 1.0, 1.2)[2]      # prescibed zi scaling
foot.str  <- c('sf0', 'sf1', 'sf2', 'trajecfoot', 'trajecfoot_dmassF')[2]

oco2.ver  <- c('b7rb', 'b8r')[1]  # for oco2 version
oco2.path <- file.path(homedir, 'lin-group5/wde/input_data/OCO-2/L2',
  paste0('OCO2_lite_', oco2.ver))

# lon.lat: minlon, maxlon, minlat, maxlat, city.lon, city.lat
output.path <-file.path(homedir, 'lin-group5/wde/github/result')
txtpath <- file.path(output.path, 'oco2_overpass')

site.info <- get.site.track(site, oco2.ver, oco2.path, searchTF = F,
  date.range = c('20140901', '20171231'), thred.count.per.deg = 200,
  lon.lat = get.lon.lat(site), urbanTF = T, dlon.urban = 0.5, dlat.urban = 0.5,
  thred.count.per.deg.urban = 100, txtpath = txtpath)

lon.lat <- site.info$lon.lat
oco2.track  <- site.info$oco2.track %>% filter(tot.urban.count > 200 &
  qf.urban.count > 80)
all.timestr <- oco2.track$timestr
print(all.timestr)

### select which overpass to work with
tt <- 3
timestr <- all.timestr[tt]
cat(paste('Working on:', timestr, 'for city/region:', site, '...\n'))

### grab footprints info, for STILT-R v2:
# always copy trajec and footprints to another directory
# if cpTF == T, copy all files from out to plot directory
# if not, simply return the paths
#cpTF <- F  # whether copy files
#foot.path <- cp.xfiles(workdir, v = 1, nhrs, dpar, site, cpTF)
#traj.path <- cp.xfiles(workdir, v = 2, nhrs, dpar, site, cpTF)
#wgttraj.path <- cp.xfiles(workdir, v = 3, nhrs, dpar, site, cpTF)

### read footprint files
if (dpar == 2500) {
  workdir <- file.path(homedir, 'lin-group5/wde/github/cp_test')
  foot.path <- file.path(workdir, paste0('out_', timestr, '_', dpar, 'dpar'),
    'by-id')
  foot.file <- file.path(foot.path,
    list.files(path = foot.path, pattern = 'foot.nc', recursive = T))
  foot.path <- dirname(foot.file)
  foot.file <- basename(foot.file)

} else {
  #workdir <- file.path(homedir, 'lin-group5/wde/github/cp_trajecfoot')
  #foot.path <- file.path(workdir, 'out', paste0('footprints_', foot.str))
  #foot.path <- file.path(workdir, paste0('out_', timestr, '_', dpar, 'dpar'),
  #  paste0('footprints_', foot.str))

  foot.path <- file.path(homedir, 'lin-group5/wde/github/stilt/ziscale_test/')
  foot.file <- list.files(path = foot.path, pattern = 'foot.nc', recursive = T)[-4]
}

foot.name <- gsub('_X_foot.nc', '', basename(foot.file))
recp.info <- data.frame(matrix(unlist(strsplit(foot.name, '_')), byrow = T,
  ncol = 3), stringsAsFactors = F)
colnames(recp.info) <- c('timestr', 'recp.lon', 'recp.lat')

# order by increasing lat
foot.file <- file.path(foot.path, foot.file)
order.index <- order(recp.info$recp.lat)
recp.info <- recp.info[order.index, ]
foot.file <- foot.file[order.index]
recp.lat <- as.numeric(recp.info$recp.lat)
recp.lon <- as.numeric(recp.info$recp.lon)
uni.timestr <- unique(recp.info$timestr)
print(uni.timestr)

selTF <- F
if (selTF) {
  # select receptors to plot
  #if (site == 'Riyadh' & tt == ) find.lat <- seq(23.4, 24.7, 0.15)
  if (site == 'Riyadh' & tt == 3) find.lat <- seq(24.3, 25.0, 0.1)
  #if (site == 'Riyadh') find.lat <- seq(25, 26, 0.15)
  if (site == 'Baghdad') find.lat <- seq(32, 34, 0.2)

  sel <- findInterval(find.lat, recp.lat)
} else {
  sel <- 1:length(foot.file)
}

sel.lat <- recp.lat[sel]
sel.lon <- recp.lon[sel]
sel.foot.file <- foot.file[sel]
print(basename(sel.foot.file))

## looping over track times
foot.sig   <- 1E-6
foot.all  <- NULL; foot.count <- NULL

for (s in 1:length(sel.foot.file)) {
#s = 3
  cat('Working on file:', sel.foot.file[s], '...\n')
  source('r/dependencies.r')
  melt.foot <- grab.foot(stilt.ver = 2, footfile = sel.foot.file[s],
    foot.sig = foot.sig, lon.lat = NULL)

  # compare two foots
  if (F) {
    if (foot.str == 'sf0' & dpar == 2500) foot.bf <- melt.foot
    if (foot.str == 'trajecfoot' & dpar == 100) foot.tf <- melt.foot

    # calculate the diff
    library(tidyr)
    merge.foot <- full_join(foot.bf, foot.tf, by = c('lon', 'lat')) %>%
      dplyr::select('lon' = 'lon', 'lat' = 'lat', 'bf' = 'foot.x',
        'tf' = 'foot.y') %>% replace_na(list(bf = 0, tf = 0)) %>%
      mutate(foot = tf - bf)
    merge.foot$fac <- sel.lat[s]

    picname <- file.path(plotdir, 'xfoot',
      paste0('diff_xfoot_', site, '_', uni.timestr, '_', met, '_STILTv2_zoom',
        zoom, '_', nhrs, 'hrs_', dpar, 'dpar_', foot.str, '.png'))

    d1 <- ggmap.xfoot.obs(mm = mm, lon.lat = lon.lat, site = site,
        oco2.path = oco2.path, facet.nrow = 1, facet.ncol = 1, nhrs = nhrs,
        dpar = dpar, stilt.ver = 'diff', foot.str = 'diff.foot', timestr = timestr,
        font.size = rel(0.7), recp.lon = sel.lon[s], recp.lat = sel.lat[s],
        foot = merge.foot, picname = picname, storeTF = T, width = 6, height = 6)
  }

  # storing
  foot.all   <- rbind(foot.all, melt.foot)
  foot.count <- c(foot.count, nrow(melt.foot))
} # end for s

#sel.foot <- foot.all %>% mutate(fac = rep(sel.lat, foot.count))
sel.foot <- foot.all %>% mutate(fac = rep(c(0.8, 1.0, 1.2), foot.count))


#### plot footprint
if (met == '1km') met <- 'wrf'

# load google map
zoom <- 7
mm <- ggplot.map(map = 'ggmap', center.lat = lon.lat[6],
  center.lon = lon.lat[5] + 0.1, zoom = zoom)

source('r/dependencies.r')
picname <- file.path(plotdir, 'xfoot',
  paste0('xfoot_', site, '_', uni.timestr, '_', met, '_STILTv', stilt.ver,
    '_zoom', zoom, '_', nhrs, 'hrs_', dpar, 'dpar_', foot.str, '_ziscale.png'))

pp1 <- ggmap.xfoot.obs(mm = mm, lon.lat = lon.lat, site = site,
  oco2.path = oco2.path, facet.nrow = 1, facet.ncol = 3, nhrs = nhrs,
  dpar = dpar, stilt.ver = 2, foot.str = foot.str, timestr = timestr,
  font.size = rel(1.2), recp.lon = sel.lon, recp.lat = sel.lat,
  foot = sel.foot, picname = picname, storeTF = T, width = 16, height = 7)




### for original STILT
v1TF <- F
if (v1TF) {
  foot.path <- paste0(homedir, '/lin-group4/wde/STILT_output/OCO-2/NetCDF/',
    site, '/', met, '/multi_agl/akpw_intfoot/', timestr, '/')
  foot.file <- list.files(foot.path, 'foot')
  foot.name <- substr(foot.file, 8, nchar(foot.file) - 4)
  recp.info <- ident.to.info(foot.name, aglTF = F)[[1]]
  recp.lat <- recp.info$recp.lat
  recp.lon <- recp.info$recp.lon

  # select receptors to plot
  #find.lat <- seq(33, 34, 0.2)
  if (site == 'Riyadh') find.lat <- c(seq(24, 26, 0.3), 24.5444+0.01)
  sel <- findInterval(find.lat, recp.lat)
  sel.lat <- recp.lat[sel]
  sel.lon <- recp.lon[sel]
  sel.foot.file <- foot.file[sel]

  ## looping over track times
  foot.sig   <- 1E-10
  melt.foot  <- NULL; foot.count <- NULL

  for (s in 1:length(sel)) {

    cat('Working on latitude', sel.lat[s], 'N...\n')
    foot.dat <- nc_open(file.path(foot.path, sel.foot.file[s]))

    tmp.foot <- ncvar_get(foot.dat, 'footprint')
    tmp.lat  <- ncvar_get(foot.dat, 'Lat')  # already centered lat, lon
    tmp.lon  <- ncvar_get(foot.dat, 'Lon')
    dimnames(tmp.foot) <- list(tmp.lat, tmp.lon)
    tmp.foot <- t(tmp.foot)
    melt.tmp.foot <- melt(tmp.foot)
    nc_close(foot.dat)

    # reshape foot
    colnames(melt.tmp.foot) <- c('lon', 'lat', 'foot')
    melt.tmp.foot <- melt.tmp.foot %>% filter(foot > foot.sig)

    # storing
    melt.foot <- rbind(melt.foot, melt.tmp.foot)
    foot.count<- c(foot.count, nrow(melt.tmp.foot))
  } # end for s

  sel.foot1 <- melt.foot %>% mutate(fac = rep(sel.lat, foot.count)) #%>%

  # fix lat lon from lower left to center lat lon
  sel.foot1$lat <- sel.foot1$lat + 1/240
  sel.foot1$lon <- sel.foot1$lon + 1/240

  picname <- file.path(plotdir, paste0('xfoot_', site, '_', uni.timestr, '_', met,
    '_STILTv1_zoom', zoom, '_', nhrs, 'hrs_', dpar, 'dpar.png'))
  pp2 <- ggmap.xfoot.obs(mm, lon.lat, site, facet.nrow, nhrs, dpar,
    stilt.ver = 1, timestr, font.size = rel(0.9), recp.lon = sel.lon,
    recp.lat = sel.lat, obs = obs, foot = sel.foot1[sel.foot1$fac == sel.lat[8],],
    picname, storeTF = T, width = 9, height = 10)

  ### subtract near-field influence from X-STILT v1
  # it should include contribution from both faraway sources and beyond 1 day

  #for (f in 1:length(sel.lat)) {
    f = 8
    # convert version 2 to raster
    raster.foot <- sel.foot[sel.foot$fac == sel.lat[f], ]
    coordinates(raster.foot) <- ~lon + lat # create spatial point
    gridded(raster.foot) <- TRUE  # coerce to SpatialPixelsDataFrame
    raster.foot <- raster(raster.foot)  # coerce to raster
    crs(raster.foot) <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

    # convert version 1 to raster, move lower left to center lat.lon
    raster.foot1 <- sel.foot1[sel.foot1$fac == sel.lat[f], ]
    #raster.foot1$lat <- raster.foot1$lat + 1/240
    #raster.foot1$lon <- raster.foot1$lon + 1/240
    coordinates(raster.foot1) <- ~lon + lat # create spatial point
    gridded(raster.foot1) <- TRUE  # coerce to SpatialPixelsDataFrame
    raster.foot1 <- raster(raster.foot1)  # coerce to raster
    crs(raster.foot1) <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

    # grab only nearfield for v1
    ext.r1 <- raster.foot1
    ext.r2 <- raster.foot
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

    nf.diff.foot <- overlay(x = nf.r1, y = nf.r2, fun = function(x, y){
        x[is.na(x[])] <- 0
        y[is.na(y[])] <- 0
        return(x - y)
      })  # foot beyond 2 days and near-field

    # extend domain and fill with NA to v2
    ext.r2 <- extend(ext.r2 , extent(ext.r1), value = NA)
    ext.r2 <- crop(ext.r2, extent(ext.r1))

    total.diff.foot <- overlay(x = ext.r1, y = ext.r2, fun = function(x, y){
        x[is.na(x[])] <- 0
        y[is.na(y[])] <- 0
        return(x - y)
      })  # foot beyond 2 days and near-field

    # convert back to df
    total.diff.foot.df <- raster::as.data.frame(total.diff.foot, xy = T) %>%
      filter(layer > 0)
    colnames(total.diff.foot.df) <- c('lon', 'lat', 'foot')
    total.diff.foot.df$fac <- 'diff'

    # find out where is the diff
    zoom <- 10
    facet.nrow <- 1
    picname2 <- file.path(plotdir, paste0('xfoot_', site, '_', uni.timestr, '_',
      met, '_diff_zoom', zoom, '_', dpar, 'dpar.png'))

    mm <- ggplot.map(map = 'ggmap', center.lat = lon.lat[6],
      center.lon = lon.lat[5] + 0.1, zoom = zoom)

    source(file.path(workdir, 'r/dependencies.r'))
    pp3 <- ggmap.xfoot.obs(mm, lon.lat, site, facet.nrow,
      nhrs = '72 vs. 72', dpar, stilt.ver = 'v1 vs. v2', timestr,
      font.size = rel(0.9), recp.lon = sel.lon, recp.lat = sel.lat, obs = obs,
      foot = total.diff.foot.df, picname2, storeTF = T, width = 10, height = 11)

    print(sel.lat[f])

  #} # end for

  # merge all maps
  library(ggpubr)
  mg <- ggarrange(plotlist = list(pp1, pp2, pp3), nrow = 2, ncol = 2)
  ggsave(mg, filename = paste0('xfoot_merge_', site, '_', uni.timestr,'_zoom',
    zoom, '.png'), width = 20, height = 22)

} # end if v1TF


# end of script
