# create a namelist for running X-STILT trajectories
# written by DW, 04/18/2018

# now build upon Ben's STILT-R version 2 codes, DW, 05/23/2018
# latest modification on 06/03/2018
# !!! need to clear up codes for forward run, based on Ben's parallel computing

#### source all functions and load all libraries
# CHANGE working directory ***
homedir <- '/uufs/chpc.utah.edu/common/home'
workdir <- file.path(homedir, 'lin-group1/wde/github/stilt')
setwd(workdir)   # move to working directory
source('r/dependencies.r') # source all functions

#------------------------------ STEP 1 --------------------------------------- #
#### CHOOSE CITIES, SEARCH FOR TRACKS AND OCO-2 LITE FILE VERSION ***
# one can add more urban regions here
indx  <- 12
site <- c(
  'Riyadh', 'Medina',  'Mecca', 'Cairo',   'Jerusalem',    # 1-5
  'PRD',    'Beijing', 'Xian',  'Lanzhou', 'Mumbai',       # 6-10
  'Indy',   'Phoenix', 'SLC',   'Denver',  'LA',           # 11-15
  'Seattle' )[indx]                                        # 16-more

# OCO-2 version, path
oco2.ver <- c('b7rb', 'b8r')[1]  # OCO-2 version
oco2.str  <- paste0('OCO-2/L2/OCO2_lite_', oco2.ver)
oco2.path <- file.path(homedir, 'lin-group1/wde/input_data', oco2.str)

# date range for searching OCO-2 tracks, min, max YYYYMMDD
date.range <- c('20140101', '20181231')

# vector of examined region, c(minlon, maxlon, minlat, maxlat, citylon, citylat)
lon.lat <- NULL  # can be NULL, default will be given in site.info()

# 'thred.count' for at least how many soundings needed per 1deg lat range
# -> calculate a total thred on total # of soundings given 'lon.lat'
thred.per.count <- 100  # number of soundings per degree

# whether to re-search OCO-2 overpasses and output in txtfile
# if FALSE, read timestr from existing txt file;
# always TRUE, if doing first simulation for a new site
searchTF <- F

# whether search for overpasses over urban region,
# defined as city.lat +/- dlat, city.lon +/- dlon
urbanTF <- T; dlon <- 0.5; dlat <- 0.5

# call get.site.info() to get lon.lat and OCO2 overpasses info
# PLEASE add lat lon info in 'get.site.track'
site.info <- get.site.track(site, oco2.ver, oco2.path, workdir, searchTF,
  date.range, thred.per.count, lon.lat, urbanTF, dlon, dlat)

# get coordinate info and OCO2 track info from result 'site.info'
lon.lat <- site.info$lon.lat
oco2.track <- site.info$oco2.track

# one can further subset 'oco2.track' based on sounding # over near city center
if (urbanTF) oco2.track <- oco2.track %>%
  filter(tot.urban.count > 100) #%>% arrange(desc(tot.urban.count))

# one can further subset 'oco2.track' based on data quality
# see columns 'qf.count' or 'wl.count' in 'oco2.track'
# e.g., choose overpasses that have 100 soundings with QF == 0, & get reordered
oco2.track <- oco2.track %>% filter(qf.urban.count > 100)

# finally narrow down and get timestr
all.timestr <- oco2.track$timestr

# once you have all timestr, you can choose whether to plot them on maps
# this helps you choose which overpass to simulate first, see 'tt' below
plotTF <- F
if (plotTF) for(t in 1:length(all.timestr)){
  ggmap.obs.xco2(site, timestr = all.timestr[t], oco2.path, lon.lat)
}

# *** NOW choose the timestr that you would like to work on...
tt <- 4
timestr <- all.timestr[tt]

cat(paste('Working on:', timestr, 'for city/region:', site, '...\n\n'))
cat('Done with choosing cities & overpasses...\n')


