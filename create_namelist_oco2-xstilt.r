# create a namelist for running X-STILT trajectories
# written by DW, 04/18/2018

# --------------------------------- updates ---------------------------------
# now build upon Ben's STILT-R version 2 codes, DW, 05/23/2018
# !!! need to clear up codes for forward run, based on Ben's parallel computing
# Add plotting scripts for footprint and XCO2 enhancements, DW, 06/28/2018
#
# Add STILTv1 dependencies and work well with existing framework and add dmassTF
# for mass violation corrections, DW, 07/17/2018
#
# Add horizontal transport error module with flag 'run_hor_err'
#   with additional subroutines in /src/oco2-xstilt/trans_err, DW, 07/23/2018
#
# Add vertical trans error module, with flag 'run_ver_err',
# ziscale when scaling PBL heights and break trans error part (step 3) into
# horizontal wind error and vertical trans error (via PBL perturb), DW, 07/25/2018
# -----------------------------------------------------------------------------

#### source all functions and load all libraries
# CHANGE working directory ***
homedir <- '/uufs/chpc.utah.edu/common/home'
workdir <- file.path(homedir, 'lin-group5/wde/github/stilt')
setwd(workdir)   # move to working directory
source('r/dependencies.r') # source all functions

#------------------------------ STEP 1 --------------------------------------- #
#### CHOOSE CITIES, SEARCH FOR TRACKS AND OCO-2 LITE FILE VERSION ***
sitelist <- c(
  # middle east and SE Asia
  'Riyadh',  'Medina',   'Mecca',     'Cairo',     'Jerusalem',   'Jeddah',
  'Karachi', 'Tehran',   'Istanbul',  'Baghdad',   'Ankara',
  'Mumbai',  'Delhi',    'Bangalore', 'Hyderabad', 'Ahmedabad',
  'Manila',  'Jakarta',  'Bangkok',   'HoChiMinh', 'Singapore',   'KualaLumpur',

  # China and Japan
  'Nanjing', 'Suzhou',   'Shanghai',  'YRD',   'Beijing',   'Tianjin',  'JJJ',
  'Xian',    'Lanzhou',  'Zhengzhou', 'PRD',
  'Seoul',   'Busan',    'Nagoya',    'Tokyo-Yokohama', 'Osaka-Kobe-Kyoto',

  # Africa and Europe
  'Lagos',   'Luanda',  'Kinshasa',  'CapeTown',   'Johannesburg', 'Moscow',
  'Paris',   'London',  'Madrid',    'Barcelona',  'Rome',         'Berlin',
  'Milan',   'Athens',  'StPetersburg',

  # North America
  'Indy',    'Chicago',  'Phoenix',   'Denver',    'Seattle',     'SLC',
  'LA',      'LV',       'Houston',   'Dallas',    'Albuquerque', 'NY',
  'DC',      'Miami',    'Atlanta',   'Toronto',   'Montreal',    'Vancouver',

  # central & south America and Australia
  'SaoPaulo', 'Lima',    'Perth',     'Sydney',    'Brisbane',    'Melbourne'
)
# one can add more urban regions here

# choose a city from above
site <- 'Riyadh'

# OCO-2 version, path
oco2.ver <- c('b7rb', 'b8r')[2]  # OCO-2 version
input.path <- file.path(homedir, 'lin-group5/wde/input_data')
output.path <-file.path(homedir, 'lin-group5/wde/github/result')

oco2.path <- file.path(input.path, paste0('OCO-2/L2/OCO2_lite_', oco2.ver))
sif.path <- file.path(input.path, paste0('OCO-2/L2/OCO2_lite_SIF_', oco2.ver))
txtpath <- file.path(output.path, 'oco2_overpass')

# date range for searching OCO-2 tracks, min, max YYYYMMDD
date.range <- c('20140101', '20181231')

# vector of examined region, c(minlon, maxlon, minlat, maxlat, citylon, citylat)
lon.lat <- get.lon.lat(site)  # can be NULL, default will be given in site.info()

# 'thred.count' for at least how many soundings needed per 1deg lat range
# -> calculate a total thred on total # of soundings given 'lon.lat'
thred.count.per.deg <- 100  # number of soundings per degree
thred.count.per.deg.urban <- 50

# whether to re-search OCO-2 overpasses and output in txtfile
# if FALSE, read timestr from existing txt file;
# always TRUE, if doing first simulation for a new site
searchTF <- F

