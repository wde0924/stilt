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
#### CHOOSE CITIES, TRACKS AND OCO-2 LITE FILE VERSION ***
# one can add other urban regions here
indx  <- 1
site  <- c('Riyadh', 'Cairo', 'PRD', 'Jerusalem')[indx]
met   <- c('1km', 'gdas1', 'gdas0p5')[3]  # customized WRF, 1 or 0.5deg GDAS

# CHOOSE OVERPASSED TIMESTR
tt <- 2   # which track to model

# input all track numbers to be modeled, can be YYYYMMDD OR YYYYMMDDHH ***
# track timestr can also be grabbed from another script
riyadh.timestr <- c('20141227', '20141229', '20150128', '20150817', '20151112',
                    '20151216', '20160115', '20160216', '20160725', '20161031')[tt]
jerusalem.timestr <- c('20150615', '20150624', '20150717', '20150726',
                       '20160601', '20160610', '20160703', '20160712',
                       '20170417', '20170528', '20170620', '20170629')[tt]
cairo.timestr <- c('20150228', '20150318', '20160224')[tt]
prd.timestr <- '20150115'

# final timestr, YYYYMMDD and file strings for trajec
timestr <- c(riyadh.timestr, cairo.timestr, prd.timestr, jerusalem.timestr)[indx]

# spatial domains placing receptors and city center, help select OCO-2 data ***
# in form of 'lon.lat <- c(minlon, maxlon, minlat, maxlat, city.lon, city.lat)'
if (site == 'Riyadh') {lon.lat <- c(45, 50, 23, 26, 46.75, 24.71); oco2.hr = 10}
if (site == 'Cairo') {lon.lat <- c(30, 32, 29, 31, NA, NA); oco2.hr = 10}
if (site == 'PRD') {lon.lat <- c(112, 115, 22, 23, NA, NA); oco2.hr = 5}
if (site == 'Jerusalem') {lon.lat <- c(35, 36, 31.75, 32.25, 35.22, 31.78);
                          oco2.hr = 10}
timestr <- paste0(timestr, formatC(oco2.hr, width = 2, flag = 0))


#------------------------------ STEP 2 --------------------------------------- #
#### Whether forward/backward, release from a column or a box
columnTF   <- T    # whether a column receptor or fixed receptor
forwardTF  <- F    # forward or backward traj, if forward, release from a box
windowTF   <- F    # whether to release particles every ?? minutes,'dhr' in hours

run_trajec <- F	   # T:rerun hymodelc, even if particle location object found
                   # F:re-use previously calculated particle location object
run_foot   <- T    # whether to generate footprint
run_sim    <- T    # whether to calculate simulated XCO2.ff

delt <- 2          # fixed timestep [min]; set = 0 for dynamic timestep
nhrs <- -24        # number of hours backward (-) or forward (+)

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


#------------------------------ STEP 3 --------------------------------------- #
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
  errpath <- file.path(homedir, 'lin-group1/wde/input_data/wind_err')
  errpath <- file.path(errpath, tolower(site), tolower(met))

  # call get.SIGUVERR() to interpolate most near-field wind errors
  err.info <- get.siguverr(site = site, forwardTF = F, gdaspath = errpath,
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

cat('step 3')
#------------------------------ STEP 4 --------------------------------------- #
#### CHANGE METFILES ***
# path for the ARL format of WRF and GDAS, CANNOT BE TOO LONG ***
met.path <- file.path(homedir, 'u0947337', met)
if (met == 'gdas0p5') met.format <- '%Y%m%d_gdas0p5' # met file convention
met.num <- 1

# path for storing trajec, foot
outdir <- file.path(workdir, 'out')

oco2.path <- NA
if (columnTF) {
  # path for input data, OCO-2 Lite file
  oco2.ver <- c('b7rb', 'b8r')[1]  # OCO-2 version
  oco2.str <- paste0('OCO-2/L2/OCO2_lite_', oco2.ver)
  oco2.path <- file.path(homedir, 'lin-group1/wde/input_data', oco2.str)
}
cat('step 4')

#------------------------------ STEP 5 --------------------------------------- #
#### Set model receptors, AGLs and particel numbers ***
# for backward fixed-level runs OR forward fixed-level runs
# agl can be a vector, meaning releasing particles from several fixed level
# but if trying to represent air column, use columnTF=T, see below

### 1) if release particles from fixed levels
agl <- 10
numpar<- 1000       # par for each time window for forward box runs

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

  # number of points to aggregate within 1deg over small/large enhancements,
  # i.e., over background/enhancements, binwidth will be 1deg/num
  num.bg   <- 20   # e.g., every 20 pts in 1 deg
  num.peak <- 40   # e.g., every 40 pts in 1 deg

  # recp.indx: how to pick receptors from all screened soundings (QF = 0)
  recp.indx <- c(seq(lon.lat[3],  peak.lat[1], 1/num.bg),
                 seq(peak.lat[1], peak.lat[2], 1/num.peak),
                 seq(peak.lat[1], lon.lat[4],  1/num.bg))
} else {recp.indx <- NULL}
cat('step 5')

