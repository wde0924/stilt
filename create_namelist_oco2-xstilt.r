# create a namelist for running X-STILT trajectories
# written by DW, 04/18/2018
# latest modification on 05/10/2018
# now build on Ben's STILT-R version 2 codes, DW, 05/23/2018

#### source all functions and load all libraries
# CHANGE working directory ***
homedir <- '/uufs/chpc.utah.edu/common/home'
workdir <- file.path(homedir, 'lin-group1/wde/github/stilt')

setwd(workdir) # move to working directory
source('r/dependencies.r') # source all functions

#------------------------------ STEP 1 --------------------------------------- #
#### CHOOSE CITIES, TRACKS AND OCO-2 LITE FILE VERSION ***
# one can add other urban regions here
indx  <- 1
site  <- c('Riyadh', 'Cairo', 'PRD', 'Jerusalem')[indx]
met   <- c('1km', 'gdas1', 'gdas0p5')[3]  # customized WRF, 1 or 0.5deg GDAS
tt    <- 1                                # which track to model
oco2.ver <- c('b7rb','b8r')[2]            # OCO-2 version

#### CHOOSE OVERPASSED TIMESTR ***
# input all track numbers to be modeled, can be YYYYMMDD OR YYYYMMDDHH ***
# track timestr can also be grabbed from another script
riyadh.timestr <- c('20141227', '20141229', '20150128', '20150817', '20151112',
                    '20151216', '20160115', '20160216', '20160725', '20161031')
jerusalem.timestr <- c('20150615', '20150624', '20150717', '20150726',
                       '20160601', '20160610', '20160703', '20160712',
                       '20170417', '20170528', '20170620', '20170629')
cairo.timestr <- c('20150228', '20150318', '20160224')
prd.timestr   <- '20150115'

# final timestr, YYYYMMDD and file strings for trajec
track.timestr <- c(riyadh.timestr[tt], cairo.timestr[tt], prd.timestr,
                   jerusalem.timestr[tt])[indx]

# spatial domains placing receptors and city center, help select OCO-2 data ***
# in form of 'lat.lon <- c(minlon, maxlon, minlat, maxlat, city.lat, city.lon)'
if(site == 'Riyadh'){lat.lon <- c(45, 50, 23, 26, 24.71, 46.75); oco2.hr <- 10}
if(site == 'Cairo'){lat.lon <- c(30, 32, 29, 31, NA, NA); oco2.hr <- 10}
if(site == 'PRD'){lat.lon <- c(112, 115, 22, 23, NA, NA); oco2.hr <- 05}
if(site == 'Jerusalem'){lat.lon <- c(35, 36, 31.75, 32.25, 31.78, 35.22);
                        oco2.hr<-10}
track.timestr <- paste0(track.timestr, oco2.hr)

#------------------------------ STEP 2 --------------------------------------- #
#### Whether forward/backward, release from a column or a box
columnTF  <- T    # whether a column receptor or fixed receptor
forwardTF <- F    # forward or backward traj, if forward, release from a box
windowTF  <- F    # whether to release particles every ?? minutes,'dhr' in hours
overwrite <- F	  # T:rerun hymodelc, even if particle location object found
                  # F:re-use previously calculated particle location object
delt      <- 2    # fixed timestep [min]; set = 0 for dynamic timestep
nhrs      <- -24  # number of hours backward (-) or forward (+)

# copy for running trajwind() or trajec()
# can be a vector with values denoting copy numbers
nummodel <- NA