# whether search for overpasses over urban region,
# defined as city.lat +/- dlat, city.lon +/- dlon
urbanTF <- T; dlon <- 0.5; dlat <- 0.5

# call get.site.info() to get lon.lat and OCO2 overpasses info
# PLEASE add lat lon info in 'get.site.track'
site.info <- get.site.track(site, oco2.ver, oco2.path, searchTF,
  date.range, thred.count.per.deg, lon.lat, urbanTF, dlon, dlat,
  thred.count.per.deg.urban, txtpath)

# get coordinate info and OCO2 track info from result 'site.info'
lon.lat <- site.info$lon.lat
oco2.track <- site.info$oco2.track
print(lon.lat)

# one can further subset 'oco2.track' based on sounding # over near city center
# one can further subset 'oco2.track' based on data quality
# see columns 'qf.count' or 'wl.count' in 'oco2.track'
# e.g., choose overpasses that have 100 soundings with QF == 0, & get reordered
if (urbanTF) oco2.track <- oco2.track %>% filter(tot.urban.count > 200)
if (oco2.ver == 'b7rb') oco2.track <- oco2.track %>% filter(qf.urban.count > 80)
if (oco2.ver == 'b8r') oco2.track <- oco2.track %>% filter(wl.urban.count > 100)

# finally narrow down and get timestr
all.timestr <- oco2.track$timestr

# once you have all timestr, you can choose whether to plot them on maps
# this helps you choose which overpass to simulate first, see 'tt' below
plotTF <- F
if (plotTF) {
  for(t in 1:length(all.timestr)){
  ggmap.obs.xco2(site, timestr = all.timestr[t], oco2.path, lon.lat, workdir,
    plotdir = file.path(workdir, 'plot/ggmap', site))
  ggmap.obs.sif(site, timestr = all.timestr[t], sif.path, lon.lat, workdir,
    plotdir = file.path(workdir, 'plot/ggmap', site))
  }
}

# *** NOW choose the timestr that you would like to work on...
tt <- 3
timestr <- all.timestr[tt]

cat(paste('Working on:', timestr, 'for city/region:', site, '...\n\n'))
cat('Done with choosing cities & overpasses...\n')


#------------------------------ STEP 2 --------------------------------------- #
#### Whether forward/backward, release from a column or a box
columnTF   <- T    # whether a column receptor or fixed receptor
forwardTF  <- F    # forward or backward traj, if forward, release from a box
windowTF   <- F    # whether to release particles every ? minutes,'dhr' in hours

# T:rerun hymodelc, even if particle location object found
# F:re-use previously calculated particle location object
run_trajec <- T    # whether to generate trajec
run_foot   <- T    # whether to generate footprint
run_sim    <- F    # whether to calculate simulated XCO2.ff, see STEP 8

# whether to generate trajec with horizontal wind err component/to calc trans error
# OR generate trajec with PBL scaling
run_hor_err <- F   # T: set parameters in STEP 3, call functions in STEP 9
run_ver_err <- T   # T: set parameters in STEP 3, call functions in STEP 9
stilt.ver   <- 2   # STILT versions (call different footprint algorithms)

delt <- 0          # fixed timestep [min]; set = 0 for dynamic timestep
nhrs <- -72        # number of hours backward (-) or forward (+)

# change to Ben's definitions,  see validate_varsiwant()
varstrajec <- c('time', 'indx', 'lati', 'long', 'zagl', 'zsfc', 'foot', 'samt',
  'dmas', 'mlht', 'pres', 'sigw', 'tlgr', 'dens')

## below settings are for forward simulations, to be improved ------------------
# if release particles from a box, +/-dxyp, +/-dxyp around the city center
# point to the hymodelc with TN's modicications--
exepath <- file.path(workdir, 'exe/AER_NOAA_branch')  # where hymodelc is
dxyp <- NA
if (forwardTF) {
  dxyp <- 0.4     # deg around city center
  nhrs <- 12      # number of hours backward (-) or forward (+)
}  # end if forwardTF

# whether allow for time window for releasing particles
dhr   <- NA; dtime <- NA
if (windowTF) {
  dhr <- 0.5     # release particle every 30 mins
  dtime <- seq(-10, 0, dhr)
  # e.g., FROM 10 hours ahead of sounding hour (-10), TO sounding hour (0)

  cat('Release particles', dtime[1], 'hrs ahead & every', dhr * 60, 'mins...\n')
}  # end if windowTF

