# CMD: Returns the names of modules of type $arg

include "library";

def modulesOfType($arg):
  [.[] | select(.Type == $arg) | .Name] | unique
;

modulesOfType($arg)