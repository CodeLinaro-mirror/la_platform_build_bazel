# Helpers for stl property resolution.
# These mappings taken from build/soong/cc/stl.go

load("//build/bazel/product_variables:constants.bzl", "constants")

_libcpp_stl_names = {"libc++" : True,
                     "libc++_static": True,
                     "c++_shared": True,
                     "c++_static": True,
                     "": True,
                     "system": True}


# https://cs.android.com/android/platform/superproject/+/master:build/soong/cc/stl.go;l=157;drc=55d98d2ba142d6c35894b1092397e2b5a70bc2e8
_common_static_deps = select({
    constants.ArchVariantToConstraints["android"]: ["//external/libcxxabi:libc++demangle"],
    "//conditions:default": [],
})

def static_stl_deps(stl_name):
  # TODO(b/201079053): Handle useSdk, windows, fuschia, preferably with selects.
  if stl_name in _libcpp_stl_names:
      return ["//external/libcxx:libc++_static"] + _common_static_deps
  elif stl_name == "none":
      return []
  else:
      fail("Unhandled stl %s" % stl_name)

def shared_stl_deps(stl_name):
  # TODO(b/201079053): Handle useSdk, windows, fuschia, preferably with selects.
  if stl_name in _libcpp_stl_names:
      return (_common_static_deps, ["//external/libcxx:libc++"])
  elif stl_name == "none":
      return ([], [])
  else:
      fail("Unhandled stl %s" % stl_name)

