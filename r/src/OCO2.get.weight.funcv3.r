### subroutine to get new AK PW profiles based on OCO-2's
# pressure weighting and averaging kernel, for combined levels
# OCO-2 only provides the PW, AK and a priori at 20 levels,
# use linear interpolation to "approx" values at given STILT releasing levels
# Dien Wu, 08/05/2016

# Bugs fixed, DW:
# fix 1, 11/20/2016, modify the interpolate of PWF from OCO2 to STILT
# fix 2, 11/28/2016, remove storeTF flag, as we always need .RData file stored
#                    for generating footprint using Trajectfoot()

# fix 3, 02/08/2017, add uneven vertical spacing
# fix 4, 04/06/2017, change AK from zero to original OCO2 AK above model level
# add 5, 04/19/2017, store interpolated AK PW apriori

# add 6, 04/20/2017, add control flags "pw.wgt" for weighting trajec
# (1) default is to return profiles using AK and PW, ak.wgt=T & pw.wgt=T;
# (2) ak.wgt=F & pw.wgt=T for only pres wgt (when no need to use apriori);
# (3) ak.wgt=T & pw.wgt=F for only AK wgt
# (4) ak.wgt=F & pw.wgt=F no weighting (which returns the original trajec)

# version 3 for matching Ben's STILT-R version 2, DW, 05/25/2018
# interpolate ground hgt in this subroutine, DW, 05/25/2018
# output refers to all the content from .rds file using STILTv2, 05/25/2018
# which is the same 'output' from simulation_step()

