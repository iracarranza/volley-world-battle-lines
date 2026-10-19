#!/usr/bin/env python3
"""One-shot local continuation. Installed only at the user's explicit request.

The launch agent starts this helper now; it queues the existing Codex thread at
an absolute UTC epoch. Sleep/wake delays are logged, never disguised as exact
execution. A success marker prevents duplicate delivery after a launch retry.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--at', type=float, required=True)
parser.add_argument('--thread', required=True)
parser.add_argument('--codex', required=True)
parser.add_argument('--workspace', type=Path, required=True)
parser.add_argument('--marker', type=Path, required=True)
args = parser.parse_args()
if args.marker.exists():
    raise SystemExit(0)
while time.time() < args.at:
    time.sleep(min(60, args.at - time.time()))
message = (
    'Resume the full Volley World cleanup and rendering optimization requested '
    'in this thread. Read docs/cleanup-methodology.md and docs/cleanup-checkpoint.md '
    f'in {args.workspace}. Continue from the verified checkpoint; do not restart '
    'or discard work. Finish the outstanding work and validation. Monitor both '
    'usage windows. The user permits ONE full reset only if weekly remaining '
    'falls below 3%; none has been consumed. If five-hour usage exhausts first, '
    'checkpoint and resume at its next replenishment. This is the authorized '
    'one-time continuation, not a new reminder or recurring schedule.'
)
for attempt in range(6):
    result = subprocess.run(
        [args.codex, 'queue', '--thread', args.thread, '--message', message],
        cwd=args.workspace, capture_output=True, text=True, timeout=60,
    )
    print(result.stdout, result.stderr, flush=True)
    if result.returncode == 0:
        args.marker.write_text(json.dumps({
            'scheduled_epoch': args.at,
            'queued_at': datetime.now(timezone.utc).isoformat(),
            'thread': args.thread,
        }, indent=2) + '\n')
        break
    time.sleep(30)
else:
    raise SystemExit('Could not queue continuation; inspect the launch-agent log.')
