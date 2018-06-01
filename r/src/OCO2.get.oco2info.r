### subroutine to find out the AK*PW, apriori profiles are,
# given the lat lon time from model receptors
# written by Dien Wu, 01/11/2017

### Input variables--
# oco2.path: oco2 path and file for searching satellite soundings;
# timestr: for finding correct oco2.file
# recp.lat, recp.lon: numeric numbers for receptor lat/lon, one at a time
# diff.td: allowable thredshold for difference in lat/lon between
#          given receptors and all satellite soundings

get.oco2info <- function(oco2.path, timestr, recp.lat, recp.lon, diff.td=1E-4){

  # grabbing OCO-2 info
  oco2.file <- list.files(path = oco2.path, pattern = substr(timestr, 3, 8))
  oco2.dat <- nc_open(file.path(oco2.path, oco2.file))

  # grabbing OCO-2 levels, lat, lon
  # level 1 to 20, for space-to-surface, level 20 is the bottom level
  # may need to reverse later
  oco2.level <- ncvar_get(oco2.dat, "levels")
  oco2.lat <- ncvar_get(oco2.dat, "latitude")
  oco2.lon <- ncvar_get(oco2.dat, "longitude")

  # grabbing warn levels
  warnlevel <- ncvar_get(oco2.dat, "warn_level")

  # grabbing time for STILT receptors
  # YYYY MM DD HH mm ss m (millisecond) f (footprint)
  id <- as.character(ncvar_get(oco2.dat, "sounding_id"))

  # locate the OCO2 data using lat, lon, when diff are both the smallest
  diff.lat <- abs(oco2.lat - recp.lat)
  diff.lon <- abs(oco2.lon - recp.lon)

  # try to find the closest sounding lat/lon,
  # given receptor lat/lon and allowable difference thredshold, "diff.td"
  lat.index <- which(diff.lat < diff.td)
  lon.index <- which(diff.lon < diff.td)

  # only if lat/lon indices are the same
  loc.index <- intersect(lat.index, lon.index)

  # cannot find the sounding according to receptor lat/lon
  # if so, loose "diff.td", or check OCO-2 version, or input lat/lon
  if(length(loc.index)!=1){
    cat("get.oco2info(): cannot find the receptor lat/lon from OCO-2 file...")
    next
  }

  # return the oco2 lat, lon, ak, pw, apriori, profiles
  find.lat <- oco2.lat[loc.index]
  find.lon <- oco2.lon[loc.index]
  find.id  <- id[loc.index]

  ## grab column co2, averaging kernel, pressure weight and prior CO2 profiles

  # dimensions--[levels, soundingID]
  # normalized averaging kernel (unitless)
  ak.norm <- ncvar_get(oco2.dat, "xco2_averaging_kernel")[, loc.index]

  # pressure weighting (unitless)
  pw <- ncvar_get(oco2.dat, "pressure_weight")[, loc.index]

  # pressure in hPa
  pres <- ncvar_get(oco2.dat, "pressure_levels")[, loc.index]

  # CO2.apriori in ppm
  apriori <- ncvar_get(oco2.dat, "co2_profile_apriori")[, loc.index]

  # dimensions--[soundingID]
  # ground height measured in OCO-2 in meter ASL
  grdhgt <- ncvar_get(oco2.dat, "Sounding/altitude")[loc.index]

  # retrieved XCO2 and its uncertainty
  xco2 <- ncvar_get(oco2.dat, "xco2")[loc.index]
  xco2.uncert <- ncvar_get(oco2.dat, "xco2_uncertainty")[loc.index]

  # satellite footprint
  footprint<-ncvar_get(oco2.dat,"Sounding/footprint")[loc.index]

  #t_700 <- ncvar_get(oco2.dat, "Retrieval/T700")[loc.index] # temp at 700mb
  psfc<-ncvar_get(oco2.dat,"Retrieval/psurf")[loc.index] # ret sfc pressure

  # check whether is missing data
  pw[pw == -999999] <- NA
  xco2[xco2 == -999999] <- NA
  pres[pres == -999999] <- NA
  psfc[psfc == -999999] <- NA
  #t_700[t_700 == -999999] <- NA
  grdhgt[grdhgt == -999999] <- NA
  apriori[apriori == -999999] <- NA
  ak.norm[ak.norm == -999999] <- NA
  footprint[footprint==-999999]<-NA
  xco2.uncert[xco2.uncert == -999999]<-NA

  # assign vertical dimnames
  attributes(ak.norm)$names <- oco2.level
  attributes(pw)$names <- oco2.level
  attributes(pres)$names <- oco2.level
  attributes(apriori)$names<-oco2.level

  ### combine all OCO-2 vertical profiles and other 1D variables
  all.info <- list(ak.norm = ak.norm, pw = pw, pres = pres, apriori = apriori,
                   oco2.grdhgt = grdhgt, oco2.psfc = psfc, oco2.foot = footprint,
                   oco2.xco2 = xco2, oco2.xco2.uncert = xco2.uncert,
                   oco2.id = find.id, oco2.lat = find.lat, oco2.lon = find.lon)

  # return both profiles and variables
  all.info

} # end of subroutine
