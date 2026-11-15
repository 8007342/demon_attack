#!/bin/sh
# boss-hero-assets: append the runs logged by studio_collect.lua for HULL to art/families/boss-hulls-runs.json,
# with verdicts from VERDICTS.json ({"<seed>": "PICK ...|reject ..."}). Run from the repository root.
set -e
H=$1 V=$2 F=art/families/boss-hulls-runs.json L=$HOME/.cache/tillandsias-project/b3/runs.jsonl
jq -s --arg h "$H" --slurpfile v "$V" '[.[] | select(.hull==$h) | .verdict = ($v[0][(.seed|tostring)] // error("no verdict for \(.seed)")) | del(.ticket)]' $L > $L.$H.tmp
jq --slurpfile n $L.$H.tmp '.runs += $n[0]' $F > $F.tmp && mv $F.tmp $F && rm $L.$H.tmp
jq --arg h "$H" '[.runs[]|select(.hull==$h)]|length' $F
