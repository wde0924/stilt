---
layout: docs
title: STILT Controls
---

# Controls

The following parameters are found in `r/run_stilt.r` and are used to configure STILT. These settings are used to adjust model parameters, execute parallelized simulations, and calculate produce upstream influence footprints.

### System configuration

Arg       | Description
----------|-------------------------------------------------------------------------
`project` | Project name
`stilt_wd`| Working directory for the given project
`lib.loc` | Path to R package installations, passed to `library()`

### Parallel simulation settings

Arg       | Description
----------|-------------------------------------------------------------------------
`n_nodes` | If using SLURM for job submission, number of nodes to utilize
`n_cores` | Number of cores per node to parallelize simulations by receptor locations and times
`slurm`   | Logical indicating the use of rSLURM to submit job(s)
`slurm_options` | Named list of options passed to `sbatch` using `rslurm::slurm_apply()`, which typically includes `time`, `account`, and `partition` values

### Simulation timing

Arg               | Description
------------------|-------------------------------------------------------------------------
`t_start/t_end`   | Simulation timing, formatted as `'yyyy-mm-dd HH:MM:SS'` UTC
`run_times`       | Hourly simulations spanning `t_start` through `t_end` of length *n*

### Receptor locations

Arg               | Description
------------------|-------------------------------------------------------------------------
`lati`            | Receptor latitude(s), in degrees. Can be a single value or a vector of length *n*
`long`            | Receptor longitude(s), in degrees. Can be a single value or a vector of length *n*
`zagl`            | Receptor height(s), in meters above ground level. Can be a single value or a vector of length *n*

> Simulation timing and receptor locations are defined in this way for convenience and then expanded to contain the unique receptors in a *x*, *y*, *z*, *t* table. To specify the receptors manually with this format, a data frame can be created with column names `run_time` (POSIXct), `long` (double), `lati` (double), and `zagl` (double).

<div class="terminal">
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-command">
    str(receptors)
  </div>
  <div class="terminal-return">
    'data.frame':	100 obs. of  4 variables:<br>
      $ run_time: POSIXct, format: "2015-07-02 11:00:00" "2015-07-02 11:00:00" ...<br>
      $ long    : num  -112 -112 -112 -112 -112 ...<br>
      $ lati    : num  40.8 40.8 40.8 40.8 40.8 ...<br>
      $ zagl    : num  5 5 5 5 5 5 5 5 5 5 ...
  </div>
</div>

### Meteorological data input

Arg               | Description
------------------|-------------------------------------------------------------------------
`met_directory`   | Full directory path in which ARL compatible meteorological data files can be found
`met_file_format` | `strftime()` compatible file naming convention to identify meteorological data files necessary for the timing of the simulation, such as `%Y%m%d.%Hz.hrrra`. Also accepts wildcards that match regular expression patterns passed to `dir()`, such as `wrfout_d0*_jul.arl`
`n_met_min`       | Minimum number of meteorological data files with which to proceed with simulation. Useful for capturing missing periods. For a -24 hour simulation using the 6 hour HRRR met data files, `n_met_min` should be set to 5, since `find_met_files()` ensures that data before and after the simulation is included.

