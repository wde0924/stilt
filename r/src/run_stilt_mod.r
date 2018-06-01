# STILT R Executable
# For documentation, see https://uataq.github.io/stilt/
# Ben Fasoli

# rewrite this code as a subroutine for X-STILT's purposes, DW, 05/23/2018

run_stilt <- function(namelist){

  # User inputs ----------------------------------------------------------------
  stilt_wd <- namelist$workdir
  output_wd <- file.path(stilt_wd, 'out')
  lib.loc <- .libPaths()[1]

  # modification if length(agl) > 1, DW, 05/24/2018
  # Initialize several variables for regular fixed run
  ak.wgt <- NA; pw.wgt <- NA; oco2.path <- NA; oco2.ver <- NA

  recp <- namelist$recp.info
  colTF <- length(recp$zagl) > 1
  if(colTF) {  # if release trajec from a column
    ak.wgt    <- namelist$ak.wgt  # whether weighted foot by averaging kernel
    pw.wgt    <- namelist$pw.wgt  # whether weighted foot by pres weighting
    oco2.path <- namelist$ocopath
    oco2.ver  <- namelist$oco2.ver
  }

  #recp <- recp[1, ]

  # Model control
  run_trajec <- namelist$overwrite
  n_hours    <- namelist$nhrs
  convect    <- namelist$convect
  delt       <- namelist$delt
  numpar     <- namelist$npar
  outdt      <- 0
  rm_dat     <- T
  timeout    <- 3600
  varsiwant  <- namelist$varstrajec

  if(length(varsiwant) == 0) {
    varsiwant  <- c('time', 'indx', 'long', 'lati', 'zagl', 'sigw', 'tlgr',
                    'zsfc', 'icdx', 'temp', 'samt', 'foot', 'shtf', 'tcld',
                    'dmas', 'dens', 'rhfr', 'sphu', 'solw', 'lcld', 'zloc',
                    'dswf', 'wout', 'mlht', 'rain', 'crai', 'pres')
  }

  # Transport error
  horcoruverr <- namelist$horcoruverr
  horcorzierr <- namelist$horcorzierr
  siguverr    <- namelist$siguverr
  sigzierr    <- namelist$sigzierr
  tluverr     <- namelist$TLuverr
  tlzierr     <- namelist$TLzierr
  zcoruverr   <- namelist$zcoruverr

  # Footprint grid settings
  xmn            <- namelist$foot.info[1]
  xmx            <- namelist$foot.info[2]
  ymn            <- namelist$foot.info[3]
  ymx            <- namelist$foot.info[4]
  xres           <- namelist$foot.info[5]
  yres           <- namelist$foot.info[6]
  hnf_plume      <- namelist$hnf_plume
  smooth_factor  <- namelist$smooth_factor
  time_integrate <- namelist$time_integrate

  # Transport and dispersion settings
  emisshrs    <- 0.01
  iconvect    <- 0
  isot        <- 0
  khmax       <- 9999
  kmix0       <- 250
  kmixd       <- 3
  krnd        <- 6
  mgmin       <- namelist$mgmin
  ndump       <- 0
  nturb       <- 0
  outfrac     <- 0.9
  random      <- 1
  tlfrac      <- 0.1
  tratio      <- 0.9
  veght       <- namelist$veght
  w_option    <- 0
  zicontroltf <- 0
  z_top       <- 25000

  # Parallel simulation settings
  slurm         <- namelist$slurm
  n_cores       <- namelist$n_cores
  n_nodes       <- namelist$n_nodes
  slurm_options <- namelist$slurm_options

  # Startup messages -----------------------------------------------------------
  message('Initializing STILT')
  message('Number of recp: ', nrow(recp))
  message('Number of parallel threads: ', n_nodes * n_cores)

  # modify for time_integrate == T, no hourly footprint for monthly mean ODIAC
  #if (time_integrate) {
  #  grd <- array(dim = c((xmx - xmn) / xres, (ymx - ymn) / yres, 1))
  #} else{
  grd <- array(dim = c((xmx - xmn) / xres, (ymx - ymn) / yres, abs(n_hours) * 60))
  #}
  ram <- format(object.size(grd) * 2.0, units = 'MB', standard = 'SI')
  message('Estimated footprint grid RAM allocation: ', ram)

  # Source dependencies --------------------------------------------------------
  setwd(stilt_wd)
  source('r/dependencies.r')

  # Structure out directory ----------------------------------------------------
  d <- file.path('out')
  if(!file.exists(d))dir.create(d)

  # Outputs are organized in three formats. by-id contains simulation files by
  # unique simulation identifier. particles and footprints contain symbolic
  # links to the particle trajectory and footprint files in by-id
  system('rm -r out/footprints', ignore.stderr = T)
  if (run_trajec) {
    system('rm -r out/by-id', ignore.stderr = T)
    system('rm -r out/particles', ignore.stderr = T)
  }

  for (d in c('by-id', 'particles', 'footprints')) {
    d <- file.path('out', d)
    if (!file.exists(d))dir.create(d)
  }

  # Met path symlink -----------------------------------------------------------
  met_directory   <- namelist$met.path
  met_file_format <- namelist$met.format

  # Auto symlink the meteorological data path to the working directory to
  # eliminate issues with long (>80 char) paths in fortran. Note that this
  # assumes that all meteorological data is found in the same directory.
  if ((nchar(paste0(met_directory, met_file_format)) + 2) > 80) {
    met_loc <- file.path(path.expand('~'), paste0('m', project))
    if (!file.exists(met_loc)) invisible(file.symlink(met_directory, met_loc))
  } else met_loc <- met_directory


  # Run trajectory simulations -------------------------------------------------
  # Gather varsiwant into a single character string and fork the process to
  # apply simulation_step() to each receptor across n_cores and n_nodes
  validate_varsiwant(varsiwant)
  if (!is.null(varsiwant[1]))
    varsiwant <- paste(varsiwant, collapse = '/')

  # add few variables for column release levels by Dien Wu, 05/24/2018
  source('r/dependencies.r')
  output <- stilt_apply(X = 1:nrow(recp), FUN = simulation_step, colTF = colTF,
                        delt = delt, emisshrs = emisshrs, hnf_plume = hnf_plume,
                        horcoruverr = horcoruverr, horcorzierr = horcorzierr,
                        iconvect = iconvect, isot = isot, khmax = khmax,
                        kmix0 = kmix0, kmixd = kmixd, krnd = krnd,
                        lib.loc = lib.loc, met_file_format = met_file_format,
                        met_loc = met_loc, mgmin = mgmin, n_hours = n_hours,
                        ndump = ndump, nturb = nturb, numpar = numpar,
                        n_cores = n_cores, n_nodes = n_nodes, outdt = outdt,
                        outfrac = outfrac,
                        oco2.path = oco2.path, oco2.ver = oco2.ver,
                        run_trajec = run_trajec, r_run_time = recp$run_time,
                        r_lati = recp$lati, r_long = recp$long,
                        r_zagl = recp$zagl, random = random, rm_dat = rm_dat,
                        slurm = slurm, slurm_options = slurm_options,
                        siguverr = siguverr, sigzierr = sigzierr,
                        smooth_factor = smooth_factor, stilt_wd = stilt_wd,
                        time_integrate = time_integrate, timeout = timeout,
                        tlfrac = tlfrac, tluverr = tluverr, tlzierr = tlzierr,
                        tratio = tratio, varsiwant = varsiwant, veght = veght,
                        w_option = w_option, xmn = xmn, xmx = xmx, xres = xres,
                        ymn = ymn, ymx = ymx, yres = yres, z_top = z_top,
                        zicontroltf = zicontroltf, zcoruverr = zcoruverr,
                        ak.wgt = ak.wgt, pw.wgt = pw.wgt)

  #q('no')

}
