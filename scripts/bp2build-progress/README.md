# bp2build progress graphs

This directory contains tools to generate reports and .png graphs of the
bp2build conversion progress, for any module.

This tool relies on `json-module-graph` and `bp2build` to be buildable targets
for this branch.

## Prerequisites

* `/usr/bin/dot`: turning dot graphviz files into .pngs
* `/usr/bin/jq`: running the query scripts over the json-module-graph.

## Instructions

# Generate the report for a module, e.g. adbd

```
./bp2build-progress.py report adbd
```

# Generate the report for a module, e.g. adbd

```
./bp2build-progress.py graph adbd > graph.in && dot -Tpng -o graph.png graph.in
```