> NOAA publishes High Resolution Rapid Refresh (HRRR) mesoscale model data in the ARL packed format required for STILT at [ftp://arlftp.arlhq.noaa.gov/pub/archives/hrrr/](ftp://arlftp.arlhq.noaa.gov/pub/archives/hrrr/). This is often the easiest place to start but is only available after June 15, 2015. The coupling of the popular Weather Research and Forecasting (WRF) model with STILT is well documented by [Nehrkorn, 2010](https://link.springer.com/article/10.1007%2Fs00703-010-0068-x).

### Model control

Arg             | Description
----------------|-------------------------------------------------------------------------
`delt` | integration timestep [min]; if set to 0.0, then timestep is dynamically determined
`n_hours` | Number of hours to run each simulation; negative indicates backward in time
`numpar` | number of particles to be run; defaults to 200
`outdt` | interval [min] to output data to PARTICLE.DAT; defaults to 0.0, which outputs at every timestep
`rm_dat`  | Logical indicating whether to delete `PARTICLE.DAT` after each simulation. Default to TRUE to reduce disk space since all of the trajectory information is also stored in `STILT_OUTPUT.rds` alongside the calculated upstream influence footprint
`run_trajec` | Logical indicating whether to produce new trajectories with `hymodelc`. If FALSE, will try to load the previous trajectory outputs. This is often useful for regridding purposes
`timeout` | number of seconds to allow hymodelc to complete before sending SIGTERM and moving to the next simulation; defaults to 3600 (1 hour)
`varsiwant` | character vector of 4-letter hymodelc variables. Options include `NULL` for all variables, or a vector containing a minimum of `c('time', 'indx', 'lati', 'long', 'zagl', 'foot')` and optionally containing `'sigw', 'tlgr', 'zsfc', 'icdx', 'temp', 'samt', 'shtf', 'tcld', 'dmas', 'dens', 'rhfr', 'sphu', 'solw', 'lcld', 'zloc', 'dswf', 'wout', 'mlht', 'rain', or 'crai'`

### Footprint gridding

Arg             | Description
----------------|-------------------------------------------------------------------------
`xmn` | grid start longitude, in degrees from -180 to 180
`xmx` | grid end longitude, in degrees from -180 to 180
`ymn` | grid start latitude, in degrees from -180 to 180
`ymx` | grid end latitude, in degrees from -180 to 180
`xres` | resolution for longitude grid, in degrees
`yres` | resolution for latitude grid, in degrees
`hnf_plume` | logical indicating whether to apply a vertical gaussian plume model to rescale the effective dilution depth for particles in the hyper near-field. This acts to scale up the influence of hyper-local fluxes on the receptor. Defaults to TRUE
`smooth_factor` | factor by which to linearly scale footprint smoothing; 0 to disable all smoothing, defaults to 1
`time_integrate` | logical indicating whether to integrate footprint over time or retain discrete hourly time steps in footprint output

### Transport and dispersion

Arg             | Description
----------------|-------------------------------------------------------------------------
`iconvect` | flag for convection. If set to 1, then runs excessive convection as described in Gerbig et al., 2003. For specialized RAMS output, the particles will be vertically redistributed according to the output convective mass fluxes; defaults to 0
`isot` | flag used to set the isotropic turbulence option; defaults to 0 to compute horizontal turbulence from wind field deformation. Setting to 1 results in the horizontal turbulence to be the same in both the u and v directions
`khmax` | max age a particle is allowed to attain; defaults to 9999
`kmix0` | minimum mixing depth (abs(kmix0) is used as the minimum mixing depth), negative values are used to force mixing heights coincident with model levels; defaults to 250
`kmixd` | PBL height computation: compute from bulk Ri profile (but see zicontroltf); defaults to 3
`krnd` | at this interval in hrs, enhanced puff merging occurs; defaults to 6
`mgmin` | determines the size of the sub domain, set >1000 when working with high-res WRF-ARW met fields
`ndump` | flag to dump all particle/puff points at the end of a simulation to a file called PARDUMP. This can be read at the start of a new simulation to continue the previous calculation. Valid settings include 0 (no i/o), 1 (read/write), 2 (read only), 3 (write only); defaults to 0
`nturb` | no turbulence flag; defaults to 0, which includes turbulence rather than simulating mean trajectories
`outfrac` | the fraction of the particles that are allowed to leave the model domain (given by met data); defaults to 0.9. If exceeded, the model stops
`random` | flag that tells the random number generator whether to have a different random sequence for each model run (0 - false, 1 - true); defaults to 1
`tlfrac` | the fraction of the lagrangian timescale TL to set as timestep in dispersion subroutine. The smaller this fraction is, the more finely the turbulence is resolved; defaults to 0.1
`tratio` | maximum fraction of gridcell to be travelled by a particle in a single integration timestep. This determines the timestep if DELT is set to be dynamic
`veght` | height below which a particle's time spent is tallied; defaults to 0.5, which specifies half of the PBL. Setting <=1.0 specifies a fraction of the boundary layer height, and setting >1.0 specifies a height above ground in meters
`w_option` | vertical motion calculation method. 0: use vertical velocity from data, 1: isob, 2: isen, 3: dens, 4: sigma; defaults to 0
`z_top` | top of model domain, in meters above ground level; defaults to 25000.0
`zicontroltf` | flag that specifies whether to scale the PBL heights in STILT uniformly in the entire model domain; defaults to 0. If set to 1, then STILT looks for a file called "ZICONTROL" that specifies the scaling for the PBL height. The first line indicates the number of hours that the PBL height will be changed, and each subsequent line indicates the scaling factor for that hour

### Transport error calculations

Arg             | Description
----------------|-------------------------------------------------------------------------
`siguverr` | standard deviation of horizontal wind errors [m/s]
`tluverr` | standard deviation of horizontal wind error timescale [min]
`zcoruverr` | vertical correlation lengthscale [m]
`horcoruverr` | horizontal correlation lengthscale [km]
`sigzierr` | standard deviation of mixed layer height errors [%]
`tlzierr` | standard deviation of mixed layer height timescale [min]
`horcorzierr` | horizontal correlation lengthscale of mixed layer height errors [km]
