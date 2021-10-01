"""Parallels variable.go to provide variables and create a platform based on converted config."""

load("//build/bazel/product_variables:constants.bzl", "constants")

def _product_variables_providing_rule_impl(ctx):
    return [
        platform_common.TemplateVariableInfo(ctx.attr.product_vars),
    ]

# Provides product variables for templated string replacement.
product_variables_providing_rule = rule(
    implementation = _product_variables_providing_rule_impl,
    attrs = {
        "product_vars": attr.string_dict(),
    },
)

_arch_os_only_suffix = "_arch_os"
_product_only_suffix = "_product"

def product_variable_config(name, product_config_vars):
    local_vars = dict(product_config_vars)

    # Native_coverage is not set within soong.variables, but is hardcoded
    # within config.go NewConfig
    local_vars["Native_coverage"] = (
        local_vars.get("ClangCoverage", False) or
        local_vars.get("GcovCoverage", False)
    )

    providing_vars = {}
    constraints = []
    for (var, value) in local_vars.items():
        # TODO(b/187323817): determine how to handle remaining product
        # variables not used in product_variables
        constraint_var = var.lower()
        if not constants.ProductVariables.get(constraint_var):
            continue

        # variable.go excludes nil values
        add_constraint = (value != None)
        if type(value) == "bool":
            providing_vars[var] = str(1 if value else 0)

            # variable.go special cases bools
            add_constraint = value
        elif type(value) == "list":
            providing_vars[var] = ",".join(value)
        elif type(value) == "int":
            providing_vars[var] = str(value)
        elif type(value) == "string":
            providing_vars[var] = value

        if add_constraint:
            constraints.append("//build/bazel/product_variables:" + constraint_var)

    native.platform(
        name = name + _product_only_suffix,
        constraint_values = constraints,
    )

    arch = local_vars.get("DeviceArch")
    os = "android"

    native.platform(
        name = name,
        constraint_values = constraints + [
            "//build/bazel/platforms/arch:" + arch,
            "//build/bazel/platforms/os:" + os,
        ],
    )

    product_variables_providing_rule(
        name = name + "_product_vars",
        product_vars = providing_vars,
    )

def android_platform(name = None, constraint_values = [], product = None):
    """ android_platform creates a platform with the specified constraint_values and product constraints."""
    native.platform(
        name = name,
        constraint_values = constraint_values,
        parents = [product + _product_only_suffix],
    )
