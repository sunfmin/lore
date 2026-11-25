#!/bin/sh
# The gate (factorium.toml): the library is valid as rolesmith reads it, every role, skill and tool,
# the cut's install (cut/install-roles) works on a fixture host, and new-repo's write-agent-docs
# works on fixture repos.
set -eu
cd "$(dirname "$0")"
rolesmith check
uv run -q --script cut/test_install_roles.py
uv run -q --script tests/test_write_agent_docs.py
