#!/usr/bin/env python3
#
# Copyright (C) 2021 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""A json-module-graph postprocessing script to generate a bp2build progress tracker.

Usage:
  ./bp2build-progress.py [report|graph] <module name>

Example:

  To generate a report on the `adbd` module, run:
    ./bp2build-progress report adbd

  To generate a graph on the `adbd` module, run:
    ./bp2build-progress graph adbd > graph.in && dot -Tpng -o graph.png graph.in

"""

import argparse
import os
import os.path
import json
import subprocess
import collections
import datetime
import xml.etree.ElementTree
import sys

# This list of module types are omitted from the report and graph
# for brevity and simplicity. Presence in this list doesn't mean
# that they shouldn't be converted, but that they are not that useful
# to be recorded in the graph or report currently.
IGNORED_KINDS = set([
    "license_kind",
    "license",
    "cc_defaults",
    "cc_prebuilt_object",
    "cc_prebuilt_library_headers",
    "cc_prebuilt_library_shared",
    "cc_prebuilt_library_static",
    "cc_prebuilt_library_static",
    "cc_prebuilt_library",
    "ndk_prebuilt_static_stl",
    "ndk_library",
])

_ModuleInfo = collections.namedtuple("_ModuleInfo", [
    "name",
    "kind",
    "dirname",
])


def generate_module_info(module, use_queryview):
  src_root_dir = os.path.abspath(__file__ + "/../../../../..")

  module_info_target = "queryview" if use_queryview else "json-module-graph"

  # Run soong to build json-module-graph and bp2build/soong_injection
  subprocess.check_output(
      [
          "build/soong/soong_ui.bash",
          "--make-mode",
          "--skip-soong-tests",
          "bp2build",
          module_info_target,
      ],
      cwd=src_root_dir,
      env={
          # Use aosp_arm as the canonical target product.
          "TARGET_PRODUCT": "aosp_arm",
          "TARGET_BUILD_VARIANT": "userdebug",
      },
  )

  module_info = None
  if use_queryview:
    result = subprocess.check_output(
        [
            "tools/bazel", "query", "--config=queryview", "--output=xml",
            'deps(attr("soong_module_name", "^{}$", //...))'.format(module)
        ],
        cwd=src_root_dir,
    )
    module_graph = xml.etree.ElementTree.fromstring(result)
    module_info = module_graph
  else:
    # Run query.sh on the module graph for the top level module
    result = subprocess.check_output(
        [
            "build/bazel/json_module_graph/query.sh", "fullTransitiveDeps",
            "out/soong/module-graph.json", module
        ],
        cwd=src_root_dir,
    )
    module_graph = json.loads(result)
    module_info = module_graph

  # Parse the list of converted module names from bp2build
  converted_modules = []
  with open(
      os.path.join(
          src_root_dir,
          "out/soong/soong_injection/metrics/converted_modules.txt")) as f:
    # Read line by line, excluding comments.
    # Each line is a module name.
    ret = [line.strip() for line in f.readlines() if not line.startswith("#")]
  converted_modules = set(ret)

  return module_info, converted_modules


def get_os_variation(module):
  dep_variations = module.get("Variations")
  dep_variation_os = ""
  if dep_variations != None:
    dep_variation_os = dep_variations.get("os")
  return dep_variation_os


# Generate a dot file containing the transitive closure of the module.
def generate_dot_file(modules, converted, module):
  DOT_TEMPLATE = """
