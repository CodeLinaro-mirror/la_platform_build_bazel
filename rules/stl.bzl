# Helpers for stl property resolution.
# These mappings taken from build/soong/cc/stl.go

_libcpp_stl_names = {"libc++" : True,
                     "libc++_static": True,
                     "c++_shared": True,
                     "c++_static": True,
                     "": True,
                     "system": True}

def static_stl_deps(stl_name):
  # TODO(b/201079053): Handle useSdk, windows, fuschia, preferably with selects.
  if stl_name in _libcpp_stl_names:
      return ["//external/libcxx:libc++_static"]
  elif stl_name == "none":
      return []
  else:
      fail("Unhandled stl %s" % stl_name)

def shared_stl_deps(stl_name):
  # TODO(b/201079053): Handle useSdk, windows, fuschia, preferably with selects.
  if stl_name in _libcpp_stl_names:
      return ["//external/libcxx:libc++"]
  elif stl_name == "none":
      return []
  else:
      fail("Unhandled stl %s" % stl_name)


