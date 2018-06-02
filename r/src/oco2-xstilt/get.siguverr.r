### subroutine to compute SIGUVERR,
# require txt file with modeled vs. observed wind data
# DW

# need polish for generalization ///
get.siguverr <- function(site, timestr, gdaspath, nfTF = F, forwardTF = F){

  ### read in wind comparisons
  gdasfile <- list.files(path = gdaspath, pattern = substr(timestr, 1, 8))

  if(length(gdasfile) != 0){

    gdastime <- substr(gdasfile, 6, nchar(gdasfile) - 4)
    gdastime <- matrix(unlist(strsplit(gdastime, "-")), ncol = 2, byrow = T)
    begin.timestr <- gdastime[, 1]
    end.timestr   <- gdastime[, 2]

    ## read GDAS and radiosonde comparisons
    gdas.rad <- read.table(file.path(gdaspath, gdasfile), sep = ",", header = T)
    gdas.rad <- gdas.rad[!is.na(gdas.rad$u.err), ]
    gdas.rad <- gdas.rad[gdas.rad$press >= 300, ]

    gdas.rad.time <- as.numeric(substr(gdas.rad$time, 1, 8))
    end.time <- as.numeric(substr(end.timestr, 1, 8))

    # select nearfield radiosondes
    # also true for forward-time definition of background
    if(nfTF | forwardTF){
      if(site == "Riyadh")sel.hor <- gdas.rad$lat > 24   & gdas.rad$lat < 25.5 &
                                     gdas.rad$lon > 45.5 & gdas.rad$lon < 47.5
      if(site == "Cairo")sel.hor <- gdas.rad$lat > 29 & gdas.rad$lat < 32 &
                                    gdas.rad$lon > 29 & gdas.rad$lon < 33

      sel.time <- gdas.rad.time >= end.time
      SEL <- sel.hor & sel.time

      if (length(which(SEL)) > 0) {
        gdas.rad$nfTF <- SEL
        nf <- gdas.rad[SEL,]
        #nf <- gdas.rad[gdas.rad$lat == 24.93 & gdas.rad$lon == 46.72, ]

      } else {
        # expanding time ranges
        cat("get.siguverr(): Missing raob, Extending time range...\n")

        for (l in 1:length(unique(gdas.rad$time))) {
          ext.time <- gdas.rad.time >= gdas.rad.time[l]
          SEL <-sel.hor & ext.time

          if (length(which(SEL))==0) {nf<-NA; next}

          gdas.rad$nfTF <- SEL
          nf <- gdas.rad[SEL, ]
        } # end loop l

        # expanding horizontal lat lon ranges
        if (length(nf) == 1) {
          cat("get.siguverr(): Missing raob, Extending horizontal ranges...\n")
          if(site == "Riyadh")ext.hor <- gdas.rad$lat > 20 & gdas.rad$lat < 30 &
                                         gdas.rad$lon > 40 & gdas.rad$lon < 50

          SEL <- ext.hor & sel.time
          if (length(which(SEL)) == 0) {
            cat("!!! Very poor RAOB network in this case...\n")
            return()
          }  # end if

          gdas.rad$nfTF <- SEL
          nf <- gdas.rad[SEL,]

        }# end if nf
      } # end if SEL

      # then compute mean SIGUVERR
      sel.nf <- nf[nf$pres >= 700,]
      siguverr <- mean(sqrt((sel.nf$u.err^2 + sel.nf$v.err^2)/2))

      # also add mean wind biases statistic
      u.bias <- mean(sel.nf$u.err)
      v.bias <- mean(sel.nf$v.err)

    }else{

      # we have 5 days statistics, only grab first 3 days backward
      SEL <- gdas.rad.time > end.time - 3
      sel.gdas <- gdas.rad[SEL & gdas.rad$pres >= 700,]
      siguverr <- mean(sqrt((sel.gdas$u.err^2 + sel.gdas$v.err^2)/2))

      # also add mean wind biases statistic
      u.bias <- mean(sel.gdas$u.err)
      v.bias <- mean(sel.gdas$v.err)

    } # end if nfTF

    stat <- data.frame(siguverr, u.bias, v.bias)
    return(list(gdas.rad, stat))

  }else{
    cat("get.SIGUVERR(): NO met vs. raob comparison found, returning NULL...\n")
    return()
  }

}  # end of subroutine
