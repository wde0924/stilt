# create a namelist for running X-STILT trajectories
# written by DW, 04/18/2018

# now build upon Ben's STILT-R version 2 codes, DW, 05/23/2018
# latest modification on 06/03/2018
# !!! need to clear up codes for forward run, based on Ben's parallel computing

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
site <- 'Baghdad'

# OCO-2 version, path
oco2.ver <- c('b7rb', 'b8r')[2]  # OCO-2 version
oco2.str  <- paste0('OCO-2/L2/OCO2_lite_', oco2.ver)
oco2.path <- file.path(homedir, 'lin-group5/wde/input_data', oco2.str)
#txtpath <- file.path(homedir, 'lin-group5/wde/input_data/OCO-2/overpass_city')
txtpath <- file.path(workdir, 'plot/ggmap')

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
if (urbanTF) oco2.track <- oco2.track %>% filter(qf.urban.count > 100 &
  tot.urban.count > 300)

# finally narrow down and get timestr
all.timestr <- oco2.track$timestr

# once you have all timestr, you can choose whether to plot them on maps
# this helps you choose which overpass to simulate first, see 'tt' below
plotTF <- F
if (plotTF) {
  for(t in 1:length(all.timestr)){
  ggmap.obs.xco2(site, timestr = all.timestr[t], oco2.path, lon.lat, workdir,
    plotdir = file.path(workdir, 'plot'))
  }
}

# *** NOW choose the timestr that you would like to work on...
tt <- c(1, 2, 3, 8, 12)[1]
timestr <- all.timestr[tt]

cat(paste('Working on:', timestr, 'for city/region:', site, '...\n\n'))
cat('Done with choosing cities & overpasses...\n')


#------------------------------ STEP 2 --------------------------------------- #
#### Whether forward/backward, release from a column or a box
columnTF   <- T    # whether a column receptor or fixed receptor
forwardTF  <- F    # forward or backward traj, if forward, release from a box
windowTF   <- F    # whether to release particles every ? minutes,'dhr' in hours
run_trajec <- T	   # T:rerun hymodelc, even if particle location object found
  # F:re-use previously calculated particle location object
run_foot   <- T    # whether to generate footprint
run_sim    <- T    # whether to calculate simulated XCO2.ff

delt <- 0          # fixed timestep [min]; set = 0 for dynamic timestep
nhrs <- -72        # number of hours backward (-) or forward (+)

# copy for running trajwind() or trajec()
# can be a vector with values denoting copy numbers
nummodel <- NA

## if release particles from a box, +/-dxyp, +/-dxyp around the city center
dxyp <- NA
if (forwardTF) {
  dxyp <- 0.2 * 2
  nhrs <- 12          # number of hours backward (-) or forward (+)
  nummodel <- 997     # use TN's hymodelc to run forward box trajec
}  # end if forwardTF

# whether allow for time window for releasing particles
dhr   <- NA
dtime <- NA
if (windowTF) {
  dhr <- 0.5     # release particle every 30 mins

  # FROM 10 hours ahead of sounding hour (-10), TO sounding hour (0)
  dtime <- seq(-10, 0, dhr)
  cat('Release particles', dtime[1], 'hrs ahead & every', dhr * 60, 'mins...\n')
}  # end if windowTF
cat('Done with choosing forward box OR backward column runs...\n')


#------------------------------ STEP 3 --------------------------------------- #
#### CHANGE PATHS ***
# path for the ARL format of WRF and GDAS, CANNOT BE TOO LONG ***
# simulation_step() will find corresponding met files
met <- c('1km', 'gdas1', 'gdas0p5')[3]  # choose met fields
met.path <- file.path(homedir, 'u0947337', met)
met.num <- 1
met.format <- '%Y%m%d_gdas0p5' # met file name convention
outdir <- file.path(workdir, 'out')  # path for storing trajec, foot

