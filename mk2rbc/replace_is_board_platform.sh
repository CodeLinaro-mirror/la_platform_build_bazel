#! /bin/bash
##CL Replace is-board-platform[-in-list] with is-board-platform[-in-list]2
##CL
##CL Bug: 201477826
##CL Test: treehugger
declare -r files="$(grep -rlP '^[^#]*call +is-board-platform' --include '*.mk' --exclude 'utils_test.mk' --exclude 'utils_sample_usage.mk')"
[[ -z "$files" ]] || sed -i -r -f <(cat <<"EOF"
s/ifeq +\(\$\(call is-board-platform,(.*)\), *true\)/ifneq (,$(call is-board-platform2,\1))/
s/ifeq +\(\$\(call is-board-platform,(.*)\), *\)/ifeq (,$(call is-board-platform2,\1))/
s/ifneq +\(\$\(call is-board-platform,(.*)\), *true\)/ifeq (,$(call is-board-platform2,\1))/
s/ifeq +\(\$\(call is-board-platform-in-list,(.*)\), *true\)/ifneq (,$(call is-board-platform-in-list2,\1))/
s/ifeq +\(\$\(call is-board-platform-in-list,(.*)\), *\)/ifeq (,$(call is-board-platform-in-list2,\1))/
s/ifeq +\(\$\(call is-board-platform-in-list,(.*)\), *false\)/ifeq (,T)  # TODO: remove useless check/
s/ifneq +\(\$\(call is-board-platform-in-list,(.*)\), *true\)/ifeq (,$(call is-board-platform-in-list2,\1))/
s/\$\(call is-board-platform,(.*)\)/$(call is-board-platform2,\1)/
EOF
) $files