#------------------------------ STEP 6 --------------------------------------- #
#### Footprint grid settings
## SET spatial domains and resolution for calculating footprints
foot.res <- 1/120  # footprint resolution, 1km for ODIAC

# these variables will determine the numpix.x, numpix.y, lon.ll, lat.ll;
# foot.info <- c(xmn, xmx, ymn, ymx, xres, yres)
#        i.e., c(minlon, maxlon, minlat, maxlat, lon.res, lat.res)
#if (site == 'Riyadh')foot.info <- c(30, 55, 10, 50, 1/120, 1/120)
if (site == 'Riyadh') foot.info <- c(40, 50, 17, 27, rep(foot.res, 2))
if (site == 'Cairo') foot.info <- c(0, 60, 0, 50, rep(foot.res, 2))
if (site == 'PRD') foot.info <- c(10, 50, 20, 130, rep(foot.res, 2))
if (site == 'Jerusalem') foot.info <- c(0, 60, 0, 50, rep(foot.res, 2))

## whether weighted footprint by AK and PW for column simulations
ak.wgt <- NA; pwf.wgt <- NA
if (columnTF) {
  ak.wgt  <- T
  pwf.wgt <- T
}
hnf_plume      <- F  # whether turn on hyper near-field (HNP) for mising hgts
smooth_factor  <- 1  # Gaussian smooth factor
time_integrate <- T  # whether integrate footprint along time
projection     <- '+proj=longlat'

#------------------------------ STEP 7 --------------------------------------- #
#### !!! NO NEED TO CHANGE ANYTHING LISTED BELOW -->
# create a namelist including all variables
# namelist required for generating trajec
nl <- list(agl = agl, ak.wgt = ak.wgt, delt = delt, dpar = dpar, dtime = dtime,
           dxyp = dxyp, errTF = errTF, foot.info = foot.info,
           forwardTF = forwardTF, hnf_plume = hnf_plume, homedir = homedir,
           horcoruverr = horcoruverr, horcorzierr = horcorzierr,
           lon.lat = lon.lat, met.format = met.format, met.num = met.num,
           met.path = met.path, nhrs = nhrs, numpar = numpar, outdir = outdir,
           oco2.path = oco2.path, projection = projection, pwf.wgt = pwf.wgt,
           recp.indx = recp.indx, run_foot = run_foot, run_sim = run_sim,
           run_trajec = run_trajec, selTF = selTF, siguverr = siguverr,
           sigzierr = sigzierr, site = site, smooth_factor = smooth_factor,
           time_integrate = time_integrate, timestr = timestr,
           TLuverr = TLuverr, TLzierr = TLzierr, windowTF = windowTF,
           workdir = workdir, zcoruverr = zcoruverr)

#------------------------------ STEP 8 --------------------------------------- #
## call get.more.namelist() to get more info about receptors
# further read OCO-2 data
# then get receptor info and other info for running trajec
# plotTF for whether plotting OCO-2 observed data
if (forwardTF == F) {

  # whether to subset receptors when debugging
  nl$recp.num <- NULL    # can be a number for max num of receptors

  ## use Ben's algorithm for parallel simulation settings
  n_nodes  <- 7
  n_cores  <- 10
  job.time <- '48:00:00'
  slurm    <- n_nodes > 1

  nl$slurm_options <- list(time = job.time, account = 'lin-kp', partition = 'lin-kp')
  nl <- c(nl, n_cores = n_cores, n_nodes = n_nodes, slurm = slurm)

  # select satellite soundings, plotTF for whether plotting OCO-2 observed XCO2
  nl <- recp.to.namelist(namelist = nl, plotTF = F)
  cat('Done with creating namelist...\n')

  # call run_stilt_mod(), start running trajec and foot
  if (run_trajec | run_foot) run.stilt.mod(namelist = nl)

} else if (forwardTF) {

  ## if for forward time runs and determining backgorund XCO2
  # plotTF for whether plotting urban plume & obs XCO2 if calling forward function
  # !!! if forward, release particles from a box around the city center

  # plotTF for whether to plot the forward urban plume
  cat('Generating forward trajec...\n')
  run.forward.trajec(namelist = nl, plotTF = T)
}  # end if forwardTF

#------------------------------ STEP 9 --------------------------------------- #
# Simulate XCO2.ff using ODIAC emissions, DW, 06/04/2018
## add FFCO2 emissions, e.g., ODIAC
if (run_sim) {

  footpath <- file.path(workdir, 'plot/foot/24hrs_back/100dpar')
  #footpath <- file.path(workdir, 'out', 'footprints')
  footfile <- list.files(footpath, pattern = substr(timestr, 1, 8))

  # call func to match ODIAC emissions with xfoot & sum up to get 'dxco2.ff'
  txtfile <- file.path(workdir, paste0(timestr, '_', site, '_XCO2ff_', dpar,
                       'dpar.txt'))
  xco2.ff <- foot.odiacv2(footpath, footfile, emiss.ext = c(0, 60, 0, 50),
   workdir, timestr, txtfile, storeTF = T, res = foot.res)

}

# end of script
