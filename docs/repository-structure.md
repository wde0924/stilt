---
layout: docs
---

# Structure

The repository contains a number of directories that serve as the framework for the model. Initially, only the `r/` and `fortran/` directories are fully populated.

```sh
exe/
  hymodelc
  ...
fortran/
  ...
out/
  by-id/
    yyyymmddHH_lati_long_zagl/
      yyyymmddHH_lati_long_zagl_traj.rds
      yyyymmddHH_lati_long_zagl_foot.nc
      hymodelc
      SETUP.CFG
      CONTROL
      ...
    ...
  footprints/
    yyyymmddHH_lati_long_zagl_foot.nc
    ...
  particles/
    yyyymmddHH_lati_long_zagl_traj.rds
    ...
r/
  src/
    ...
  dependencies.r
  run_stilt.r
setup
```

The purposes of the above directories are as follows.


### exe/

Location for files to be shared across model runs. Each file stored within `exe/` is symbolically linked to each unique simulation directory in `out/by-id/`.

This is where you will find the compiled `hymodelc` executable as well as global model configuration files, including `ASCDATA.CFG`, `CONC.CFG`, `LANDUSE.ASC`, and `ROUGLEN.ASC`.


### fortran/

Contains source code for the `hymodelc` executable and `permute.f90` spatial permutation subroutine used for footprint kernel calculations.  the included `setup` script (which runs as part of the standard `uataq::stilt_init()` installation) or manually with

```sh
cd fortran
R CMD SHLIB permute.f90
mv permute.so ../r/src/permute.so
make
mv hymodelc ../exe/hymodelc
cd ..
chmod +x exe/hymodelc
```

Note that `permute.f90` is compiled specially as an R-compatible dynamic link library, which allows its interactive use from within the R environment.

> gfortran is used as the default compiler because it (1) is a universal free GNU fortran compiler and (2) has recently shown speed advantages over other popular paid compilers on test systems. To modify the compiler used for the fortran components of STILT, modify fortran/Makefile setting the compiler and relevant compilation flags and recompile.



### out/

Initially empty, this folder propagates subdirectories containing simulation information and outputs. These are organized into the following three subdirectories for convenience.

#### by-id/
Contains simulation files by simulation id, with the naming convention `yyyymmddHH_lati_long_zagl`.

Abbreviation   | Value
---------------|----------------------------------
`yyyy`         | Year (start)
`mm`           | Month (start)
`dd`           | Day (start)
`HH`           | Hour (start)
`lati`         | Receptor latitude (deg)
`long`         | Receptor longitude (deg)
`zagl`         | Receptor height above ground (m)

This becomes the working directory for each unique simulation, containing symbolic links to all of the shared files in `exe/` as well as simulation specific `CONTROL`, `SETUP.CFG`, and output files.

STILT outputs two files for later use. Particle trajectories are saved to a `_traj.rds` file and gridded footprints saved to a `_foot.nc` file. For more information, see [Outputs]({{"/docs/outputs.html"|relative_url}}).

#### footprints/
Symbolic links to footprint files found in `by-id/` simulation directories.

#### particles/
Symbolic links to particle trajectory files found in `by-id/` simulation directories.


## r/

Contains all R code that controls the model.

**`run_stilt.r` is the primary script that users will interact with**. It contains settings used to adjust model parameters, execute parallelized simulations, and calculate produce upstream influence footprints. These parameters are documented in [Controls]({{"/docs/controls.html"|relative_url}}).

`dependencies.r` is used to load the necessary functions  on each forked parallel process.

The `src/` subdirectory contains the bulk of the R source code. Since the model is controlled by `run_stilt.r`, the source code found here will not be modified by the majority of users. Each file contains a single R function with metadata documenting function arguments and usage instructions for making programatic adjustments to STILT's workflow.
