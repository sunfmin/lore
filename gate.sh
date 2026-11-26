#!/bin/sh
# The gate (factorium.toml): the library is valid as rolesmith reads it, every role, skill and tool,
# the cut's install (cut/install-roles) works on a fixture host, and each document fits its kind (docfit.toml).
set -eu
cd "$(dirname "$0")"
rolesmith check
uv run -q --script cut/test_install_roles.py
docfit check
