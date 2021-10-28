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

apex_key = rule(
    implementation = _apex_key_rule_impl,
    attrs = {
        "public_key": attr.label(mandatory = True, allow_single_file = True),
        "private_key": attr.label(mandatory = True, allow_single_file = True),
    },
)