#### Whether obtaining wind errors, transport error component
errTF <- F    # whether add wind error component to generate trajec
if (errTF) {
  cat('Using wind error component...\n')

  # intput correlation lengthscale (in m) and timescales (in mins) ***
  # correlation timescale, horizontal and vertical lengthscales
  if (met == 'gdas0p5') {TLuverr <- 1*60; zcoruverr <- 600; horcoruverr <- 40}
  if (met == 'gdas1') {TLuverr <- 2.4*60; zcoruverr <- 700; horcoruverr <- 97}

  ## add errors, mainly siguverr, create a subroutine to compute siguverr
  # from model-data wind comparisons
  err.path <- file.path(homedir, 'lin-group5/wde/input_data/wind_err')
  err.path <- file.path(err.path, tolower(site), tolower(met))

  # call get.SIGUVERR() to interpolate most near-field wind errors
  err.info <- get.siguverr(site = site, forwardTF = F, gdaspath = err.path,
    nfTF = F, timestr = timestr)

  if (is.null(err.info)) {
    cat('no wind error found; make consevative assumption of siguverr...\n')
    # make a conservative assumption about the wind error, for the Middle East
    siguverr <- 1.8  # < 2 m/s for GDAS 1deg, based on Wu et al., submitted

  } else {
    #met.rad <- err.info[[1]]
    siguverr <- as.numeric(err.info[[2]][1])    # SD in wind errors
    u.bias   <- as.numeric(err.info[[2]][2])
    v.bias   <- as.numeric(err.info[[2]][3])
    cat(paste('u.bias:', signif(u.bias,3), 'm/s; v.bias:', signif(u.bias,3), 'm/s\n'))
  }  # end if is.null(err.info)
  cat(paste('SIGUVERR:', signif(siguverr,3), 'm/s..\n'))

} else {  # if no wine error component used
  cat('NO wind error component for generating trajec...\n')
  siguverr <- NA; TLuverr <- NA; horcoruverr <- NA; zcoruverr <- NA
  sigzierr <- NA; TLzierr <- NA; horcorzierr <- NA
}  # end if errTF
cat('Done with choosing met & inputting wind errors...\n')


#------------------------------ STEP 4 --------------------------------------- #
#### Set model receptors, AGLs and particel numbers ***
# for backward fixed-level runs OR forward fixed-level runs
# agl can be a vector, meaning releasing particles from several fixed level
# but if trying to represent air column, use columnTF=T, see below

### 1) if release particles from fixed levels
agl <- 10
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
  num.peak <- 50   # e.g., every 40 pts in 1 deg

  # recp.indx: how to pick receptors from all screened soundings (QF = 0)
  recp.indx <- c(seq(lon.lat[3],  peak.lat[1], 1/num.bg),
    seq(peak.lat[1], peak.lat[2], 1/num.peak),
    seq(peak.lat[1], lon.lat[4],  1/num.bg))

} else {
  recp.indx <- NULL
}
cat('Done with receptor setup...\n')


#------------------------------ STEP 5 --------------------------------------- #
#### Footprint grid settings
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
foot.info <- data.frame(xmn = 30, xmx = 50, ymn = 25, ymx = 45,
  xres = foot.res, yres = foot.res)
print(foot.info)

## whether weighted footprint by AK and PW for column simulations
ak.wgt <- NA; pwf.wgt <- NA
if (columnTF) {
  ak.wgt  <- T
  pwf.wgt <- T
}

hnf_plume      <- T  # whether turn on hyper near-field (HNP) for mising hgts
smooth_factor  <- 1  # Gaussian smooth factor, 0 to disable
time_integrate <- T  # whether integrate footprint along time
projection     <- '+proj=longlat'
cat('Done with footprint setup...\n')


#------------------------------ STEP 6 --------------------------------------- #
#### !!! NO NEED TO CHANGE ANYTHING LISTED BELOW -->
# create a namelist including all variables
# namelist required for generating trajec
namelist <- list(agl = agl, ak.wgt = ak.wgt, delt = delt, dpar = dpar,
  dtime = dtime, dxyp = dxyp, errTF = errTF, foot.info = foot.info,
  forwardTF = forwardTF, hnf_plume = hnf_plume, homedir = homedir,
  horcoruverr = horcoruverr, horcorzierr = horcorzierr, lon.lat = lon.lat,
  met.format = met.format, met.num = met.num, met.path = met.path, nhrs = nhrs,
  numpar = numpar, outdir = outdir, oco2.path = oco2.path,
  projection = projection, pwf.wgt = pwf.wgt, recp.indx = recp.indx,
  run_foot = run_foot, run_sim = run_sim, run_trajec = run_trajec,
  selTF = selTF, siguverr = siguverr, sigzierr = sigzierr, site = site,
  smooth_factor = smooth_factor, time_integrate = time_integrate,
  timestr = timestr, TLuverr = TLuverr, TLzierr = TLzierr, windowTF = windowTF,
  workdir = workdir, zcoruverr = zcoruverr)


