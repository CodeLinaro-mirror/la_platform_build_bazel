"""
Copyright (C) 2020 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

_CAPTURED_ENV_VARS = [
    "PWD",
    "TARGET_PRODUCT",
    "TARGET_BUILD_VARIANT",
    "COMBINED_NINJA",
    "KATI_NINJA",
    "PACKAGE_NINJA",
    "SOONG_NINJA",
]

_ALLOWED_SPECIAL_CHARACTERS = [
    "/",
    "_",
    "-",
    "'",
    ".",
]

# Since we write the env var value literally into a .bzl file, ensure that the string
# does not contain special characters like '"', '\n' and '\'. Use an allowlist approach
# and check that the remaining string is alphanumeric.
def _validate_env_value(env_var, env_value):
    if env_value == None:
        fail("The env var " + env_var + " is not defined.")

    for allowed_char in _ALLOWED_SPECIAL_CHARACTERS:
        env_value = env_value.replace(allowed_char, "")
    if not env_value.isalnum():
        fail("The value of " +
             env_var +
             " can only consist of alphanumeric and " +
             str(_ALLOWED_SPECIAL_CHARACTERS) +
             " characters: " +
             str(env_value))

def _lunch_impl(rctx):
    env_vars = {}
    for env_var in _CAPTURED_ENV_VARS:
        env_value = rctx.os.environ.get(env_var)
        _validate_env_value(env_var, env_value)
        env_vars[env_var] = env_value

    rctx.file("BUILD.bazel", """
exports_files(["env.bzl"])
""")

    # Re-export captured environment variables in a .bzl file.
    rctx.file("env.bzl", "\n".join([
        item[0] + " = \"" + str(item[1]) + "\""
        for item in env_vars.items()
    ]))

_lunch = repository_rule(
    implementation = _lunch_impl,
    configure = True,
    environ = _CAPTURED_ENV_VARS,
    doc = "A repository rule to capture environment variables based on the lunch choice.",
)

def lunch():
    # Hardcode repository name to @lunch.
    _lunch(name = "lunch")
