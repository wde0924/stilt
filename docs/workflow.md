---
layout: docs
title: STILT Workflow
---

# Workflow

<div class="text-center" style="margin-bottom: 30px;">
  <img src="{{"/img/chart-workflow-simple.png"|relative_url}}" style="max-height: 250px; width: auto; margin: auto;">
</div>

Presented here is a generalized workflow for executing STILT simulations and applying flux inventories. In addition to the theoretical points below, several [Tutorials](https://github.com/uataq/stilt-tutorials) provide workable examples to get you up and running.

1. Collect **meteorological data** for simulations
> NOAA publishes High Resolution Rapid Refresh (HRRR) mesoscale model data in the ARL packed format required for STILT at [ftp://arlftp.arlhq.noaa.gov/pub/archives/hrrr/](ftp://arlftp.arlhq.noaa.gov/pub/archives/hrrr/). This is often the easiest place to start but is only available after June 15, 2015. The coupling of the popular Weather Research and Forecasting (WRF) model with STILT is well documented by [Nehrkorn, 2010](https://link.springer.com/article/10.1007%2Fs00703-010-0068-x).

1. Subset meteorological data for model domain (optional)
> Many meteorological data products are offered at a global, continental, or regional scale. STILT loads all meteorological data files that encompass the temporal domain of the simulation into memory. Reading these large files is often the largest bottleneck of simulations and is highly memory intensive. Recent versions of HYSPLIT provide a spatial grid extraction routine (xtrct_grid) for this purpose and documentation can be found in the [HYSPLIT User's Guide](https://www.arl.noaa.gov/documents/reports/hysplit_user_guide.pdf).

1. Initialize a **new STILT project** with `Rscript -e "uataq::stilt_init('myproject')"`
> If the UATAQ package is not installed, see [Installation](installation.md).

1. Define [simulation controls]({{"/docs/controls.html"|relative_url}}) in `run_stilt.r`
  1. Coordinates for **receptor(s)**
  1. **Footprint grid** domain and resolution
  1. **Meteorological data** path and file naming conventions in `run_stilt.r`
  1. Adjust parallel execution, transport, and dispersion settings (optional)
1. Execute the model with `Rscript run_stilt.r`
> If not dispatching multi-node simulations with SLURM, using a job scheduler or Linux screen to execute the simulations in the background can be useful to avoid server disconnects cancelling the program. More information can be found in [Execution]({{"/docs/execution.html"|relative_url}}).

1. Convolve footprints with flux inventories to estimate contribution of near-field fluxes on the receptor
> Footprint units give a *ppm* contribution from the near-field when multiplied by the flux field. For a more detailed look, the [Tutorials](https://github.com/uataq/stilt-tutorials) provide workable examples for convolving footprints with flux inventories.

1. Add background signal to estimate changes outside of the near-field
> Background signals are often derived from measurements made just upstream from the model domain or a coarser model product such as [Carbon Tracker](https://www.esrl.noaa.gov/gmd/ccgg/carbontracker/).

1. Analysis and visualizations


# Advanced

<div class="text-center" style="margin-bottom: 30px;">
  <img src="{{"/img/chart-workflow-advanced.png"|relative_url}}" style="max-height: 270px; width: auto; margin: auto;">
</div>

After setting model parameters and executing `run_stilt.r`, meteorological data is symbolically linked to the user's home directory to avoid fortran issues with paths longer than 80 characters. This will appear with the default format `paste0('m', project)` but can be adjusted or disabled.

User parameters are then passed to `stilt_apply`, which manages dispatching simulations across parallel threads or executing serially. If using SLURM for job submission, `stilt_apply` will use the `rslurm` package to submit jobs across `n_nodes` using `n_cores` per node. If running in parallel on a single node without SLURM, `stilt_apply` will use the `parallel` package to run simulations on the current node across `n_cores`. Otherwise, `stilt_apply` will run the simulations serially using `lapply()`.