cat('Done with choosing forward box OR backward column runs...\n')


#------------------------------ STEP 3 --------------------------------------- #
# select receptors --
## eyeball lat range for enhanced XCO2, or grab from available forward-time runs
# place denser receptors during this lat range (40pts in 1deg)
selTF <- T  # whether select receptors; or simulate all soundings
if (selTF) {

  # lat range in deg N for placing denser receptors, required for backward run
  if (site == 'Riyadh')    peak.lat <- c(24, 25)
  if (site == 'Jerusalem') peak.lat <- c(31.75, 32.25)
  if (site == 'Cairo')   peak.lat <- c(29.5, 30.5)
  if (site == 'Phoenix') peak.lat <- c(33.0, 34.0)
  if (site == 'Baghdad') peak.lat <- c(32.5, 33.5)

  # number of points to aggregate within 1deg over small/large enhancements,
  # i.e., over background/enhancements, binwidth will be 1deg/num
  num.bg   <- 20   # e.g., every 20 pts in 1 deg
  num.peak <- 40   # e.g., every 40 pts in 1 deg

  # recp.indx: how to pick receptors from all screened soundings (QF = 0)
  recp.indx <- c(seq(lon.lat[3],  peak.lat[1], 1/num.bg),
    seq(peak.lat[1], peak.lat[2], 1/num.peak),
    seq(peak.lat[1], lon.lat[4],  1/num.bg))

} else {
  recp.indx <- NULL
}

# whether to subset receptors when debugging
recp.num <- NULL     # can be a number for max num of receptors
find.lat <- NULL     # for debug or test, model one sounding

# select satellite soundings, plotTF for whether plotting OCO-2 observed XCO2
source('r/dependencies.r') # source all functions
recp.info <- get.recp.info(timestr, oco2.path, lon.lat, selTF, recp.indx,
  recp.num, find.lat, agl, plotTF = F)
nrecp <- nrow(recp.info)
cat('Done with reading OCO-2 data and selecting soundings...\n')


#------------------------------ STEP 4 --------------------------------------- #
# path for the ARL format of WRF and GDAS
# simulation_step() will find corresponding met files
met        <- c('1km', 'gdas1', 'gdas0p5')[3]  # choose met fields
met.path   <- file.path(homedir, 'u0947337', met)
met.num    <- 1                                # min number of met files needed
met.format <- '%Y%m%d_gdas0p5'                 # met file name convention

# one can link to other direcetory that store trajec,
# but need to have the same directory structure, including by-id, footprint...
outdir     <- file.path(workdir, 'out')  # path for storing trajec, foot

#### Whether obtaining wind errors, transport error component
# require wind error comparisons stored in txtfile *****
if (run_hor_err) {
  cat('+++ horizontal wind error component +++\n')

  # intput correlation lengthscale (in m) and timescales (in mins)
  # correlation timescale, horizontal and vertical lengthscales
  if (met == 'gdas0p5') {TLuverr <- 1*60; zcoruverr <- 600; horcoruverr <- 40}
  if (met == 'gdas1') {TLuverr <- 2.4*60; zcoruverr <- 700; horcoruverr <- 97}

  ## add errors, mainly siguverr, create a subroutine to compute siguverr
  # from model-data wind comparisons
  err.path <- file.path(homedir, 'lin-group5/wde/input_data/wind_err')
  err.path <- file.path(err.path, tolower(site), tolower(met))

  # call get.SIGUVERR() to interpolate most near-field wind errors
  err.info <- get.siguverr(site, timestr, errpath = err.path, nfTF = F,
    forwardTF = forwardTF, lon.lat, nhrs)

  if (is.null(err.info)) {
    cat('no wind error found; make consevative assumption of siguverr...\n')
    # make a conservative assumption about the wind error, for the Middle East
    siguverr <- 1.8  # < 2 m/s for GDAS 1deg, based on Wu et al., GMDD

  } else {
    met.rad  <- err.info[[1]]
    siguverr <- as.numeric(err.info[[2]][1])    # SD in wind errors
    u.bias   <- as.numeric(err.info[[2]][2])
    v.bias   <- as.numeric(err.info[[2]][3])
    cat(paste('u.bias:', signif(u.bias,3), 'm/s; v.bias:', signif(v.bias,3), 'm/s\n'))

  }  # end if is.null(err.info)
  cat(paste('SIGUVERR:', signif(siguverr, 3), 'm/s..\n'))

} else {  # if no wine error component used
  cat('NO horizontal wind error component for generating trajec...\n')
  siguverr    <- NA
  TLuverr     <- NA
  horcoruverr <- NA
  zcoruverr   <- NA
}  # end if run_hor_err