#------------------------------ STEP 2 --------------------------------------- #
#### Whether forward/backward, release from a column or a box
columnTF   <- T    # whether a column receptor or fixed receptor
forwardTF  <- F    # forward or backward traj, if forward, release from a box
windowTF   <- F    # whether to release particles every ? minutes,'dhr' in hours
run_trajec <- F	   # T:rerun hymodelc, even if particle location object found
  # F:re-use previously calculated particle location object
run_foot   <- T    # whether to generate footprint
run_sim    <- F    # whether to calculate simulated XCO2.ff
delt <- 2          # fixed timestep [min]; set = 0 for dynamic timestep
nhrs <- -48        # number of hours backward (-) or forward (+)

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
  err.path <- file.path(homedir, 'lin-group1/wde/input_data/wind_err')
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
  dpar <- c(10, 50, 100, 200)[3]           # particle numbers per level

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
  if (site == 'Riyadh') peak.lat <- c(24.5, 25)
  if (site == 'Jerusalem') peak.lat <- c(31.75, 32.25)
  if (site == 'Cairo') peak.lat <- c(29.5, 30.5)
  if (site == 'Phoenix') peak.lat <- c(33, 34)

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

cat('Done with receptor setup...\n')

#------------------------------ STEP 5 --------------------------------------- #
#### Footprint grid settings
## SET spatial domains and resolution for calculating footprints
foot.res <- 1/120  # footprint resolution, 1km for ODIAC

# these variables will determine resoluation and spatial domain of footprint
# 10x10 degree domain around the city center
foot.info <- data.frame(
  xmn = round(lon.lat[5]) - 5, xmx = round(lon.lat[5]) + 5,
  ymn = round(lon.lat[6]) - 5, ymx = round(lon.lat[6]) + 5,
  xres = foot.res, yres = foot.res
)

## whether weighted footprint by AK and PW for column simulations
ak.wgt <- NA; pwf.wgt <- NA
if (columnTF) {
  ak.wgt  <- T
  pwf.wgt <- T
}

hnf_plume      <- T  # whether turn on hyper near-field (HNP) for mising hgts
smooth_factor  <- 1  # Gaussian smooth factor
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

  # select satellite soundings, plotTF for whether plotting OCO-2 observed XCO2
  namelist <- recp.to.namelist(namelist = namelist, plotTF = F)

  ## use Ben's algorithm for parallel simulation settings
  n_nodes  <- 7
  n_cores  <- 11
  job.time <- '48:00:00'
  slurm    <- n_nodes > 1

  namelist$slurm_options <- list(time = job.time, account = 'lin-kp',
    partition = 'lin-kp')
  namelist <- c(namelist, n_cores = n_cores, n_nodes = n_nodes, slurm = slurm)
  cat('Done with creating namelist...\n')

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

  #foot.path <- file.path(workdir, 'plot/foot/24hrs_back/100dpar')
  foot.path <- file.path(workdir, 'out', 'footprints')
  foot.file <- list.files(foot.path, pattern = substr(timestr, 1, 8))

  # call func to match ODIAC emissions with xfoot & sum up to get 'dxco2.ff'
  txtfile <- file.path(workdir, paste0(timestr, '_', site, '_XCO2ff_', dpar,
    'dpar.txt'))

  # before simulations, subset emissions and convert tif format to nc format
  vname <- '2017'
  tiff.path <- file.path(homedir, paste0('lin-group1/group_data/ODIAC/ODIAC',
    vname), substr(timestr, 1,4))  # tif file from ODIAC website
  store.path <- file.path(workdir, 'in') # path for storing nc format ODIAC

  source('r/dependencies.r') # source all functions
  emiss.file <- tif2nc.odiacv2(timestr, foot.info, workdir, store.path,
    tiff.path, vname, site)

  # reformatted ODIAC emissions file name should include 'YYYYMM'
  xco2.ff <- foot.odiacv2(foot.path, foot.file, emiss.file,
    emiss.ext = c(0, 60, 0, 50),
    workdir, timestr, txtfile, storeTF = T, res = foot.res)

}

# end of script
