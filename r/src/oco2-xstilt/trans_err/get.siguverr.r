### subroutine to compute SIGUVERR,
# require txt file with modeled vs. observed wind data
# returning met-raob comparisons and wind stat for trans error
# DW

# pre-requirement: wind error statistics generated in txtfile *****
# generalize the code for other cities by introducing 'lon.lat', DW, 07/19/2018
# nhrs: selecting ? days backward for computing wind err, DW, 07/19/2018

get.siguverr <- function(site, timestr, errpath, nfTF = F, forwardTF = F,
  lon.lat, nhrs){

  ### read in wind comparisons
  errfile <- list.files(path = errpath, pattern = substr(timestr, 1, 8))

  if(length(errfile) != 0){

    errtime <- substr(errfile, 6, nchar(errfile) - 4)
    errtime <- matrix(unlist(strsplit(errtime, "-")), ncol = 2, byrow = T)
    begin.timestr <- errtime[, 1]
    end.timestr   <- errtime[, 2]

    ## read met and radiosonde comparisons
    met.rad <- read.table(file.path(errpath, errfile), sep = ",", header = T) %>%
      na.omit() %>% filter(press >= 300)

    end.time <- as.numeric(substr(end.timestr, 1, 8))

    # select nearfield radiosondes
    # also true for forward-time definition of background
    if(nfTF | forwardTF){

      # select wind comparisons within 2x2 deg around the city center
      # select 1day comparisons
      nf <- met.rad %>% filter(
          lon > (lon.lat[5] - 1) & lon < (lon.lat[5] + 1) &
          lat > (lon.lat[6] - 1) & lat < (lon.lat[6] + 1) & time >= end.time)

      # if there are no data given above selection,
      # expanding time range first, then spatial domain
      if (nrow(nf) == 0) {
        cat("get.siguverr(): Missing nf raob, Extending time range...\n")

        # expanding time ranges
        uni.time <- unique(met.rad$time) # unique raob times
        for (l in 1:length(uni.time)) {

          nf <- met.rad %>% filter(
              lon > (lon.lat[5] - 1) & lon < (lon.lat[5] + 1) &
              lat > (lon.lat[6] - 1) & lat < (lon.lat[6] + 1) &
              time >= uni.time[l])

          if (nrow(nf) == 0) {nf <- NA; next}
        } # end loop l

        # expanding horizontal lat lon ranges
        if (is.na(nf)) {
          cat("get.siguverr(): Missing raob, Extending spatial domain...\n")

          # expanding spatial domain, now 8x8 deg around city center
          nf <- met.rad %>% filter(
              lon > (lon.lat[5] - 4) & lon < (lon.lat[5] + 4) &
              lat > (lon.lat[6] - 4) & lat < (lon.lat[6] + 4) &
              time >= end.time)

          if (nrow(nf) == 0) {
            cat("**** Very POOR RAOB network for this event...returning NA\n")
            return()
          }  # end if
        }# end if nf
      } # end if

      # then compute mean SIGUVERR
      sel.nf <- nf %>% filter(press >= 700)
      siguverr <- mean(sqrt((sel.nf$u.err^2 + sel.nf$v.err^2)/2))
      u.bias <- mean(sel.nf$u.err); v.bias <- mean(sel.nf$v.err)

    }else{

      #### if not nearfield wind statistics
      # we have 5 days statistics, only grab first 3 days backward
      # if backward, ndays < 0
      max.date <- as.Date(as.character(end.time), '%Y%m%d')
      min.date <- as.Date(max.date, '%Y%m%d') + nhrs/24

      sel.met.rad <- met.rad %>%
        mutate(date = as.Date(as.character(time), '%Y%m%d')) %>%
        filter(press >= 700 & date > min.date & date < max.date)

      # also add mean wind biases statistic
      siguverr <- mean(sqrt((sel.met.rad$u.err^2 + sel.met.rad$v.err^2)/2))
      u.bias <- mean(sel.met.rad$u.err); v.bias <- mean(sel.met.rad$v.err)
    } # end if nfTF

    stat <- data.frame(siguverr, u.bias, v.bias)
    return(list(met.rad, stat))

  }else{
    cat("get.SIGUVERR(): NO met vs. raob comparison found, returning NA...\n")
    return()
  }

}  # end of subroutine