#------------------------------ STEP 7 --------------------------------------- #
## call get.more.namelist() to get more info about receptors
# further read OCO-2 data
# then get receptor info and other info for running trajec
# plotTF for whether plotting OCO-2 observed data
if (forwardTF == F) {

  # whether to subset receptors when debugging
  namelist$recp.num <- NULL   # can be a number for max num of receptors
  namelist$find.lat <- NULL   # for debug or test, model one sounding

  # select satellite soundings, plotTF for whether plotting OCO-2 observed XCO2
  source('r/dependencies.r') # source all functions
  namelist <- recp.to.namelist(namelist, plotTF = F)

  ## use Ben's algorithm for parallel simulation settings
  n_nodes  <- 6
  n_cores  <- 12
  job.time <- '24:00:00'
  slurm    <- n_nodes > 1
  #slurm <- T

  namelist$slurm_options <- list(time = job.time, account = 'lin-kp',
    partition = 'lin-kp')

  # time allowed for running hymodelc before forced terminations
  timeout  <- 3 * 60 * 60  # in sec

  namelist <- c(namelist, n_cores = n_cores, n_nodes = n_nodes, slurm = slurm,
    timeout = timeout)
  cat('Done with creating namelist...\n')

  if (run_trajec) cat('Need to generate trajec...\n')
  if (run_foot) cat('Need to generate footprint...\n\n')

  # call run_stilt_mod(), start running trajec and foot
  if (run_trajec | run_foot) run.stilt.mod(namelist = namelist)

} else if (forwardTF) {

  ## if for forward time runs and determining backgorund XCO2
  # plotTF for whether plotting urban plume & obs XCO2 if calling forward function
  # !!! if forward, release particles from a box around the city center

  # plotTF for whether to plot the forward urban plume
  cat('Generating forward trajec...\n')
  run.forward.trajec(namelist = namelist, plotTF = T)
}  # end if forwardTF


#------------------------------ STEP 8 --------------------------------------- #
# Simulate XCO2.ff using ODIAC emissions, DW, 06/04/2018
## add FFCO2 emissions, e.g., ODIAC
if (run_sim) {

  #foot.path <- '/uufs/chpc.utah.edu/common/home/lin-group4/wde/STILT_output/OCO-2/Footprints/Riyadh'
  foot.path <- file.path(workdir, 'out', 'footprints')
  foot.file <- list.files(foot.path, pattern = substr(timestr, 1, 8))

  tmp.foot <- raster(file.path(foot.path, foot.file[1]))
  foot.extent <- extent(tmp.foot)
  cat('Done reading footprint.\n')

  # txt file name for outputting model results
  txtfile <- file.path(workdir, paste0(timestr, '_', site, '_XCO2ff_',
    abs(nhrs), 'hrs_', dpar, 'dpar_test.txt'))

  # before simulations, subset emissions and convert tif format to nc format
  vname <- '2017'
  tiff.path <- file.path(homedir, paste0('lin-group2/group_data/ODIAC/ODIAC',
    vname), substr(timestr, 1,4))  # tif file from ODIAC website

  # call tif2nc.odiacv2() to subset and get emiss file name
  # 'store.path' is the path for outputting emissions
  cat('Start reading and subsetting emissions that match foot...\n')
  emiss.file <- tif2nc.odiacv3(site, timestr, vname, workdir, foot.extent,
    store.path = file.path(workdir, 'in', 'ODIAC'), tiff.path, gzTF = F)

  # reformatted ODIAC emissions file name should include 'YYYYMM'
  # 'store.path' here is the path for storing nc format foot * emission
  # call func to match ODIAC emissions with xfoot & sum up to get 'dxco2.ff'
  cat('Start XCO2.ff simulations...\n')
  source('r/dependencies.r') # source all functions
  receptor <- foot.odiacv3(foot.path, foot.file, emiss.file, workdir,
    store.path = file.path(workdir, 'plot', 'foot_emiss'), txtfile, plotTF = F)

  #ff2 <- read.table(txtfile, sep = ",", header = T)
  #l1 <- ggplot() + geom_point(data = receptor, aes(lat, xco2.ff), colour = 'red')

  ### add latitude integrations--
  auc <- diff(receptor$lat) * rollmean(receptor$xco2.ff, 2)
  xco2.ff.int <- sum(auc[auc > 0])
  cat(paste("Lat-integrated XCO2.ff:", signif(xco2.ff.int, 3), "ppm\n"))
}

# end of script