digraph mygraph {{
  node [shape=box];

  %s
}}
"""

  make_node = lambda module, color: \
      ('"{name}" [label="{name}\\n{kind}" color=black, style=filled, '
       "fillcolor={color}]").format(name=module.name, kind=module.kind, color=color)
  make_edge = lambda module, dep: \
      '"%s" -> "%s"' % (module.name, dep)

  # Check that all modules in the argument are in the list of converted modules
  all_converted = lambda modules: all(map(lambda m: m in converted, modules))

  dot_entries = []

  for module, deps in modules.items():
    if module.name in converted:
      # Skip converted modules (nodes)
      continue
    elif module.name not in converted:
      if all_converted(deps):
        dot_entries.append(make_node(module, "yellow"))
      else:
        dot_entries.append(make_node(module, "tomato"))

    # Print all edges for this module
    for dep in list(deps):
      # Skip converted deps (edges)
      if dep not in converted:
        dot_entries.append(make_edge(module, dep))

  print(DOT_TEMPLATE % "\n  ".join(dot_entries))


# Generate a report for each module in the transitive closure, and the blockers for each module
def generate_report(modules, converted, input_module):
  report_lines = []

  report_lines.append("# bp2build progress report for: %s\n" % input_module)
  report_lines.append("Ignored module types: %s\n" % sorted(IGNORED_KINDS))
  report_lines.append("# Transitive dependency closure:")

  # Map of [number of unconverted deps] to list of entries,
  # with each entry being the string: "<module>: <comma separated list of unconverted modules>"
  blocked_modules = collections.defaultdict(list)

  # Map of unconverted modules to the number of modules they're blocking
  # (i.e. number of reverse deps)
  all_unconverted_modules = collections.defaultdict(int)

  dirs_with_unconverted_modules = set()
  kind_of_unconverted_modules = set()

  for module, deps in sorted(modules.items()):
    unconverted_deps = set(dep for dep in deps if dep not in converted)
    for dep in unconverted_deps:
      all_unconverted_modules[dep] += 1

    unconverted_count = len(unconverted_deps)
    if module.name not in converted:
      report_entry = "{name} [{kind}] [{dirname}]: {unconverted_deps}".format(
          name=module.name,
          kind=module.kind,
          dirname=module.dirname,
          unconverted_deps=", ".join(sorted(unconverted_deps)))
      blocked_modules[unconverted_count].append(report_entry)
      dirs_with_unconverted_modules.add(module.dirname)
      kind_of_unconverted_modules.add(module.kind)

  for count, modules in sorted(blocked_modules.items()):
    report_lines.append("\n%d unconverted deps remaining:" % count)
    for module_string in modules:
      report_lines.append("  " + module_string)

  report_lines.append("\n")
  report_lines.append("# Unconverted deps of {}:\n".format(input_module))
  for count, dep in sorted(
      ((count, dep) for dep, count in all_unconverted_modules.items()),
      reverse=True):
    report_lines.append("%s: blocking %d modules" % (dep, count))

  report_lines.append("\n")
  report_lines.append("Dirs with unconverted modules:\n\n{}".format("\n".join(
      sorted(dirs_with_unconverted_modules))))

  report_lines.append("\n")
  report_lines.append("Kinds with unconverted modules:\n\n{}".format("\n".join(
      sorted(kind_of_unconverted_modules))))

  report_lines.append("\n")
  report_lines.append("# Converted modules:\n\n%s" %
                      "\n".join(sorted(converted)))

  report_lines.append("\n")
  report_lines.append(
      "Generated by: https://cs.android.com/android/platform/superproject/+/master:build/bazel/scripts/bp2build-progress/bp2build-progress.py"
  )
  report_lines.append("Generated at: %s" %
                      datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S %z"))
  print("\n".join(report_lines))


def adjacency_list_from_json(module_graph):
  # The set of ignored modules. These modules are not shown in the graph or report.
  ignored = set()

  # A map of module name to _ModuleInfo
  name_to_info = dict()

  # Do a single pass to find all top-level modules to be ignored
  for module in module_graph:
    name = module["Name"]
    if ignore_kind(module["Type"]):
      ignored.add(module["Name"])
      continue
    name_to_info[name] = _ModuleInfo(
        name=name,
        kind=module["Type"],
        dirname=os.path.dirname(module["Blueprint"]))

  # An adjacency list for all modules in the transitive closure, excluding ignored modules.
  module_adjacency_list = {}

  # Create the adjacency list.
  for module in module_graph:
    module_name = module["Name"]
    if module_name in ignored:
      continue
    if get_os_variation(module) == "windows":
      # ignore the windows variations of modules
      continue

    module_info = name_to_info[module_name]
    module_adjacency_list[module_info] = set()
    for dep in module["Deps"]:
      dep_name = dep["Name"]
      if dep_name in ignored or dep_name == module_name:
        continue
      module_adjacency_list[module_info].add(dep_name)

  return module_adjacency_list


def ignore_kind(kind):
  return kind in IGNORED_KINDS or "defaults" in kind


def bazel_target_to_dir(full_target):
  dirname, _ = full_target.split(":")
  return dirname[2:]


def adjacency_list_from_queryview_xml(module_graph):
  # The set of ignored modules. These modules are not shown in the graph or report.
  ignored = set()

  # A map of module name to ModuleInfo
  name_to_info = dict()

  # queryview embeds variant in long name, keep a map of the name with vaiarnt
  # to just name
  name_with_variant_to_name = dict()

  for module in module_graph:
    ignore = False
    if module.tag != "rule":
      continue
    kind = module.attrib["class"]
    name_with_variant = module.attrib["name"]
    name = None
    variant = ""
    for attr in module:
      attr_name = attr.attrib["name"]
      if attr_name == "soong_module_name":
        name = attr.attrib["value"]
      elif attr_name == "soong_module_variant":
        variant = attr.attrib["value"]
      elif attr_name == "soong_module_type" and kind == "generic_soong_module":
        kind = attr.attrib["value"]
      # special handling for filegroup srcs, if a source has the same name as
      # the module, we don't convert it
      elif kind == "filegroup" and attr_name == "srcs":
        for item in attr:
          if item.attrib["value"] == name:
            ignore = True

    if ignore_kind(kind) or variant.startswith("windows") or ignore:
      ignored.add(name_with_variant)
    else:
      name_with_variant_to_name.setdefault(name_with_variant, name)
      name_to_info.setdefault(
          name,
          _ModuleInfo(
              name=name,
              kind=kind,
              dirname=bazel_target_to_dir(name_with_variant),
          ))

  # An adjacency list for all modules in the transitive closure, excluding ignored modules.
  module_adjacency_list = dict()

  for module in module_graph:
    if module.tag != "rule":
      continue
    name_with_variant = module.attrib["name"]
    if name_with_variant in ignored:
      continue

    name = name_with_variant_to_name[name_with_variant]
    module_info = name_to_info[name]
    module_adjacency_list[module_info] = set()
    for attr in module:
      if attr.tag != "rule-input":
        continue
      dep_name_with_variant = attr.attrib["name"]
      if dep_name_with_variant in ignored:
        continue
      dep_name = name_with_variant_to_name[dep_name_with_variant]
      if name == dep_name:
        continue
      module_adjacency_list[module_info].add(dep_name)

  return module_adjacency_list


def main():
  parser = argparse.ArgumentParser(description="")
  parser.add_argument("mode", help="mode: graph or report")
  parser.add_argument("module", help="name of Soong module")
  parser.add_argument(
      "--use_queryview",
      type=bool,
      default=False,
      required=False,
      help="whether to use queryview or module_info")
  args = parser.parse_args()

  mode = args.mode
  top_level_module = args.module
  use_queryview = args.use_queryview

  # The main module graph containing _all_ modules in the Soong build,
  # and the list of converted modules.
  try:
    module_graph, converted = generate_module_info(top_level_module,
                                                   use_queryview)
  except subprocess.CalledProcessError as err:
    print("Error running: '%s':", " ".join(err.cmd))
    print("Output:\n%s" % err.output.decode("utf-8"))
    print("Error:\n%s" % err.stderr.decode("utf-8"))
    sys.exit(-1)

  module_adjacency_list = None
  if use_queryview:
    module_adjacency_list = adjacency_list_from_queryview_xml(module_graph)
  else:
    module_adjacency_list = adjacency_list_from_json(module_graph)

  if mode == "graph":
    generate_dot_file(module_adjacency_list, converted, top_level_module)
  elif mode == "report":
    generate_report(module_adjacency_list, converted, top_level_module)
  else:
    raise RuntimeError("unknown mode: %s" % mode)


if __name__ == "__main__":
  main()
