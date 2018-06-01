# create a namelist for running X-STILT trajectories
# written by DW, 04/18/2018
# latest modification on 05/10/2018
# now build on Ben's STILT-R version 2 codes, DW, 05/23/2018

#### source all functions and load all libraries
# CHANGE working directory ***
homedir <- "/uufs/chpc.utah.edu/common/home"
workdir <- file.path(homedir, "lin-group1/wde/github/XSTILTv2")
setwd(workdir) # move to working directory
source(file.path(workdir, "r/dependencies.r")) # source all functions

#------------------------------ STEP 1 --------------------------------------- #
#### CHOOSE CITIES, TRACKS AND OCO-2 LITE FILE VERSION ***
# one can add other urban regions here
index <- 1
site  <- c("Riyadh", "Cairo", "PRD", "Jerusalem")[index]
met   <- c("1km", "gdas1", "gdas0p5")[3]  # customized WRF, 1 or 0.5deg GDAS
tt    <- 1                                # which track to model
oco2.ver <- c("b7rb","b8r")[2]        # OCO-2 version

#### CHOOSE OVERPASSED TIMESTR ***
# input all track numbers to be modeled, can be YYYYMMDD OR YYYYMMDDHH ***
# track timestr can also be grabbed from another script
riyadh.timestr <- c("20141227", "20141229", "20150128", "20150817", "20151112",
                    "20151216", "20160115", "20160216", "20160725", "20161031")
jerusalem.timestr <- c("20150615", "20150624", "20150717", "20150726",
                       "20160601", "20160610", "20160703", "20160712",
                       "20170417", "20170528", "20170620", "20170629")
cairo.timestr <- c("20150228", "20150318", "20160224"); prd.timestr<- "20150115"

# final timestr, YYYYMMDD and file strings for trajec
track.timestr <- c(riyadh.timestr[tt], cairo.timestr[tt], prd.timestr,
                   jerusalem.timestr[tt])[index]

filestr <- paste(substr(track.timestr,1,4), "x", substr(track.timestr,5,6), "x",
                 substr(track.timestr,7,8), sep="")

# spatial domains placing receptors and city center, help select OCO-2 data ***
# in form of "lat.lon <- c(minlat, maxlat, minlon, maxlon, city.lat, city.lon)"
# oco2.hr for overpass hour in UTC
if(site == "Riyadh"){lat.lon <- c(23, 26, 45, 50, 24.71, 46.75); oco2.hr <- 10}
if(site == "Cairo"){lat.lon <- c(29, 31, 30, 32, NA, NA); oco2.hr <- NA}
if(site == "PRD"){lat.lon <- c(22, 23, 112, 115, NA, NA); oco2.hr <- NA}
if(site == "Jerusalem"){lat.lon <- c(31.75, 32.25, 35, 36, 31.78, 35.22); oco2.hr<-10}
track.timestr <- paste(track.timestr, oco2.hr, sep="")

#------------------------------ STEP 2 --------------------------------------- #
#### TURN ON/OFF FLAGS for XSTILT setups ***
selTF <- F       # true for only use 1-day trajs.
columnTF <- T    # whether a column receptor or fixed receptor
forwardTF <- F   # forward or backward traj, if forward, release from a box
windowTF <- F    # whether to release particles every ?? minutes, "dhr" in hours
uncertTF <- F    # whether add wind error component to generate trajec
overwrite <- T	      # T:rerun hymodelc, even if particle location object found
                      # F:re-use previously calculated particle location object
mpcTF <- T            # true for running trajec on multiple STILT copies
delt <- 2             # fixed timestep [min]; set =0 for dynamic timestep

### change parameters according to above flags
nhrs <- -24           # number of hours backward (-) or forward (+)
if(selTF)nhrs <- -24  # 1day if  selTF

# copy for running trajwind() or trajec()
# can be a vector with values denoting copy numbers
nummodel <- NA
## if release particles from a box
# +/-dxyp, +/-dxyp around the city center
dxyp <- NULL
if(forwardTF){
  dxyp <- 0.2*2
  nummodel <- 997     # use TN's hymodelc to run forward box trajec
  nhrs <- 12          # number of hours backward (-) or forward (+)
}

## if allow for time window for releasing particles
dhr <- NULL; dtime <- NULL
if(windowTF){
  dhr <- 0.5     # release particle every 30 mins
  # FROM 10 hours ahead of sounding hour (-10), TO sounding hour (0)
  dtime <- seq(-10, 0, dhr)
  cat("Release particles", dtime[1], "hrs ahead & every", dhr * 60, "mins...\n")
}

