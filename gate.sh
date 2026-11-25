#!/bin/sh
# The gate (factorium.toml): the library is valid as rolesmith reads it, every role, skill and tool,
# and the cut's install (cut/install-roles) works on a fixture host.
set -eu
cd "$(dirname "$0")"
rolesmith check
uv run -q --script cut/test_install_roles.py