# no error covariance on PBL heights used for now
# but one can assign values as below
sigzierr    <- NA
TLzierr     <- NA
horcorzierr <- NA

### Besides horizontal wind error, do we want to account for PBL height?
# add vertical trans error via ziscale *****
if (run_ver_err) {
  cat('+++ PBL scaling when generating trajec +++\n')
  zicontroltf <- 1              # 0 for FALSE; 1 for scaling, TRUE
  ziscale     <- rep(list(rep(1.2, 24)), nrecp)  # create as list
  # 1st # for scaling factor; 2nd # for # of hours (always use abs())

} else {
  cat('NO PBL scaling when generating trajec...\n')
  zicontroltf <- 0
  ziscale     <- NULL
} # end if run_ver_err

cat('Done with choosing met & inputting wind errors...\n')


#------------------------------ STEP 5 --------------------------------------- #
#### Set model receptors, AGLs and particel numbers ***
# for backward fixed-level runs OR forward fixed-level runs
# agl can be a vector, meaning releasing particles from several fixed level
# but if trying to represent air column, use columnTF=T, see below

### 1) if release particles from fixed levels
agl    <- 10         # in mAGL
numpar <- 1000       # par for each time window for forward box runs

### 2) SET COLUMN RECEPTORS as a list, if release particles from a column
if (columnTF) {

  # min, middle, max heights for STILT levels, in METERS
  minagl <- 0
  midagl <- 3000
  maxagl <- 6000

  # vertical spacing below and above cutoff level 'midagl', in METERS
  dh   <- c(100, 500)

  # particle numbers per level, 2500 for the Brute Force test
  dpar <- c(10, 50, 100, 200, 2500)[3]

  # compute the agl list
  agl  <- list(c(seq(minagl, midagl, dh[1]), seq(midagl+dh[2], maxagl, dh[2])))
  nlev <- length(unlist(agl))
  numpar <- nlev * dpar   # total number of particles
}

cat('Done with receptor setup...\n')


#------------------------------ STEP 6 --------------------------------------- #
#### Settings for generating footprint maps
## SET spatial domains and resolution for calculating footprints
foot.res <- 1/120  # footprint resolution, 1km for ODIAC

# these variables will determine resoluation and spatial domain of footprint
# 20x20 degree domain around the city center
foot.info <- data.frame(
  xmn = round(lon.lat[5]) - 10, xmx = round(lon.lat[5]) + 10,
  ymn = round(lon.lat[6]) - 10, ymx = round(lon.lat[6]) + 10,
  xres = foot.res, yres = foot.res
)
# OR customize foot domain, in deg E and deg N
foot.info <- data.frame(xmn = 30, xmx = 50, ymn = 15, ymx = 35, xres = foot.res,
  yres = foot.res)
print(foot.info)

## whether weighted footprint by AK and PW for column simulations
if (columnTF) {
  ak.wgt  <- T; pwf.wgt <- T
} else {  # no weighting needed for fixed receptor simulations
  ak.wgt <- NA; pwf.wgt <- NA
}

# 1st-order correction on dmass for footprint using STILTv1
dmassTF <- F

# other footprint parameters using STILTv2
hnf_plume      <- T  # whether turn on hyper near-field (HNP) for mising hgts
smooth_factor  <- 1  # Gaussian smooth factor, 0 to disable
time_integrate <- T  # whether integrate footprint along time
projection     <- '+proj=longlat'


cat('Done with footprint setup...\n')


