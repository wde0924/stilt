---
layout: docs
---

# Fair Use Policy

STILT is freely available and we encourage others to use it. Kindly keep us informed of how you are using the model and of any publication plans. Please acknowledge the source as a citation. STILT is continuously updated and improved by the development consortium, and in some cases \(as when new elements are used for the first time\) we may suggest that one or more of the developers be offered participation as authors. If your work directly competes with our analysis, we may ask that we have the opportunity to submit a manuscript before you submit one that uses unpublished features. The software is updated from time to time, and it is your responsibility to ensure that your publication is consistent with the most recent version.

# Installation

STILT has been compiled to run on UNIX platforms \(Mac, Linux\). Required software includes

* R \(v &gt;= 3.25\), [https://www.r-project.org/](https://www.r-project.org/)
  * `dplyr` package, for speed and data manipulation
  * `parallel` package, for parallel computation on a single node
  * `raster` package, for raster-based spatial analysis
  * `rslurm` package, for parallel computation across multiple nodes
  * `uataq` package, for data manipulation
* One of the following Fortran compilers (listed by preference/simulation speed)
  * GNU Fortran Compiler \(gfortran\)
  * Portland Group Compiler \(pgf90\)
  * Intel Fortran Compiler \(ifort\)
  * G95 Fortran Compiler \(g95\)
* Git, [https://git-scm.com/](https://git-scm.com/)

## Install methods

Two options exist to initialize a new STILT project.

### R \(preferred\)

This method uses R to initialize a new project. `stilt_init()` in the Utah Atmospheric Trace gas & Air Quality \(UATAQ\) R package, which includes tools for trace gas data manipulation and analysis, is a wrapper around several system commands that do much of the heavy lifting. The `uataq` R package is available on [Github](https://github.com/benfasoli/uataq/) and can be installed in R using `devtools`.

```r
if (!require('devtools')) install.packages('devtools')
devtools::install_github('benfasoli/uataq')
```

A new STILT project can then be initialized in plain R code with

```r
uataq::stilt_init('myproject')
```

> The STILT repository is 38 MB and contains source code for the model, website, and documentation.

<div class="terminal">
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-command">
    Rscript -e "uataq::stilt_init('myproject')"
  </div>
  <div class="terminal-return">
    Cloning into 'stilt'...<br>
    remote: Counting objects: 1712, done.<br>
    remote: Compressing objects: 100% (275/275), done.<br>
    remote: Total 1712 (delta 71), reused 267 (delta 39), pack-reused 1384<br>
    Receiving objects: 100% (1712/1712), 32.85 MiB | 8.57 MiB/s, done.<br>
    Resolving deltas: 100% (652/652), done.<br>
    Checking connectivity... done.<br>
    gfortran  -fpic -g -O2 -fstack-protector --param=ssp-buffer-size=4  -c  permute.f90 -o permute.o<br>
    gfortran -shared -L/usr/lib/R/lib -Wl,-Bsymbolic-functions -Wl,-z,relro -o permute.so permute.o -L/usr/lib/R/lib -lR<br>
    gfortran -c -O2 -fconvert=big-endian -frecord-marker=4 -fbounds-check -ffree-form -I. funits.f<br>
    ...    
  </div>
</div>

This function  
1. clones the stilt Github repository into a local `stilt` directory which is then renamed `myproject`  
2. builds the `permute.so` dynamic link library used to apply gaussian kernels for footprint output  
3. compiles the hymodelc executable and moves to the `exe` directory  
4. populates the project name and paths in `myproject/r/run_stilt.r`

> Since the name of the Github Repository is "stilt", a name other than "stilt" should be chosen for projects. Otherwise, conflicts will arise when attempting to clone the master repository for initializing future projects in the same parent directory.

### Manual

While the R method is preferable since it streamlines the process of initializing new projects, the same can be accompolished manually. To reproduce the results above,

Clone the repository and set the name of the project

```bash
git clone https://github.com/benfasoli/stilt
mv stilt myproject
```

Compile and move the hymodelc executable to the `exe` directory using the provided `setup` script \(or manually\)

```bash
cd myproject
chmod +x setup
./setup
```

Finally, edit settings in `r/run_stilt.r`, being sure to specify the project name  and the working directory.
