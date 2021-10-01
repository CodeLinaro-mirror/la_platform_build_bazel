# CMD: Returns the modules in the transitive closure of module $arg

include "library";

[((moduleGraphNoVariants | removeSelfEdges) as $m |
  [$arg] |
  transitiveDeps($m)) as $names |
  .[] |
  select (IN(.Name; $names | .[]))] |
  sort_by(.Name)