#------------------------------ STEP 7 --------------------------------------- #
#### !!! NO NEED TO CHANGE ANYTHING LISTED BELOW -->
# create a namelist including all variables
# namelist required for generating trajec
namelist <- list(agl = agl, ak.wgt = ak.wgt, delt = delt, dmassTF = dmassTF,
  dpar = dpar, dtime = dtime, dxyp = dxyp, foot.info = foot.info,
  forwardTF = forwardTF, hnf_plume = hnf_plume, homedir = homedir,
  horcoruverr = horcoruverr, horcorzierr = horcorzierr, lon.lat = lon.lat,
  met = met, met.format = met.format, met.num = met.num, met.path = met.path,
  nhrs = nhrs, numpar = numpar, outdir = outdir, oco2.path = oco2.path,
  projection = projection, pwf.wgt = pwf.wgt, recp.info = recp.info,
  run_foot = run_foot, run_sim = run_sim, run_trajec = run_trajec,
  run_hor_err = run_hor_err, run_ver_err = run_ver_err, siguverr = siguverr,
  sigzierr = sigzierr, site = site, smooth_factor = smooth_factor,
  stilt.ver = stilt.ver, time_integrate = time_integrate, timestr = timestr,
  TLuverr = TLuverr, TLzierr = TLzierr, varstrajec = varstrajec,
  windowTF = windowTF, workdir = workdir, zicontroltf = zicontroltf,
  ziscale = ziscale, zcoruverr = zcoruverr)


#------------------------------ STEP 8 --------------------------------------- #
## call get.more.namelist() to get more info about receptors
# further read OCO-2 data
# then get receptor info and other info for running trajec
# plotTF for whether plotting OCO-2 observed data
if (forwardTF == F) {

  # if running trajec or footprint--
  if (run_trajec | run_foot) {
    ## use Ben's algorithm for parallel simulation settings
    n_nodes  <- 7
    n_cores  <- 10
    job.time <- '24:00:00'
    slurm    <- n_nodes > 1
    namelist$slurm_options <- list(time = job.time, account = 'lin-kp',
      partition = 'lin-kp')

    # time allowed for running hymodelc before forced terminations
    timeout  <- 12 * 60 * 60  # in sec
    namelist <- c(namelist, n_cores = n_cores, n_nodes = n_nodes, slurm = slurm,
      timeout = timeout)
    cat('Done with creating namelist...\n')

    if (run_trajec) cat('Need to generate trajec...\n')
    if (run_foot)   cat('Need to generate footprint...\n\n')

    # call run_stilt_mod(), start running trajec and foot
    run.stilt.mod(namelist = namelist)
  }

} else if (forwardTF) {

  ## if for forward time runs and determining backgorund XCO2
  # plotTF for whether plotting urban plume & obs XCO2 if calling forward function
  # !!! if forward, release particles from a box around the city center

  # plotTF for whether to plot the forward urban plume
  cat('Generating forward trajec...\n')
  run.forward.trajec(namelist = namelist, plotTF = T)
}  # end if forwardTF


