#### subroutine to readin ODIAC emissions and then couple with STILT footprint
# as footprints have already been weighted by AK and PW,
# just multiple emission with 2D footprint map
# written by Dien Wu, 09/13/2016

# Updates:
# ADD ODIACv2016, flag 1 for using v2015a, flag 2 for v2016, DW 02/14/2017
# note that v2015a does not have emission for year 2015
# ADD PRD ODIAC emissions, DW 03/08/2017
# ADD TIMES hourly scaling factors for ODIACv2016, DW 03/08/2017
# Get rid of variable "odiac.vname",
# always preprocess and read ODIAC emission before call this function...

# version 2 modify based on Ben's code, DW
# can work with multiple receptors at a time, now, DW, 06/05/2018
# fix footprint lat/lon to lower lefts, as Ben uses centered lat/lon
# use raster rather than nc_open, DW, 06/19/2018

foot.odiacv3 <- function(foot.path, foot.file, emiss.file,
  emiss.ext = c(0, 60, 0, 50),
  workdir, timestr, txtfile, storeTF){

  library(raster)

  # if cannot find the correct format of nc file for emissions given selected area
  # and return ODIAC file name with path in front
  if (length(emiss.file) == 0) {
    cat('NO nc file found, check tif2nc.odiacv2() to create one...\n')
    return()

  } else {
    ## read in emissions
    emiss.dat <- raster(emiss.file)
    emiss.res <- res(emiss.dat)[1]
  }  # end if emiss.file

  # from foot.file, get receptor info
  receptor <- unlist(strsplit(gsub('_X_foot.nc', '', foot.file), "_"))
  receptor <- data.frame(matrix(receptor, byrow = T, ncol = 3),
    stringsAsFactors = F)
  colnames(receptor) <- list('timestr', 'lon', 'lat')

  order.index <- order(receptor$lat)
  receptor <- receptor[order.index, ]
  foot.file <- foot.file[order.index]

  receptor$xco2.ff <- NA

  # then loop over each receptor
  for (r in 1:nrow(receptor)) {

    # read in footprint
    foot.dat <- raster(file.path(foot.path, foot.file[r]))

    # NOW, foot and emiss should have the same dimension,
    # multiple them to get contribution map of CO2 enhancements
    # sum the map to get the XCO2 enhancements,
    # note that AK and PW have been incorporated in footprint
    xco2.ff <- raster::overlay(x = emiss.dat, y = foot.dat,
      fun = function(x, y){return(x * y)})
    #plot(log10(xco2.ff.raster))

    xco2.ff.array <- raster::as.matrix(xco2.ff.raster)
    receptor$xco2.ff[r] <- sum(xco2.ff.array)
    print(sum(xco2.ff.array))

    ### store emission * column footprint = XCO2 contribution grid into .nc file
    if(storeTF){
      filenm <- gsub('foot', 'foot_emiss', foot.file[r])
      filenm <- file.path(workdir, 'plot', 'foot_emiss', filenm)

      # define dimnames
      x <- ncdim_def("lon", "degreesE", seq(xmn, xmx - emiss.res, emiss.res))
      y <- ncdim_def("lat", "degreesN", seq(ymn, ymx - emiss.res, emiss.res))

      # flip 2D foot and store footprint in [LAT, LON]
      vars <- ncvar_def(name = "xco2", units = "PPM", list(x, y),
                        longname = "XCO2 enhancemnets due to ODIAC emission")
      ncnew <- nc_create(filename = filenm, vars = vars)
      ncvar_put(nc = ncnew, varid = vars, vals = xco2.ff.array)
      nc_close(ncnew)   # close our netcdf4 file
    }  # end if storeTF
  }  # end for r

  # finally, write in a txt file
  write.table(x = receptor, file = txtfile, sep = ',', row.names = F, quote = F)

  return(receptor$xco2.ff)
} # end of subroutine
