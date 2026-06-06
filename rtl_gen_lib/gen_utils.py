"""
Shared utilities for the NXP ICLAD 2026 RTL Generation Library.
"""


class MissingParameter(Exception):
    """Raised when a required YAML parameter is absent."""
    pass


def required(spec, key, ip_type):
    """
    Fetch a parameter from the YAML spec dict.
    Raises MissingParameter if the key is not present.
    This enforces that participants explicitly specify every parameter
    rather than relying on silent defaults.
    """
    if key not in spec:
        raise MissingParameter(
            f"[{ip_type}] Required parameter '{key}' is missing from the YAML spec.\n"
            f"  Provided keys: {sorted(spec.keys())}\n"
            f"  Read the architecture docs carefully and infer the correct value."
        )
    return spec[key]


def opt(spec, key, default):
    """Fetch an optional parameter; use default only for truly optional fields."""
    return spec.get(key, default)


def hdr(module, desc=""):
    return (
        f"// {'='*77}\n"
        f"// Module: {module}\n"
        f"// Desc  : {desc}\n"
        "// NXP ICLAD 2026 RTL Gen Library\n"
        f"// {'='*77}\n"
        "`timescale 1ns/1ps\n\n"
    )