#### obtaining wind errors, transport error component
# SD in wind errors, correlation timescale, horizontal and vertical lengthscales
if(uncertTF){
  cat("Using wind error component...\n")

  # intput correlation lengthscale (in m) and timescales (in mins) ***
  if(met == "gdas0p5"){TLuverr <- 1*60; zcoruverr <- 600; horcoruverr <- 40}
  if(met == "gdas1"){TLuverr <- 2.4*60; zcoruverr <- 700; horcoruverr <- 97}

  ## add errors, mainly siguverr, create a subroutine to compute siguverr
  # from model-data wind comparisons
  errpath <- file.path(homedir,"lin-group1/wde/STILT_input/wind_err")
  errpath <- file.path(errpath, tolower(site), tolower(met))

  # call get.SIGUVERR() to interpolate most near-field wind errors
  err.info <- get.SIGUVERR(site=site, timestr=track.timestr, gdaspath=errpath,
                           nfTF=FALSE,forwardTF=F)

  # if no wind error found, return NA for err.info
  # make a conservative assumption about the wind error, for the Middle East
  if(length(err.info)!=2){siguverr <- 1.8}

  met.rad <- err.info[[1]]
  siguverr <- as.numeric(err.info[[2]][1])
  u.bias <- as.numeric(err.info[[2]][2])
  v.bias <- as.numeric(err.info[[2]][3])

  cat(paste("SIGUVERR:", signif(siguverr,3), "m/s..\n"))
  cat(paste("u.bias:", signif(u.bias,3), "\n"))
  cat(paste("v.bias:", signif(u.bias,3), "\n"))

}else{

  cat("NOT using wind error component...\n")
  siguverr <- NA; TLuverr <- NA; horcoruverr <- NA; zcoruverr <- NA
  sigzierr <- NA; TLzierr <- NA; horcorzierr <- NA
}

#------------------------------ STEP 3 --------------------------------------- #
# path for input data, OCO-2 Lite file
ocostr   <- paste("OCO-2/OCO2_lite_", oco2.ver, sep="")
ocopath  <- file.path(homedir, "lin-group1/wde/STILT_input", ocostr)

#### CHANGE METFILES ***
# path for the ARL format of WRF and GDAS, CANNOT BE TOO LONG ***
metpath <- file.path(homedir, "u0947337", "GDAS0p5")

# get metfile for generating backward trajectories
# met.format: met file convention, e.g., "%Y%m%d_gdas0p5"
met.format <- "%Y%m%d_gdas0p5"

#source(file.path(workdir, "src/sourceall.r"))  # source all functions
#metfile <- find.metfile(timestr=track.timestr, nhrs=nhrs, metpath=metpath,
#                        met.format=met.format)

# Where to run STILT, where Copy lies
#rundir <- file.path(homedir, "lin-group1/wde/STILT_modeling/STILT_Exe/")

#------------------------------ STEP 4 --------------------------------------- #
#### Set model receptors, AGLs and particel numbers ***
### 1) if release particles from fixed levels
# for backward fixed-level runs OR forward fixed-level runs
# agl can be a vector, meaning releasing particles from several fixed level
# but if trying to represent air column, use columnTF=T, see below

agl <- 10
npar<- 1000            # par for each time window for forward box runs
minagl <- NA; maxagl <- NA; midagl <- NA; dh <- NA; dpar <- NA

#### 2) SET COLUMN RECEPTORS, using vector form ***
 # if release particles from a column
if(columnTF){

  # INPUT min, max heights and dh for STILT levels, in METERS
  minagl <- 0; maxagl <- 6000; midagl <- 3000

  # vertical spacing below and above cutoff level, in METERS
  dh <- c(100, 500)
  dpar <- 100           # particle numbers per level
  agl <- list(c(seq(minagl, midagl, dh[1]), seq(midagl+dh[2], maxagl, dh[2])))
  nlev <- length(unlist(agl))
  npar <- nlev * dpar   # total number of particles
}

## eyeball lat range for enhanced XCO2, or grab from available forward-time runs
# place denser receptors during this lat range (40pts in 1deg)
filterTF <- T  # whether select receptors; or simulate all soundings
if(site=="Riyadh")peak.lat <- c(24.5, 25)  # in deg N, required for backward run
if(site=="Jerusalem")peak.lat <- c(31.75, 32.25)
bw.bg <- 1/20    # binwidth over small enhancements, e.g., every 20 pts in 1deg
bw.peak <- 1/100  # binwidth over large enhancements, during "peak.lat"

