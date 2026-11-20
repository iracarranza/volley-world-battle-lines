#!/usr/bin/env python3
"""Seeded dual run (MS-05): run the scenario catalogue on two builds and diff the outcome traces.

Usage: python3 tools/dual_run.py BASE_REV [CHANGED_REV|WORKTREE] [--godot PATH] [--keep DIR]
  BASE_REV      git revision of the baseline build (at or after MS-02: the scenarios use the seed hooks and MS-03 clock record)
  CHANGED_REV   revision of the changed build, or WORKTREE (default) for the current working tree
Each build is exported to a temp dir (git archive, or a copy of the working tree), the CURRENT harness (tests/support, tests/dump_scenarios.gd)
is overlaid so both builds run the same scenario script, the project is imported with an isolated user dir, and every scenario trace is
dumped as JSON. Traces are compared per scenario with a 1e-9 tolerance on numbers. Exit 0 = zero differences (acceptance, blueprint 3.2);
exit 1 = a difference (list printed). An intentional difference needs a decision record and a register status change.
The two builds never run in one process, and the harness only reads gameplay state.
"""
import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TOLERANCE = 1e-9


def export(rev, destination):
    if rev == 'WORKTREE':
        shutil.copytree(ROOT, destination, ignore=shutil.ignore_patterns('.git', '.godot', 'artifacts', '__pycache__'))
    else:
        commit = subprocess.check_output(['git', 'rev-parse', '--verify', rev + '^{commit}'], cwd=ROOT, text=True).strip()
        archive = subprocess.check_output(['git', 'archive', '--format=tar', commit], cwd=ROOT)
        destination.mkdir()
        with tarfile.open(fileobj=io.BytesIO(archive)) as files:
            files.extractall(destination, filter='data')
        # Overlay the current harness so both builds run identical scenarios.
        shutil.rmtree(destination / 'tests' / 'support', ignore_errors=True)
        shutil.copytree(ROOT / 'tests' / 'support', destination / 'tests' / 'support')
        shutil.copy(ROOT / 'tests' / 'dump_scenarios.gd', destination / 'tests' / 'dump_scenarios.gd')
        (destination / 'tests' / 'golden').mkdir(exist_ok=True)


def dump(rev, godot, workdir, out):
    workspace = workdir / ('build-' + rev.replace('/', '_'))
    export(rev, workspace)
    config = workspace / 'project.godot'
    config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="volley-checks"'))
    home = workdir / ('home-' + rev.replace('/', '_'))
    home.mkdir()
    env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(home / 'data'))
    base = [godot, '--path', str(workspace)]
    subprocess.run(base + ['--headless', '--editor', '--import'], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    result = subprocess.run(base + ['--headless', '--script', 'res://tests/dump_scenarios.gd', '--', '--out', str(out)], env=env, text=True, capture_output=True, timeout=900)
    if result.returncode != 0 or 'SCRIPT ERROR' in result.stdout + result.stderr:
        print((result.stdout + result.stderr)[-2000:])
        raise SystemExit(f'dump failed for {rev}')


def compare(a, b, path, out):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) and not isinstance(b, bool):
        if abs(a - b) > TOLERANCE:
            out.append(f'{path}: {a} != {b}')
    elif type(a) is not type(b):
        out.append(f'{path}: type {type(a).__name__} != {type(b).__name__}')
    elif isinstance(a, dict):
        for key in sorted(set(a) | set(b)):
            if key not in a or key not in b:
                out.append(f'{path}/{key}: present in only one build')
            else:
                compare(a[key], b[key], f'{path}/{key}', out)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append(f'{path}: length {len(a)} != {len(b)}')
        else:
            for index, (x, y) in enumerate(zip(a, b)):
                compare(x, y, f'{path}[{index}]', out)
    elif a != b:
        out.append(f'{path}: {a!r} != {b!r}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('base')
    parser.add_argument('changed', nargs='?', default='WORKTREE')
    parser.add_argument('--godot', default=os.environ.get('GODOT', shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--keep', type=Path, help='keep the dumped traces in this directory')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='volley-dual-') as temp:
        work = Path(temp)
        out_a, out_b = work / 'a', work / 'b'
        dump(args.base, args.godot, work, out_a)
        dump(args.changed, args.godot, work, out_b)
        names_a = sorted(path.name for path in out_a.glob('*.json'))
        names_b = sorted(path.name for path in out_b.glob('*.json'))
        differences = []
        if names_a != names_b:
            differences.append(f'scenario sets differ: {names_a} vs {names_b}')
        for name in sorted(set(names_a) & set(names_b)):
            found = []
            compare(json.loads((out_a / name).read_text()), json.loads((out_b / name).read_text()), name, found)
            differences.extend(found)
        if args.keep:
            shutil.copytree(work, args.keep, dirs_exist_ok=True)
    print(f'{len(names_a)} scenarios compared, {len(differences)} differences')
    for line in differences[:40]:
        print('  ' + line)
    return 1 if differences else 0


if __name__ == '__main__':
    sys.exit(main())
