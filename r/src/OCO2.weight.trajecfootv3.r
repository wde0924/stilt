#### subroutine to weight the column of footprint for each particle
# create new profile based on OCO-2 pressure weighting and averaging kernel
#     and then apply to STILT footprint, by weighting the footprints of
#     particles, based on different releasing heights
# OCO-2 only provides the PW, AK and a priori at 20 levels, use linear
#     interpolation to "approx" values at given STILT releasing levels
# written by Dien Wu

# updates--
# add "get.weight.func()" for obtaining interpolated weighting function
# trajec with level column is not passed to weight.trajecfoot(), DW, 05/22/2017
# version 3 for matching Ben's STILTv2, DW, 05/29/2018

weight.trajecfootv3 <- function(output, oco2.info, ak.wgt = T, pw.wgt = T){

  # read trajectory before weighting
  trajdat <- output$particle  # now a data.frame
  dpar <- (output$receptor)$dpar

	# HERE, ak.wgt and pw.wgt is passed on for weighting trajec
	combine.prof <- get.weight.funcv3(output = output, oco2.info = oco2.info,
		                                ak.wgt = ak.wgt, pw.wgt = pw.wgt)

	### STARTing weighting trajec based on profiles
	if (ak.wgt == F & pw.wgt == F) {

		# if ak.wgt == F && pw.wgt == F, return trajec with original footprint,
		# no longer need any following weighting...
		# !!! but still need to return weighting functions and other info
		cat("weight.trajecfootv3(): NO weighting turned on...\n")
		result <- list(combine.prof, trajdat)

	} else {

		#### --------- START WEIGHTING FOOTPRINT COLUMN FROM .RData FILE --------- #
		# group particles, sort traj files by "indx", 05/22/2017
		# add one more column for release level to which particles belong
		level <- trajdat$indx %/% dpar
		trajdat <- cbind(trajdat, level)
		adj <- trajdat$indx %% dpar !=0
		trajdat[adj, "level"] <- trajdat[adj, "level"] + 1
		stilt.nlevel <- max(trajdat$level)

		# initialize weighted foot column with normal footprint
		trajdat$newfoot <- NA

		# weighting newfoot by multipling AK and PW profiles from "combine.prof",
		# along with number of STILT levels
		stilt.prof <- combine.prof[combine.prof$stiltTF == TRUE, ]

		# DW, 04/20/2017, add pw.wgt flag too
		# only weight footprint in trajec if one of the two flags/or both are TRUE
		if (ak.wgt == T & pw.wgt == T) {
		  cat("weight trajec by both AK & PW profiles...\n")
			wgt.prof <- stilt.prof$ak.pw
		}
		if (ak.wgt == F & pw.wgt == T) {
      cat("weight trajec only by PW profiles\n")
			wgt.prof <- stilt.prof$pw
		}

		if (ak.wgt == T & pw.wgt == F) {
			cat("weight trajec only by AK profiles\n")
			wgt.prof <- stilt.prof$ak.norm
		}

		# start weighting for unique release levels
		for (l in 1:stilt.nlevel) {
			level.indx <- which(trajdat$level == l)

      # need to multiple by number of levels, as trajecfoot() will calculate the
      # spatial footprint based on average footprint in a column
      # thus, resultant 'newfoot' should be similar to 'foot'
			trajdat[level.indx, "newfoot"] <- trajdat[level.indx, "foot"] *
                                        wgt.prof[l] * stilt.nlevel
		} # end for l

	} # end if flag, ak.wgt & pw.wgt

	# for testing, store two sets of trajdat
	# one weighting over AK.norm * PW, newfoot are much smaller than original foot
	newtraj <- trajdat[, -which(colnames(trajdat) == "foot")]
	colnames(newtraj)[colnames(newtraj) == "newfoot"] <- "foot"

	# add interpolated profiles in RData files as well, DW, 04/19/2017
	# put 'newtraj' back to 'output'
	wgt.output <- output
	wgt.output$particle <- newtraj # overwrite with weighted trajec
	wgt.output$wgt.prof <- combine.prof  # add interpolated AK, PW profiles
	wgt.output$file <- gsub("traj", "wgttraj", output$file)
  saveRDS(wgt.output, wgt.output$file)

	# return both weighting profiles and weighted trajec
	return(wgt.output)

}  # end of subroutine