# recp.index: how to pick receptors from soundings
recp.index <- c(seq(lat.lon[1], peak.lat[1], bw.bg),
                seq(peak.lat[1], peak.lat[2], bw.peak),
                seq(peak.lat[1], lat.lon[2], bw.bg))

# instead of using allocate.receptors(), route to Ben's codes
# Parallel simulation settings
n_cores <- 12
n_nodes <- 6
slurm   <- n_nodes > 1
slurm_options <- list(
  time      = '48:00:00',
  account   = 'lin-kp',
  partition = 'lin-kp'
)

#------------------------------ STEP 5 --------------------------------------- #
# whether weighted footprint by AK and PW
ak.wgt <- T
pw.wgt <- T

# Footprint grid settings
#### SET spatial domains for generating footprints or grabbing ODIAC emissions,
# these variables will determine the numpix.x, numpix.y, lon.ll, lat.ll;
# foot.info <- c(xmn, xmx, ymn, ymx, xres, yres)
#     which is c(minlon, maxlon, minlat, maxlat, lon.res, lat.res)
#if(site == "Riyadh")foot.info <- c(30, 55, 10, 50, 1/120, 1/120)
if(site == "Riyadh")foot.info <- c(40, 50, 20, 30, 1/120, 1/120)
if(site == "Cairo")foot.info <- c(0, 60, 0, 50, 1/120, 1/120)
if(site == "PRD")foot.info <- c(10, 50, 20, 130, 1/120, 1/120)
if(site == "Jerusalem")foot.info <- c(0, 60, 0, 50, 1/120, 1/120)
print(foot.info)

hnf_plume <- T
smooth_factor <- 1
time_integrate <- T

#------------------------------ STEP 6 --------------------------------------- #
#### !!! NO NEED TO CHANGE ANYTHING LISTED BELOW -->
# create a namelist including all variables
# namelist required for generating trajec
namelist <- list(site = site, timestr = track.timestr, filestr = filestr,
                 lat.lon = lat.lon, oco2.version = oco2.ver, ocopath = ocopath,
                 oco2.hr = oco2.hr, met = met, met.format = met.format,
                 met.path = metpath, homedir = homedir, workdir = workdir,
                 nummodel = nummodel, nhrs = nhrs, delt = delt, selTF = selTF,
                 overwrite = overwrite, columnTF = columnTF,
                 filterTF = filterTF, uncertTF = uncertTF, windowTF = windowTF,
                 forwardTF = forwardTF, agl = agl, dpar = dpar, npar = npar,
                 dxyp = dxyp, dtime = dtime,
                 siguverr = siguverr, sigzierr = sigzierr, TLuverr = TLuverr,
                 TLzierr = TLzierr, zcoruverr = zcoruverr,
                 horcoruverr = horcoruverr, horcorzierr = horcorzierr,
                 recp.index = recp.index, slurm = slurm, n_cores = n_cores,
                 n_nodes = n_nodes, slurm_options = slurm_options,
                 ak.wgt = ak.wgt, pw.wgt = pw.wgt,
                 foot.info = foot.info, hnf_plume = hnf_plume,
                 smooth_factor = smooth_factor, time_integrate = time_integrate)

#------------------------------ STEP 7 --------------------------------------- #
## call get.more.namelist() to get more info about receptors
# further read OCO-2 data
# then get receptor info and other info for running trajec
# plotTF for whether plotting OCO-2 observed data
if (forwardTF == F) {

  namelist <- get.more.namelist(namelist = namelist, plotTF = F)
  cat("Done with creating namelist...\n")

  source(file.path(workdir, "r/dependencies.r")) # source all functions
  run_stilt(namelist)  # call run_stilt()
}

# if for forward time runs and determining backgorund XCO2
# plotTF for whether plotting urban plume & obs XCO2 if calling forward function
# !!! if forward, release particles from a box around the city center
if (forwardTF == T) {
  cat("Generating forward trajec...\n")

  # store namelist to output directory
  filenm <- paste("trajlist_", site, "_", track.timestr, sep="")
  filenm <- paste(filenm, "_forward.txt", sep="")
  filenm <- file.path(outpath, filenm)  # link to path
  write.table(x=t(namelist), file=filenm, sep="\n", col.names=F, quote=T)

  source(file.path(workdir, "src/sourceall.r"))  # source all functions
  forw.info <- run.forward.trajec(namelist = namelist, plotTF=T)
}

# end of running trajec
