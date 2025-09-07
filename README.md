# Comparison of sequential greedy and parallel algorithms on the vertex coloring problem

## 1. Vertex Coloring
The task is to assign colors to vertices of a graph so that no two adjacent vertices share the same color, while minimizing the total number of colors used. It is an NP-hard problem.

The input graphs are provided in the `/data` folder in `.col` format, and were collected from the following sites:
- https://mat.tepper.cmu.edu/COLOR/instances.html
- https://networkrepository.com/dimacs.php

The output is expected in the `.dot` format to enable Graphviz visualization.

## 2. Sequential Greedy Implementation
The `src/greedy.cpp` implements the Welsh-Powell algorithm, which takes the vertices in the descending order of their degree and assigns them the first color that isn't used by any of their neighbors. This was an unoptimalized but working version of the program.

## 3. Profiling of Sequential Implementation
A **gprof** analysis provided files `profiling/greedy-flat.txt`, `profiling/greedy-annontated.txt`, and `profiling/greedy-callgraph.txt`, which showed that the most expensive operations came from data structures based on hashing (`unordered_set` and related functions).

## 4. Sequential Code Optimizations
The `src/optim-greedy.cpp` is an optimalized greedy algorithm with two main changes:
- Added memory pre-allocations for several vectors to prevent reallocating when the final size is previously known
- Removed `unordered_set` from all usages and replaced it with adjacency vectors and sorting to remove duplicates

## 5. Parallel Implementation
The `src/parallel.cpp` uses **Luby’s algorithm** to parallely find maximal independent sets, and colors independent sets of vertices in parallel and then reduces conflicts.

OpenMP was used for parallelization.

## 6. Comparison of Results and Measurement of Speedup and Efficiency
I compared the parallel and optimized sequential algorithms in runtime and number of colors used. The results are stored in `profiling/final.csv`.

The `profiling/final-compare-measure.sh` script runs both (optimalized) greedy and parallelized program on all `.col` graphs in the `data` folder 10 times (by default). It measures wall-clock, user and system time of each execution, then computes the median of those per input, together with the number of colors used. It produces a summary `.csv` file for each graph and algorithm. Then it uses mainly `awk` to merge these files and compute the speedup and parallel algorithm efficiency from the median of wall-clock time.