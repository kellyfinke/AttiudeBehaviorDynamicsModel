#!/bin/bash
#SBATCH --job-name=cbla-1           # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=1        # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem=20G                 # memory 
#SBATCH --time=4:00:00          # total run time limit (HH:MM:SS)
#SBATCH --array=1                # array of jobs to run
#SBATCH -o logs/slurm-%A_%a.out  # standard output
#SBATCH -e logs/slurm-%A_%a.err  # standard error

module purge
module load julia/1.11.1

export OMP_NUM_THREADS=1

julia saveCompressedParameterSweep.jl
