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

foot.odiacv2 <- function(footpath, footfile, emiss.ext = c(0, 60, 0, 50),
  workdir, timestr, txtfile, storeTF, res = 1/120){

  library(raster)
  emiss.path <- file.path(workdir, 'in')
  emiss.file <- list.files(path = emiss.path, pattern = substr(timestr, 1, 6))
  emiss.file <- file.path(emiss.path, emiss.file)

  # if cannot find the correct format of nc file for emissions given selected area
  # and return ODIAC file name with path in front
  if (length(emiss.file) == 0) {
    cat('NO ODIAC file found, creating one from tiff format...\n')
    return()
  } else {
    ## read in emissions
    emiss.dat <- nc_open(emiss.file)
    emiss <- ncvar_get(emiss.dat, 'odiac_co2_emiss')  # [lat, lon]
    # determine whether to use hourly emissions, based on footprint dim
    hourlyTF <- F; if(length(dim(emiss)) == 3)hourlyTF <- T
    emiss.lat <- ncvar_get(emiss.dat, 'lat')
    emiss.lon <- ncvar_get(emiss.dat, 'lon')
    if(hourlyTF == F) {
      dimnames(emiss) <- list(emiss.lat, emiss.lon)
    } else {
      emiss.hr <- ncvar_get(emiss.dat, 'hr')
      dimnames(emiss) <- list(emiss.lat, emiss.lon, emiss.hr)
    }
  }  # end if emiss.file

  # flip latitude order, decreasing for North hemisphere
  emiss.prep <- emiss[length(emiss.lat):1, ]
  emiss.raster <- raster(resolution = res, vals = emiss.prep,
                         xmn = emiss.ext[1], xmx = emiss.ext[2],
                         ymn = emiss.ext[3], ymx = emiss.ext[4])
  #plot(log10(new.raster))

  # from footfile, get receptor info
  receptor <- unlist(strsplit(gsub('_X_foot.nc', '', footfile), "_"))
  receptor <- data.frame(matrix(receptor, byrow = T, ncol = 3),
                         stringsAsFactors = F)
  colnames(receptor) <- list('timestr', 'lon', 'lat')

  order.index <- order(receptor$lat)
  receptor <- receptor[order.index, ]
  footfile <- footfile[order.index]

  receptor$xco2.ff <- NA

  # then loop over each receptor
  for (r in 1:nrow(receptor)) {
    # r = 30
    # read in footprint
    foot.dat <- nc_open(file.path(footpath, footfile[r]))
    foot <- ncvar_get(foot.dat, 'foot') # [lon, lat]

    # convert to lower left
    foot.lon <- ncvar_get(foot.dat, 'lon') - 1/240
    foot.lat <- ncvar_get(foot.dat, 'lat') - 1/240
    dimnames(foot) <- list(foot.lon, foot.lat)

    # correct form for raster, [lat, lon], lat decreasing
    foot.prep <- t(foot)[length(foot.lat):1, ]
    foot.raster <- raster(resolution = res, vals = foot.prep,
                          xmn = min(foot.lon), xmx = max(foot.lon) + res,
                          ymn = min(foot.lat), ymx = max(foot.lat) + res)
    #plot(log10(foot.raster))

    # find overlaid region
    xmn <- max(c(min(emiss.lon), min(foot.lon))) # left border
    xmx <- min(c(max(emiss.lon), max(foot.lon)) + res) # right border
    ymn <- max(c(min(emiss.lat), min(foot.lat))) # bottom border
    ymx <- min(c(max(emiss.lat), max(foot.lat)) + res) # top border

    # then crop emissions or footprint
    reg <- as(extent(xmn, xmx, ymn, ymx), 'SpatialPolygons')
    crs(reg) <- crs(emiss.raster)
    crop.emiss <- crop(emiss.raster, reg)
    crop.foot <- crop(foot.raster, reg)

    # NOW, foot and emiss should have the same dimension,
    # multiple them to get contribution map of CO2 enhancements
    # sum the map to get the XCO2 enhancements,
    # note that AK and PW have been incorporated in footprint
    xco2.ff.raster <- raster::overlay(x = crop.emiss, y = crop.foot,
                                      fun = function(x, y){return(x * y)})
    #plot(log10(xco2.ff.raster))

    xco2.ff.array <- raster::as.matrix(xco2.ff.raster)
    receptor$xco2.ff[r] <- sum(xco2.ff.array)
    print(sum(xco2.ff.array))

    ### store emission * column footprint = XCO2 contribution grid into .nc file
    if(storeTF){
      filenm <- gsub('foot', 'foot_emiss', footfile[r])
      filenm <- file.path(workdir, 'plot', 'foot_emiss', filenm)

      # define dimnames
      x <- ncdim_def("lon", "degreesE", seq(xmn, xmx - res, res))
      y <- ncdim_def("lat", "degreesN", seq(ymn, ymx - res, res))

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
