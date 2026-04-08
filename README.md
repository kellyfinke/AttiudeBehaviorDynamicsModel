# AttitudeBehaviorDynamicsModel

## Overview
This repository contains the code used to generate the results in:

**A complex systems framework reveals hidden context-dependence of behavior
transitions**  
Kelly A. Finke, Kristopher L. Nichols, Elke U. Weber, Corina E. Tarnita  
Submitted to Science Advances

The model is implemented in Julia and supports both agent-based simulations and analytical exploration of system dynamics.

## System requirements

The code was produced on Julia v1.12.5

Module uses the following packages:

```console
CairoMakie
Colors 
Distributions
FileIO
GaussianMixtures
GraphPlot
Graphs
JLD
JLD2
LinearAlgebra
Plots
SharedArrays
Statistics
StyledStrings
```

For more information, check `Project.toml` and `Manifest.toml`.

## Julia installation guide

Download and install Julia by following these [instructions](https://julialang.org/downloads/), or by running:

> Linux and MacOS:
>
> ```console
> $ curl -fsSL https://install.julialang.org | sh
> ```
>
> Windows:
>
> ```console
> > winget install julia -s msstore
> ```

This will install the `juliaup` installation manager.
Make sure to be up to date by running:

> ```console
> $ juliaup update
> $ juliaup default release
> ```

To install different versions or explore more options run `juliaup --help`.

### Run scripts

Once installed, Julia will be available via the command line interface. Then, a script like `my_script.jl` can be run as:

```console
$ julia my_script.jl
```

## Module installation guide

### Download the repository

Clone this repository either by the `Download ZIP` option under the `Code` dropdown menu above, or by running:

```console
$ git clone https://github.com/[repo name].git
```

For more information on how to clone a repository visit the [documentation](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository).

### Install packages

For installation of all packages and precompilation of the `AttitudeBehaviorDynamics.jl` module, run `setup.jl` as:

```console
$ julia setup.jl
```

Assuming the command line is in the directory of the repository. Alternatively, run the script using the relative path to the repository as:

```console
$ julia path/to/repo/setup.jl
```

Expected installation and precompilation time is 5 minutes.

## Sample Simulation Data
We provide low-resolution versions of the simulations used to create all figures in the main text of the article.

Due to file size, simulation data is hosted externally:

[Download dataset (Zenodo)](LINK)

To reproduce figures:
1. Download and extract the dataset
2. Place in `AgentBasedModel/simulations/compressedSims`
3. Run `scripts/reproduce_figures.ipynb` (instructions below)

## Agent Based Model

### Reproducing figures from the article

`scripts/reproduce_figures.ipynb` includes code for reproducing all of the figures in the main text of the paper.

You can open the notebook directly from Julia

```console
$ julia --project=. -e 'using IJulia; jupyterlab()'
```

Or, if you already have Jupyter installed (e.g., via Anaconda):

```bash
jupyter notebook
```

or

```bash
jupyter lab
```

This will launch Jupyter in your browser. Then navigate to `scripts/reproduce_figures.ipynb` and open it.

A Jupyter Notebook file consists of many cells, and allows you to run code and see results in the same file.
We suggest running the file cell by cell in order (using Shift+Enter or by clicking the play button on the top panel), to ensure that all required functions are created before they're used. You can then go back and re-run cells if you want to produce different figures:

`reproduce_figures.ipynb` consists of sections for each type of result: 
 - Timeseries
 - 1D equilibrium plots
 - 2D equilibrium plots
 - 3D equilibrium plot

In each section, you can select which specific result you'd like to produce by setting the `whichPlot` variable. E.g., in the Timeseries section, setting `whichPlot = "Fig. 2Ai"` will produce the plot from Fig. 2Ai.

For timeseries plots, you'll run simulations in real time in the jupyter notebook file. For all other plots, you'll load pre-run simulations. To save space, all pre-generated simulation data is of a lower resolution than those displayed in the article, and we only save behavior (not attitude) data for 2D plots. See **Sample Simulation Data** above for instructions on dowloading this data. You can also choose to run these larger simulations yourself (see "Running Simulations" below).

### Running Simulations

If you'd like to run your own simulations, there are two options:

- `scripts/visualizeSimulationTimeseries.ipynb` allows you to run simulations from a single set of parameters, immediately visualizing the simulation via a timeseries plots. Simply follow the instructions above for opening a Jupyter Notebook file, edit whichever parameters you like, and play around with the simulations. Each simulation should run in seconds to minutes.
- `scripts/runSimulationsParameterSweep.jl` allows you to run a batch of simulations from a range of parameters. We include the parameter values used to generate all the figures in the paper, which you can select from using the `whichSim` variable in the Julia file.

**NOTE: we do not recommend running batches of simulations on a personal computer!** We recommend parallelizing these simulations across multiple cores on a computing cluster. Each computing cluster is different, so reach out to your cluster administrator for assistance on how to parallelize the code for your cluster. See `sampleScriptsForCluster/` for samples of slurm scripts we use for our own cluster as well as modified scripts setup for parallelization within our cluster's setup. For instance, we are limited to running 300 jobs at a time, so our scripts splits the `paramVals` list into 300 equal parts.

Running `scripts/runSimulationsParameterSweep.jl` will generate many simulation files in `simulations/`. In order to extract useful data from those files to use for plotting, you must first run `scripts/saveCompressedParameterSweep.jl` _after all simulations have finished running_. 

When running large batches of simulations simultaneously, it's possible that simulation files can become corrupted (e.g., if your job times out before simulations are finished). `scripts/deleteCorruptedSims.jl` will automatically track down all corrupted simulations and delete them. Then, you can just re-run `scripts/runSimulationsParameterSweep.jl`, and it will pick up where it left off and complete the simulations. 

## Analytical Model

`AnalyticalModel.ipynb` includes code for reproducing all of the supplemental analytical model figures.

You can open the notebook directly from Julia

```console
$ julia --project=. -e 'using IJulia; notebook()'
```

Or, if you already have Jupyter installed (e.g., via Anaconda):

```bash
jupyter notebook
```

or

```bash
jupyter lab
```

This will launch Jupyter in your browser. Then navigate to `AnalyticalModel.ipynb` and open it.

A Jupyter Notebook file consists of many cells, and allows you to run code and see results in the same file.
We suggest running the file cell by cell in order (using Shift+Enter or by clicking the play button on the top panel), to ensure that all required functions are created before they're used. You can then go back and re-run cells if you want to produce different figures:

`reproduce_figures.ipynb` consists of sections for each type of result: 
 - Timeseries
 - 1D equilibrium plots
 - 2D equilibrium plots
 - 3D equilibrium plot

In each section, you can select which specific result you'd like to produce by setting the `whichPlot` variable. E.g., in the Timeseries section, setting `whichPlot = "Fig. S2A"` will produce the plot from Fig. S2A.


---
Copyright (c) 2026 Kelly Finke
