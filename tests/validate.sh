#!/usr/bin/env bash
# Pre-flight checks for this plugin, run before every push.
#
#   1. The manifest still satisfies the schema the shell enforces.
#   2. suretune-ctl parses. A syntax error here means the bar widget
#      silently loses its backend, which looks like "the icon stopped
#      working" rather than an error.
#   3. The catalogue tests pass — the curated ad-free ordering above all.

set -euo pipefail

cd "$(dirname "$0")/.."

fail() { echo "validate: $*" >&2; exit 1; }

echo "==> manifest"
omarchy plugin validate . || fail "manifest is not valid"

echo "==> backend parses"
python3 -c "import ast,sys; ast.parse(open('suretune-ctl',encoding='utf-8').read())" \
  || fail "suretune-ctl does not parse"

echo "==> seed list"
python3 -c "
import json,sys
data=json.load(open('ad-free-stations.json',encoding='utf-8'))
stations=data.get('stations')
if not isinstance(stations,list) or len(stations)<10:
    sys.exit('ad-free-stations.json needs at least 10 stations')
ranks=[s['rank'] for s in stations]
if ranks!=sorted(ranks):
    sys.exit('ad-free-stations.json is not in rank order')
" || fail "ad-free-stations.json is malformed"

echo "==> tests"
python3 -W error::ResourceWarning tests/test_catalogue.py || fail "catalogue tests failed"

echo "==> ok"
