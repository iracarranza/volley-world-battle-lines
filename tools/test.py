#!/usr/bin/env python3
"""Run Godot checks in an isolated project and save per-suite logs.

Usage: python3 tools/test.py [suite stems ...] [--render] [--timeout 90]
No suites means all *_test.gd files. Rendering utilities require --render.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suites', nargs='*')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--timeout', type=float, default=90)
    parser.add_argument('--godot', default=os.environ.get('GODOT', shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--logs', type=Path, default=ROOT / 'artifacts' / 'checks')
    args = parser.parse_args()
    suites = [ROOT / 'tests' / (Path(s).stem + '.gd') for s in args.suites] if args.suites else sorted((ROOT / 'tests').glob('*_test.gd'))
    if any(not p.exists() for p in suites):
        parser.error('Unknown suite: ' + ', '.join(str(p) for p in suites if not p.exists()))
    args.logs.mkdir(parents=True, exist_ok=True)
    results = []
    with tempfile.TemporaryDirectory(prefix='volley-checks-') as temp:
        workspace = Path(temp) / 'project'
        shutil.copytree(ROOT, workspace, ignore=shutil.ignore_patterns('.git', '.godot', 'artifacts', '__pycache__'))
        # Godot derives user:// from the project name. Use a unique identity so
        # even tests that instantiate the title cannot read the user's roster.
        config = workspace / 'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + temp + '/userdata"'))
        (workspace / 'artifacts').mkdir()
        command = [args.godot, '--path', str(workspace)]
        imported = subprocess.run(command + ['--headless', '--editor', '--import'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=args.timeout)
        (args.logs / 'import.log').write_bytes(imported.stdout)
        if imported.returncode or b'SCRIPT ERROR:' in imported.stdout:
            print('Import failed; see', args.logs / 'import.log', flush=True)
            return 1
        for suite in suites:
            start = time.monotonic()
            try:
                result = subprocess.run(command + ([] if args.render else ['--headless']) + ['--script', 'res://tests/' + suite.name], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=args.timeout)
                output, code = result.stdout, result.returncode
                passed = code == 0 and b'SCRIPT ERROR:' not in output and b'ERROR:' not in output
            except subprocess.TimeoutExpired as error:
                output, code, passed = (error.stdout or b'') + b'\nTEST TIMEOUT\n', -1, False
            seconds = round(time.monotonic() - start, 2)
            (args.logs / (suite.stem + '.log')).write_bytes(output)
            results.append(dict(suite=suite.stem, passed=passed, seconds=seconds, exit_code=code))
            print(f'{"PASS" if passed else "FAIL"} {suite.stem} ({seconds}s)', flush=True)
        shutil.copytree(workspace / 'artifacts', args.logs / 'renders', dirs_exist_ok=True)
    (args.logs / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    failed = sum(not r['passed'] for r in results)
    print(f'{len(results) - failed}/{len(results)} suites passed. Logs: {args.logs}', flush=True)
    return int(failed > 0)

if __name__ == '__main__':
    sys.exit(main())
