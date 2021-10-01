# Configuration transitions for APEX rules.
#
# Transitions are a Bazel mechanism to analyze/build dependencies in a different
# configuration (i.e. options and flags). The APEX transition is applied from a
# top level APEX rule to its dependencies via an outgoing edge, so that the
# dependencies can be built specially for APEXes (vs the platform).
#
# e.g. if an apex A depends on some target T, building T directly as a top level target
# will use a different configuration from building T indirectly as a dependency of A. The
# latter will contain APEX specific configuration settings that its rule or an aspect can
# use to create different actions or providers for APEXes specifically..

def _impl(settings, attr):
    # Perform a transition to apply APEX specific build settings on the
    # destination target (i.e. an APEX dependency).
    return {
        "//build/bazel/rules/apex:apex_name" : attr.name, # Name of the APEX
        "//build/bazel/rules/apex:min_sdk_version" : attr.min_sdk_version, # Min SDK version of the APEX
    }

apex_transition = transition(
    implementation = _impl,
    inputs = [],
    outputs = [
        "//build/bazel/rules/apex:apex_name",
        "//build/bazel/rules/apex:min_sdk_version",
    ]
)
