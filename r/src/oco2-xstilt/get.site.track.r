# separate script that includes all site information, including timestr, lat, lon \
# by DW, 06/15/2018

# 'urbanTF, dlon, dlat' for find.overpass()
get.site.track <- function(site, oco2.ver, oco2.path, workdir, searchTF = F,
  date.range = c('20140101', '20181231'), thred.per.count, lon.lat = NULL,
  urbanTF, dlon, dlat){

  # instead of inputting all info mannually, use find.overpass() to find
  # overpasses given a city lat.lon

  # first input lon.lat, from parent code or below
  if (is.null(lon.lat)) {  # if lon.lat is not passed from above

    # spatial domains placing receptors and city center, help select OCO-2 data
    # in form of 'lon.lat <- c(minlon, maxlon, minlat, maxlat, city.lon, city.lat)'
    # Middle East
    if (site == 'Riyadh')lon.lat <- c(46, 48,    23.5, 26.0, 46.72, 24.63)
    if (site == 'Medina')lon.lat <- c(38, 41,    23.5, 25.5, 39.60, 24.46)
    if (site == 'Mecca') lon.lat <- c(38, 40.5,  20.5, 22.5, 39.82, 21.42)
    if (site == 'Cairo') lon.lat <- c(30, 32,    29.0, 32.0, 31.23, 30.05)
    if (site == 'Jerusalem')lon.lat <- c(34, 36, 31.0, 33.0, 35.22, 31.78)

    # Asia
    if (site == 'PRD')    lon.lat <- c(110,   118,   21,   27,   114.11, 22.40)
    if (site == 'Beijing')lon.lat <- c(115.5, 117.5, 39,   41,   116.41, 39.90)
    if (site == 'Xian')   lon.lat <- c(107.5, 110.5, 33,   35.5, 108.90, 34.27)
    if (site == 'Lanzhou')lon.lat <- c(102.5, 105,   35,   37.5, 103.80, 36.04)
    if (site == 'Mumbai') lon.lat <- c(72,    74.5,  17.5, 20.0,  72.83, 18.98)

    # US
    if (site == 'Indy')    lon.lat <- c(-90,  -82,  38, 43,  -86.15, 39.77)
    if (site == 'Phoenix') lon.lat <- c(-113, -110, 32, 35, -112.07, 33.45)
    if (site == 'SLC')     lon.lat <- c(-114, -111, 37, 43, -111.88, 40.75)
    if (site == 'Denver')  lon.lat <- c(-109, -101, 37, 43, -104.88, 39.76)
    if (site == 'LA')      lon.lat <- c(-122, -115, 32, 38, -118.41, 34.05)
    if (site == 'Seattle') lon.lat <- c(-125, -119, 45, 50, -122.35, 47.61)
  }  # end if is.null()

  # once have coordinate info, get OCO-2 overpasses,
  # either from txt file or scanning through all OCO-2 files
  # first need timestr for SIF files, look for txtfile from find.overpass()
  txtfile <- paste0('oco2_overpass_', site, '_', oco2.ver, '.txt')

  # if not call find.overpass(); if exists, read from txtfile
  if (!file.exists(file.path(workdir, txtfile)) | searchTF == T) {
    cat('NO overpass txt file found or need overwrite...searching now...\n')

    # find overpasses over all OCO-2 time period
    oco2.track <- find.overpass(date = c('20140901', '20181231'),
      target.region = lon.lat, oco2.ver = oco2.ver, oco2.path = oco2.path,
      urbanTF, dlon, dlat)

    write.table(oco2.track, file = file.path(workdir, txtfile), sep = ",",
      row.names = F, quote = F)

  } else {   # txtfile found--
    oco2.track <- read.table(file.path(workdir, txtfile), header = T, sep = ',',
      stringsAsFactors = F)
  } # end if !file.exists()

  # select time range and remove tracks with too few soundings
  thred.count <- thred.per.count * abs(diff(c(lon.lat[3], lon.lat[4])))
  cat('Only return overpass dates that have >', thred.count, 'sounding...\n')

  oco2.track <- oco2.track %>%
    filter(timestr >= date.range[1] & timestr <= date.range[2]) %>%
    filter(tot.count >= thred.count)

  # at least one sounding near the city 
  if (urbanTF) oco2.track <- oco2.track %>% filter(tot.urban.count > 0)

  all.info <- list(lon.lat = lon.lat, oco2.track = oco2.track)
  return(all.info)
}

# end of script
