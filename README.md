# Comparison of sequential greedy and parallel algorithms on the vertex coloring problem

## 1. Vertex Coloring
The task is to assign colors to vertices of a graph so that no two adjacent vertices share the same color, while minimizing the total number of colors used. It is an NP-hard problem.

The input graphs are provided in the /data folder in .col format, and were collected from the following sites:
https://mat.tepper.cmu.edu/COLOR/instances.html
https://networkrepository.com/dimacs.php

The output is expected in the .dot format to enable Graphviz visualization.

## 2. Sequential Greedy Implementation
The /src.greedy.cpp implements the Welsh-Powell algorithm, which takes the vertices in the descending order of their degree and assigns them the first color that isn't used by any of their neighbors. This was an unoptimalized but working version of the program.

## 3. Profiling of Sequential Implementation
A **gprof** analysis provided files profiling/greedy-flat.txt, profiling/greedy-annontated.txt, and profiling/greedy-callgraph.txt, which showed that the most expensive operations came from data structures based on hashing (`unordered_set` and related functions).

## 4. Sequential Code Optimizations
- Added memory pre-allocations for several vectors to prevent reallocating when the final size is previously known
- Removed `unordered_set` from all usages and replaced it with adjacency vectors and sorting to remove duplicates

## 5. Parallel Implementation


## 6. Comparison of Results


## 7. Measurement of Speedup and Efficiency
 