#------------------------------ STEP 9 --------------------------------------- #
# Simulate XCO2.ff using ODIAC emissions, DW, 06/04/2018
## add FFCO2 emissions, e.g., ODIAC
if (run_sim) {

  foot.path <- file.path(workdir, 'out', 'footprints')
  #foot.path <- file.path(workdir, 'ziscale_test/out_ziscale_1.2/by-id')
  foot.file <- list.files(foot.path, pattern = 'foot.nc')

  tmp.foot <- raster(file.path(foot.path, foot.file[1]))
  foot.extent <- extent(tmp.foot)
  cat('Done reading footprint.\n')

  # txt file name for outputting model results
  txtfile <- file.path(workdir, paste0(timestr, '_', site, '_XCO2ff_',
    abs(nhrs), 'hrs_', dpar, 'dpar_sf', smooth_factor, '.txt'))

  # before simulations, subset emissions and convert tif format to nc format
  vname <- '2017'
  tiff.path <- file.path(homedir, paste0('lin-group2/group_data/ODIAC/ODIAC',
    vname), substr(timestr, 1,4))  # tif file from ODIAC website

  # call tif2nc.odiacv2() to subset and get emiss file name
  # 'store.path' is the path for outputting emissions
  cat('Start reading and subsetting emissions that match foot...\n')
  emiss.file <- tif2nc.odiacv3(site, timestr, vname, workdir, foot.extent,
    store.path = file.path(workdir, 'in', 'ODIAC'), tiff.path, gzTF = F)

  # plot emissions
  if (F) {

    emiss.file <- list.files(path = file.path(workdir, 'in', 'ODIAC'))[4]
    emiss <- raster(file.path(workdir, 'in', 'ODIAC', emiss.file))
    emiss.df <- raster::as.data.frame(emiss, xy = T)
    colnames(emiss.df) <- list('lon', 'lat', 'emiss')
    emiss.df <- emiss.df %>% filter(emiss > 1)

    lon.lat <- c(46.00, 48.00, 23.50, 26.00, 46.72, 24.63) # Riyadh
    #lon.lat <- c(43.00, 45.00, 32.00, 34.00, 44.36, 33.31)  # Baghdad
    mm <- ggplot.map(map = 'ggmap', center.lat = lon.lat[6],
      center.lon = lon.lat[5], zoom = 8)

    # grab observations using map lat/lon
    map.ext <- c(min(mm[[1]]$data$lon), max(mm[[1]]$data$lon),
      min(mm[[1]]$data$lat), max(mm[[1]]$data$lat))

    sel.emiss <- emiss.df %>% filter(lon >= map.ext[1] & lon <= map.ext[2] &
      lat >= map.ext[3] & lat <= map.ext[4])
    print(sel.emiss[sel.emiss$emiss >= 100, ])

    e1 <- mm[[1]] + coord_equal() + geom_raster(data = sel.emiss,
      aes(lon + mm[[3]], lat + mm[[2]], fill = emiss)) +
      scale_fill_gradientn(trans = 'log10', colours = def.col(),
        limits = c(1, 1E5))

  }

  # reformatted ODIAC emissions file name should include 'YYYYMM'
  # 'store.path' here is the path for storing nc format foot * emission
  # call func to match ODIAC emissions with xfoot & sum up to get 'dxco2.ff'
  cat('Start XCO2.ff simulations...\n')
  #store.path <- file.path(output.path, 'foot_emiss/tmp')
  store.path <- file.path(outdir, 'by-id')
  receptor <- foot.odiacv3(foot.path, foot.file, emiss.file, workdir, store.path,
    txtfile, plotTF = F)

  #ff2 <- read.table(txtfile, sep = ',', header = T)
  #l1 <- ggplot() + geom_point(data = receptor, aes(lat, xco2.ff), colour = 'red')

  ### add latitude integrations--
  library(zoo)
  auc <- diff(receptor$lat) * rollmean(receptor$xco2.ff, 2)
  xco2.ff.int <- sum(auc[auc > 0])
  cat(paste('Lat-integrated XCO2.ff:', signif(xco2.ff.int, 3), 'ppm\n'))
}


#------------------------------ STEP 10 --------------------------------------- #
### simulate transport error in XCO2 due to met errors
if (run_hor_err) {

  # for ffco2 emission path and files
  vname <- '2017'
  tiff.path <- file.path(homedir, paste0('lin-group2/group_data/ODIAC/ODIAC',
    vname), substr(timestr, 1,4))  # tif file from ODIAC website
  foot.extent <- extent(as.numeric(foot.info[1:4]))
  emiss.file <- tif2nc.odiacv3(site, timestr, vname, workdir, foot.extent,
    store.path = file.path(workdir, 'in', 'ODIAC'), tiff.path, gzTF = F)

  # load two paths for trajec before and after perturbations
  traj.path1 <- file.path(homedir, 'lin-group5/wde/github/cp_trajecfoot/out_2014122910_100dpar/by-id')
  traj.path2 <- file.path(workdir, 'out/by-id')

  # add CT paths and files, DW, 07/28/2018
  ct.ver <- '2016-1'; if (timestr >= 20160101) ct.version <- '2017'
  ctflux.path <- file.path(
    '/uufs/chpc.utah.edu/common/home/lin-group2/group_data/CT-NRT',
    paste0('v', ct.ver), 'fluxes/optimized')
  ctmole.path <- file.path(
    '/uufs/chpc.utah.edu/common/home/lin-group2/group_data/CT-NRT',
    paste0('v', ct.ver), 'molefractions/co2_total')

  # path for storing CO2 statistics
  store.path <- file.path(output.path, 'trans_err')

  # txt file name for outputting model results
  txtfile <- file.path(workdir, paste0(timestr, '_', site, '_trans_err_',
    met, '.txt'))

  namelist <- c(namelist, emiss.file = emiss.file, traj.path1 = traj.path1,
    traj.path2 = traj.path2, ct.ver = ct.ver, ctflux.path = ctflux.path,
    ctmole.path = ctmole.path, store.path = store.path, txtfile = txtfile)

  # call cal.trans.err to estimate trans err
  trans.err <- cal.trans.err(namelist)
}
# end of script
