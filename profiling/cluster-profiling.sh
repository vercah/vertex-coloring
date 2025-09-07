#!/bin/bash
#PBS -N vertec-coloring
#PBS -q cpu_b
#PBS -l walltime=01:00:00
# one node, 16 CPUs
#PBS -l select=1:ncpus=16:ompthreads=16:mem=375G
#PBS -j oe

cd "$PBS_O_WORKDIR"

module purge
module load gcc   

# OpenMP runtime
export OMP_NUM_THREADS=16
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export OMP_DYNAMIC=false


./final-compare-measure.sh all

