#!/bin/sh
# The gate (factorium.toml): the library is valid as rolesmith reads it, every role, skill and tool.
set -eu
cd "$(dirname "$0")"
rolesmith check
