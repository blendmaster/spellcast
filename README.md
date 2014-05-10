spellcast
=========

Spellcast attempts to find better heuristics for the Conflict-Aware Minimum Latency Broadcast Scheduling problem using
the PushGP environment [clojush][1] and an algorithm based on the HCABS heuristic described in 
[_An Approximation Algorithm for Conflict-Aware Broadcast Scheduling in Wireless Ad Hoc Networks_][0].

## Running

To run the genetic evolver starting with a random set of programs, run the main method with [leiningen][2]:

    lein run
    
Some of the best programs I've found are present in the `data` directory. Some of the other methods
will operate on the files to more fully test them against human-made algorithms:

    lein run full-test data/bestfinal.push
    
This will spit out an SVG graph called `test-results.svg` that shows the latency ratio of the given
program vs the best known human algorithm (chose node with the most uninformed neighbors).

You can also attempt to evolve the current algorithms, but clojush doesn't seem to have an easy way to
insert premade programs into the initial population. What I did is run pushGP with `:save-initial-population true`,
then manually copied a premade program over one of the programs in the `data/<timestamp>.ser` file that
is saved. From there, the file can be loaded with `:initial-population <filename>` as the pushgp argument.

## Algorithm Demonstration

The algorithms described in the [approximation algorithm paper][0] are also demoed in javascript + d3,
in the `web` directory of the repository. They show an interactive breakdown of the steps of the algorithm
on a randomly generated graph.

[0]: http://www.cs.utexas.edu/~reza/files/bcast-mobihoc.pf
[1]: https://github.com/lspector/Clojush
[2]: http://leiningen.org/
