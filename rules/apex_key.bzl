ApexKeyInfo = provider(
    "Info needed to sign APEX bundles",
    fields={
        "public_key": "File containing the public_key",
        "private_key": "File containing the private key",
    })

def _apex_key_rule_impl(ctx):
    return [
        ApexKeyInfo(public_key = ctx.file.public_key, private_key = ctx.file.private_key)
    ]

_apex_key = rule(
    implementation = _apex_key_rule_impl,
    attrs = {
        "public_key": attr.label(mandatory = True, allow_single_file = True),
        "private_key": attr.label(mandatory = True, allow_single_file = True),
    },
)

def apex_key(
    name,
    public_key,
    private_key,
    **kwargs):
    "Bazel macro to correspond with the APEX key Soong module."

    _apex_key(
        name = name,
        public_key = public_key,
        private_key = private_key,
        **kwargs,
    )
