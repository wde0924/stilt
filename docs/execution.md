---
layout: docs
title: STILT Execution
---

# STILT Execution

![]({{"img/chart-parallel.png"|relative_url}})

Now that you've [installed STILT]({{"/docs/install.html"|relative_url}}) and [edited model controls in run_stilt.r]({{"/docs/controls.html"|relative_url}}), we're ready to run the model. The simplest way to do this is to execute `run_stilt.r` with `Rscript`.

<div class="terminal">
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-command">
    Rscript r/run_stilt.r
  </div>
</div>

Depending on which of the three parallelization settings you used, you will see one of the following.

### Serialized simulations

<!-- ![](/assets/terminal-run-stilt-serial.png) -->
<div class="terminal">
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-command">
    Rscript r/run_stilt.r
  </div>
  <div class="terminal-return">
    Initializing STILT<br>
    Number of receptors: 4<br>
    Number of parallel threads: 1<br>
    Estimated footprint grid RAM allocation: 314 MB<br>
    Parallelization disabled. Executing simulations sequentially...<br>
    <br>
    Running simulation ID:   2015061822_-111.980323_40.782561_5<br>
    ...
  </div>
</div>

The model will execute the simulations one at a time in order and print the current simulation ID to the console. This is the default and occurs when `slurm = FALSE` and `n_cores = 1`.


### Single-node parallel

<!-- ![](/assets/terminal-run-stilt-parallel.png) -->
<div class="terminal">
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-command">
    Rscript r/run_stilt.r
  </div>
  <div class="terminal-return">
    Initializing STILT<br>
    Number of receptors: 4<br>
    Number of parallel threads: 2<br>
    Estimated footprint grid RAM allocation: 314 MB<br>
    Single node parallelization. Dispatching worker processes...<br>
    <br>
    Running simulation ID:   2015061822_-111.980323_40.782561_5<br>
    Running simulation ID:   2015061823_-111.980323_40.782561_5<br>
    ...
  </div>
</div>

The model will dispatch batches of simulations to forked worker processes. This occurs when `slurm = FALSE`, `n_nodes = 1`, and `n_cores > 1`.


### SLURM multi-node parallel

<!-- ![](/assets/terminal-run-stilt-slurm.png) -->
<div class="terminal">
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-osx-button"></div>
  <div class="terminal-command">
    Rscript r/run_stilt.r
  </div>
  <div class="terminal-return">
    Initializing STILT<br>
    Number of receptors: 4<br>
    Number of parallel threads: 4<br>
    Estimated footprint grid RAM allocation: 314 MB<br>
    Multi node parallelization using slurm. Dispatching jobs...
  </div>
</div>

The model will dispatch batches of simulations across multiple SLURM nodes and execute the forked worker processes. This occurs when `slurm = TRUE`. SLURM jobs can be monitored and controlled using `squeue` and `sacct` as well as [other utilities and GUI tools](https://www.chpc.utah.edu/documentation/software/slurm.php).


### Background processing

SLURM execution will run the job in the background without tying up the active shell. You can check the progress of your job from the command line with the `sacct` command.

Single node simulations should be executed in the background to keep the process safe from disconnects and not tie up the active shell. While methods vary between systems, an easy way to ensure disconnects do not disrupt the simulations and allow for monitoring progress is to use the [screen](https://www.chpc.utah.edu/documentation/software/screen.php) UNIX tool.
