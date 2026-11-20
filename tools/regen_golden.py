#!/usr/bin/env python3
"""Regenerate the MS-05 golden scenario traces (tests/golden/*.json) from the CURRENT code.

Usage: python3 tools/regen_golden.py [--godot PATH]
Only run this when a behaviour change was decided and recorded (a decision record plus a divergence-register status change). A refactor
stage must never regenerate goldens: a difference IS the finding. The project is copied to a temp dir with an isolated user dir (like
tools/test.py), the three catalogue shards and the writer ratchet run with `-- --regen`, and the written files are copied back into tests/golden/.
Review `git diff tests/golden` before committing; the commit message must name the decision record.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SHARDS = ['characterization_catalogue_a_test', 'characterization_catalogue_b_test', 'characterization_catalogue_c_test', 'writer_ratchet_test']


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--godot', default=os.environ.get('GODOT', shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--ratchet-only', action='store_true', help='rewrite only tests/golden/writer_ratchet.json (to tighten it after a routing stage)')
    args = parser.parse_args()
    shards = ['writer_ratchet_test'] if args.ratchet_only else SHARDS
    with tempfile.TemporaryDirectory(prefix='volley-golden-') as temp:
        workspace = Path(temp) / 'project'
        shutil.copytree(ROOT, workspace, ignore=shutil.ignore_patterns('.git', '.godot', 'artifacts', '__pycache__'))
        config = workspace / 'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="volley-checks"'))
        home = Path(temp) / 'home'
        home.mkdir()
        env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(home / 'data'))
        base = [args.godot, '--path', str(workspace)]
        subprocess.run(base + ['--headless', '--editor', '--import'], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        (workspace / 'tests' / 'golden').mkdir(exist_ok=True)
        for shard in shards:
            result = subprocess.run(base + ['--headless', '--script', f'res://tests/{shard}.gd', '--', '--regen'], env=env, text=True, capture_output=True)
            lines = [line for line in result.stdout.splitlines() if line.startswith(('CATALOGUE', 'WRITER'))]
            print(shard, result.returncode, lines[-1] if lines else result.stdout[-400:], flush=True)
            if result.returncode != 0:
                return 1
        target = ROOT / 'tests' / 'golden'
        target.mkdir(exist_ok=True)
        written = 0
        for path in sorted((workspace / 'tests' / 'golden').glob('*.json')):
            shutil.copy(path, target / path.name)
            written += 1
        print(f'{written} golden traces written to {target}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