get.weight.funcv3 <- function(output, oco2.info, ak.wgt = TRUE, pw.wgt = TRUE){

	if(ak.wgt){
		cat("Turn on weighting OCO-2 simulation using averaging kernel...\n")
	}else{
		cat("NO averaging kernel weighting, set ak to 1...\n")
	}

  # grab trajectory info
  receptor <- output$receptor
  r_zagl <- receptor$zagl
	zsfc <- receptor$zsfc           # modeled ground heights from get.grdhgtv2()
	recp.nlevel <- length(r_zagl)
  trajdat <- output$particle

  # grab OCO-2 info
  oco2.ak.norm  <- oco2.info$ak.norm
	oco2.pw  <- oco2.info$pw
	oco2.pres  <- oco2.info$pres
	oco2.apriori  <- oco2.info$apriori

	#### ------  CONVERT altitudes of STILT release levels to pressure ----- ####
	# interpolate starting pressure based on starting hgts, by looking at press
	# and altitude of particles at the first timestep back

	# first select the particles at first delt backwards
	cat("get.weight.funcv3(): inter/extrapolate OCO-2 profiles to model levels\n")
	min.time <- min(abs(trajdat$time)) * sign(trajdat$time[1]) # MIN time in mins
	sel.traj <- trajdat[trajdat$time == min.time, ] # trajec near receptor

	# calculate mASL, add ground height (zsfc) to mAGL
	sel.traj$zasl <- sel.traj$zagl + sel.traj$zsfc	# ASL near receptor

	### do linear interpolation on the relationship between pressure and hgts
	# and output the starting pressure based on starting hgt
	# rule=2 allows us to interpolate pressure beyond the range by using the data
	#        extreme, e.g., the surface pressure (z=0)
	# ruel=1 return NA values to values beyond data range

	# similarly, calculate mASL of release levels for column receptors
	recp.zasl <- r_zagl + zsfc     # in m

	# since there are values beyond the range which "approx" cannot predict,
	# use "approxExtrap" function INSTEAD, linear interpolation works fine for
	# lower altitudes
	asl.to.pres <- approxExtrap(sel.traj$zasl, sel.traj$pres, recp.zasl, rule = 2)
	recp.pres <- asl.to.pres$y

	# for debug--
	#plot(sel.traj$zasl, sel.traj$pres, ylim = c(1013, 0))
	#points(asl.to.pres$x, recp.pres, col="red")

	#### ------------------------ DEALING WITH OCO-2 NOW -------------------- ####
	# since STILT display particles from surface-to-space, the opposite as OCO-2
	# product originally, profiles from OCO are from levels 1-20, from TOA to sfc.
	# we need to reverse AK and PW profiles, as well as renaming attributes as
	# pressure levels. Thus, flipped profiles (now from level 1 to 20) will be
	# from sfc to TOA now...

	oco2.nlev <- length(oco2.pres)
	oco2.pres   <- oco2.pres[length(oco2.pres):1]	# flip pressure levels
	attributes(oco2.pres)$names <-
	            attributes(oco2.pres)$names[length(attributes(oco2.pres)$names):1]

	# flip 20 levels (--> from sfc to TOA) and assign names
	oco2.ak.norm <- oco2.ak.norm[length(oco2.ak.norm):1]
	oco2.apriori <- oco2.apriori[length(oco2.apriori):1]
	oco2.pw  <- oco2.pw[length(oco2.pw):1]

	attributes(oco2.ak.norm)$names <- oco2.pres
  attributes(oco2.apriori)$names <- oco2.pres
	attributes(oco2.pw)$names <- oco2.pres

	# for debug--
	# plot(oco2.pw, oco2.pres, ylim = c(1013, 0))

	## determine the separate level from STILT to OCO-2, using pressure
	# for model levels, keep OCO2 levels with zero AK above the max STILT level
	# for levels above model levels, use OCO2 profile
	min.recp.pres <- min(recp.pres)
	upper.index <- oco2.pres <  min.recp.pres	# return T/F
	lower.index <- oco2.pres >= min.recp.pres


	### -------------------  FOR a combined pressure profile ----------------- ###
	upper.oco2.pres <- oco2.pres[upper.index]
	lower.oco2.pres <- oco2.pres[lower.index]

	# combine LOWER STILT levels and UPPER OCO-2 levels
	combine.pres <- c(recp.pres, upper.oco2.pres)
	combine.nlevel <- length(combine.pres)


	### -------------------- FOR a combined AK.norm profile ------------------ ###
	# interpolate for LOWER STILT levels if ak.wgt==TRUE;
	# OR set all AK to 1 if ak.wgt==FALSE

	# DW, 04/06/2017, AK=0 for upper levels --> now keep original OCO2 AK profiles
	if (ak.wgt) {

		lower.ak.norm <- approx(oco2.pres, oco2.ak.norm, recp.pres, rule = 2)$y
		upper.ak.norm <- oco2.ak.norm[upper.index]
		combine.ak.norm <- c(lower.ak.norm, upper.ak.norm)

	} else {

		# DW, 02/06/2018, also assign 1 to upper levels if no AK weighting
		combine.ak.norm <- rep(1, combine.nlevel)
	}

	attributes(combine.ak.norm)$names <- combine.pres   # assign names


	### ------------------- FOR a combined a priori CO2 profile -------------- ###
	# interpolate for lower STILT levels
	# remain the upper OCO-2 apriori profiles for UPPER levels
	lower.apriori <- approx(oco2.pres, oco2.apriori, recp.pres, rule = 2)$y
	upper.apriori <- oco2.apriori[upper.index]
	combine.apriori <- c(lower.apriori, upper.apriori)
	attributes(combine.apriori)$names <- combine.pres


	### ------------------- FOR a combined PW profile ------------------------ ###
	# Interpolate and scale PW for LOWER/STILT levels
	# Remain PW for UPPER OCO-2 levels
	# MAY WANT TO TREAT THE VERY BOTTOM LEVEL DIFFERENTLY, BY USING XSUM(PW)=1

	# Method 0: simply using dp/p_surface, do not turn on this
	#combine.pw <- c(1-sum(abs(diff(combine.pres))/combine.pres[1]),
	#                abs(diff(combine.pres))/combine.pres[1])

	# Method 1:
	# 1) directly interpolate PW for LOWER/STILT levels, need adjustments later
	# treat the bottom layer differently, only use PWF profiles above the first
	# layer to interpolate, no weird curve now, DW 09/20/2017
	# "lower.stilt.pw.before" -- interpolated PW before scaling
	lower.stilt.pw.before <- approx(oco2.pres[-1], oco2.pw[-1], recp.pres[-1],
		                              rule = 2)$y
	#plot(lower.stilt.pw.before, recp.pres, ylim=c(1013,0))

	# 2) calculate dP for STILT levels as well as LOWER/OCO-2 levels
	# diff in pres have one value less than the LEVELS
	lower.stilt.dp <- abs(diff(recp.pres))	        # for LOWER/STILT levels
	lower.oco2.dp  <- abs(diff(lower.oco2.pres))	  # for LOWER/OCO levels

	# DW 11/20/2016 --
	# !!! also, remember to calculate dp for the OCO/STILT interface, because dp
	# scaling factor between two levels is always assigned for the upper one level
	intf.stilt.dp <- abs(diff(combine.pres))[recp.nlevel]
	intf.oco2.dp  <- lower.oco2.pres[length(lower.oco2.pres)] - upper.oco2.pres[1]

	# 3) interpolate dp.oco2.lower onto STILT levels using pres (EXCEPT the bottom
	# level, first element) + pres diff at LOWER OCO level
	# bug found, approx needs at least two non-NA values to interpolate
	# bug occurs when we have small MAXAGL for bootstrapping
	lower.oco2.dp.stilt <- approx(lower.oco2.pres[-1], lower.oco2.dp,
		                            recp.pres[-1], rule = 2)$y

	# 4) since PW is a function of pressure difference,
	# larger dp, larger air mass, should be weighted more
	# if ignoring the slight variation in q (moisture), note that STILT footprint
	# and OCO2 are only simulating/measuring the DRY AIR PROPERTIES

	# thus, calculate the ratio of dp at LOWER/STILT levels over interpolated OCO
	# dp for LOWER/STILT levels
	dp.ratio <- lower.stilt.dp/lower.oco2.dp.stilt

	# DW 11/20/2016--
	# always assign new pw to one upper level
	# !!!! we need to add one dp.ratio for the 1st OCO level above the interface
	intf.dp.ratio <- intf.stilt.dp/intf.oco2.dp

	# 5) scale interpolated PW for STILT levels by multiplying the "dp ratio"
	# remember to put aside the very bottom STILT level
	lower.pw <- lower.stilt.pw.before * dp.ratio
	attributes(lower.pw)$names <- recp.pres[-1]

	# 6) remain the PW for UPPER OCO-2 levels, from oco2.pw and upper.oco2.pres
	upper.pw <- oco2.pw[upper.index]	        # from the dividing level to TOA

	# DW, 11/20/2016--
	# 6.5) CHANGE the lowest UPPER OCO2 level using DP.RATIO at interface
	intf.pw <- upper.pw[1] * intf.dp.ratio
	upper.pw <- c(intf.pw, upper.pw[-1])

	# 7) calulate the PW for the very bottom layer
	bottom.pw  <- 1 - sum(lower.pw) - sum(upper.pw)
	combine.pw <- c(bottom.pw, lower.pw, upper.pw)
	attributes(combine.pw)$names <- combine.pres

  # combine all interpolated OCO-2 profiles
	combine.profile <- data.frame(pres = combine.pres, pw = combine.pw,
		                            ak.norm = combine.ak.norm,
																apriori = combine.apriori)
	rownames(combine.profile) <- seq(1, combine.nlevel, 1)

	# calculating the AK*PW profile, and store back into "stilt.profile"
	combine.profile$ak.pw <- combine.profile$ak.norm * combine.profile$pw

	# NOW ALL PROFILES CONTAIN--pressure, pressure weighting, normalized ak,
	#AK*PW and a priori contribution
	combine.profile$stiltTF <- F
	combine.profile[1:length(recp.pres), "stiltTF"] <- T
	
	# return both weighting profiles
	return(combine.profile)
}

# end of subroutine