## if release particles from a box, +/-dxyp, +/-dxyp around the city center
dxyp <- NA
if (forwardTF) {
  dxyp <- 0.2*2
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
  if(met == 'gdas0p5'){TLuverr <- 1*60; zcoruverr <- 600; horcoruverr <- 40}
  if(met == 'gdas1'){TLuverr <- 2.4*60; zcoruverr <- 700; horcoruverr <- 97}

  ## add errors, mainly siguverr, create a subroutine to compute siguverr
  # from model-data wind comparisons
  errpath <- file.path(homedir, 'lin-group1/wde/STILT_input/wind_err')
  errpath <- file.path(errpath, tolower(site), tolower(met))

  # call get.SIGUVERR() to interpolate most near-field wind errors
  err.info <- get.siguverr(site = site, forwardTF = F, gdaspath = errpath,
                           nfTF = F, timestr = track.timestr)

  if (is.null(err.info)) {
    cat('no wind error found; make consevative assumption of siguverr...\n')
    # make a conservative assumption about the wind error, for the Middle East
    siguverr <- 1.8  # < 2 m/s for GDAS 1deg, based on Wu et al., submitted

  } else {
    #met.rad  <- err.info[[1]]
    siguverr <- as.numeric(err.info[[2]][1])    # SD in wind errors
    u.bias <- as.numeric(err.info[[2]][2])
    v.bias <- as.numeric(err.info[[2]][3])

    cat(paste('u.bias:', signif(u.bias,3), 'm s-1;
               v.bias:', signif(u.bias,3), 'm s-1...\n'))
  }  # end if is.null(err.info)

  cat(paste('SIGUVERR:', signif(siguverr,3), 'm/s..\n'))

} else {
  cat('NO wind error component for generating trajec...\n')
  siguverr <- NA; TLuverr <- NA; horcoruverr <- NA; zcoruverr <- NA
  sigzierr <- NA; TLzierr <- NA; horcorzierr <- NA
}  # end if errTF

#------------------------------ STEP 4 --------------------------------------- #
# path for input data, OCO-2 Lite file
oco2.str   <- paste('OCO-2/OCO2_lite_', oco2.ver, sep='')
oco2.path  <- file.path(homedir, 'lin-group1/wde/STILT_input', oco2.str)

#### CHANGE METFILES ***
# path for the ARL format of WRF and GDAS, CANNOT BE TOO LONG ***
met.path <- file.path(homedir, 'u0947337', met)
if(met == 'gdas0p5')met.format <- '%Y%m%d_gdas0p5' # met file convention
met.num <- 1

#------------------------------ STEP 5 --------------------------------------- #
#### Set model receptors, AGLs and particel numbers ***
# for backward fixed-level runs OR forward fixed-level runs
# agl can be a vector, meaning releasing particles from several fixed level
# but if trying to represent air column, use columnTF=T, see below

### 1) if release particles from fixed levels
agl <- 10; npar<- 1000       # par for each time window for forward box runs
minagl <- NA; maxagl <- NA; midagl <- NA; dh <- NA; dpar <- NA

### 2) SET COLUMN RECEPTORS as a list, if release particles from a column
if (columnTF) {

  # min, middle, max heights for STILT levels, in METERS
  minagl <- 0; maxagl <- 6000; midagl <- 3000

  # vertical spacing below and above cutoff level, in METERS
  dh   <- c(100, 500)
  agl  <- list(c(seq(minagl, midagl, dh[1]), seq(midagl+dh[2], maxagl, dh[2])))
  nlev <- length(unlist(agl))
  dpar <- 100           # particle numbers per level
  npar <- nlev * dpar   # total number of particles
}

## eyeball lat range for enhanced XCO2, or grab from available forward-time runs
# place denser receptors during this lat range (40pts in 1deg)
filterTF <- T  # whether select receptors; or simulate all soundings

# lat range in deg N for placing denser receptors, required for backward run
if(site == 'Riyadh')peak.lat <- c(24.5, 25)
if(site == 'Jerusalem')peak.lat <- c(31.75, 32.25)

# binwidth over small/large enhancements (i.e., over background/enhancements)
bw.bg <- 1/20     # e.g., every 20 pts in 1 deg
bw.peak <- 1/100  # e.g., every 100 pts in 1 deg

# recp.indx: how to pick receptors from soundings
recp.indx <- c(seq(lat.lon[3], peak.lat[1], bw.bg),
               seq(peak.lat[1], peak.lat[2], bw.peak),
               seq(peak.lat[1], lat.lon[4], bw.bg))

#------------------------------ STEP 6 --------------------------------------- #
#### Footprint grid settings
## whether weighted footprint by AK and PW
ak.wgt <- T
pwf.wgt <- T

## SET spatial domains for generating footprints or grabbing ODIAC emissions,
# these variables will determine the numpix.x, numpix.y, lon.ll, lat.ll;
# foot.info <- c(xmn, xmx, ymn, ymx, xres, yres)
#        i.e., c(minlon, maxlon, minlat, maxlat, lon.res, lat.res)
#if(site == 'Riyadh')foot.info <- c(30, 55, 10, 50, 1/120, 1/120)
if(site == 'Riyadh') foot.info <- c(40, 50, 20, 30, 1/120, 1/120)
if(site == 'Cairo') foot.info <- c(0, 60, 0, 50, 1/120, 1/120)
if(site == 'PRD') foot.info <- c(10, 50, 20, 130, 1/120, 1/120)
if(site == 'Jerusalem') foot.info <- c(0, 60, 0, 50, 1/120, 1/120)

hnf_plume      <- T  # whether turn on hyper near-field (HNP) for mising hgts
smooth_factor  <- 1  # Gaussian smooth factor
time_integrate <- T  # whether integrate footprint along time
projection     <- '+proj=longlat'

#------------------------------ STEP 7 --------------------------------------- #
#### !!! NO NEED TO CHANGE ANYTHING LISTED BELOW -->
# create a namelist including all variables
# namelist required for generating trajec
namelist <- list(agl = agl, ak.wgt = ak.wgt, delt = delt, dpar = dpar,
                 dtime = dtime, dxyp = dxyp, errTF = errTF, filterTF = filterTF,
                 foot.info = foot.info, forwardTF = forwardTF,
                 hnf_plume = hnf_plume, homedir = homedir,
                 horcoruverr = horcoruverr, horcorzierr = horcorzierr,
                 lat.lon = lat.lon, met.format = met.format, met.num = met.num,
                 met.path = met.path, nhrs = nhrs, npar = npar,
                 oco2.path = oco2.path, oco2.ver = oco2.ver,
                 overwrite = overwrite, projection = projection,
                 pwf.wgt = pwf.wgt, recp.indx = recp.indx, siguverr = siguverr,
                 sigzierr = sigzierr, site = site,
                 smooth_factor = smooth_factor, timestr = track.timestr,
                 time_integrate = time_integrate, TLuverr = TLuverr,
                 TLzierr = TLzierr, windowTF = windowTF, workdir = workdir,
                 zcoruverr = zcoruverr)

#------------------------------ STEP 7 --------------------------------------- #
## call get.more.namelist() to get more info about receptors
# further read OCO-2 data
# then get receptor info and other info for running trajec
# plotTF for whether plotting OCO-2 observed data
if (forwardTF == F) {

  # whether to run just few receptors when debugging, num of receptors
  recp.num <- NULL

  # use Ben's algorithm for parallel simulation settings
  n_nodes <- 6
  n_cores <- 12
  slurm <- n_nodes > 1
  namelist$slurm_options <- list(time = '48:00:00',
                                 account = 'lin-kp', partition = 'lin-kp')
  namelist <- c(namelist, n_cores = n_cores, n_nodes = n_nodes, slurm = slurm)

  # select satellite soundings--
  namelist <- recp.to.namelist(namelist, recp.num, plotTF = F)

  cat('Done with creating namelist...\n')
  run.stilt.mod(namelist)  # call run_stilt_mod()
}

## if for forward time runs and determining backgorund XCO2
# plotTF for whether plotting urban plume & obs XCO2 if calling forward function
# !!! if forward, release particles from a box around the city center
if (forwardTF == T) {
  cat('Generating forward trajec...\n')

  # store namelist to output directory
  filenm <- paste('trajlist_', site, '_', track.timestr, sep='')
  filenm <- paste(filenm, '_forward.txt', sep='')
  filenm <- file.path(outpath, filenm)  # link to path
  write.table(x=t(namelist), file=filenm, sep='\n', col.names=F, quote=T)

  source(file.path(workdir, 'src/sourceall.r'))  # source all functions
  forw.info <- run.forward.trajec(namelist = namelist, plotTF=T)
}

# end of running trajec
