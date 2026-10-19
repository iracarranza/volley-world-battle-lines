#!/usr/bin/env python3
"""Run Godot checks in an isolated project and save per-suite logs.

Usage: python3 tools/test.py [suite stems ...] [--render] [--timeout 90]
No suites means all *_test.gd files. Rendering utilities require --render.
"""
import argparse
import io
import tarfile
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def run_suite(command, log_path, timeout):
    """Keep failures readable while a suite runs; a script error cannot recover."""
    with log_path.open('wb') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + timeout
        try:
            while process.poll() is None:
                output = log_path.read_bytes()
                if b'SCRIPT ERROR:' in output or time.monotonic() >= deadline:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    if time.monotonic() >= deadline:
                        log.write(b'\nTEST TIMEOUT\n')
                    return False, -1
                time.sleep(0.1)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    output = log_path.read_bytes()
    return process.returncode == 0 and b'ERROR:' not in output, process.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suites', nargs='*')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--revision', help='Run an isolated committed snapshot for comparison')
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
        if args.revision:
            revision = subprocess.check_output(['git', 'rev-parse', '--verify', args.revision + '^{commit}'], cwd=ROOT, text=True).strip()
            archive = subprocess.check_output(['git', 'archive', '--format=tar', revision], cwd=ROOT)
            workspace.mkdir()
            with tarfile.open(fileobj=io.BytesIO(archive)) as files:
                files.extractall(workspace, filter='data')
        else:
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
            passed, code = run_suite(
                command + ([] if args.render else ['--headless']) + ['--script', 'res://tests/' + suite.name],
                args.logs / (suite.stem + '.log'), args.timeout,
            )
            seconds = round(time.monotonic() - start, 2)
            results.append(dict(suite=suite.stem, passed=passed, seconds=seconds, exit_code=code))
            print(f'{"PASS" if passed else "FAIL"} {suite.stem} ({seconds}s)', flush=True)
        shutil.copytree(workspace / 'artifacts', args.logs / 'renders', dirs_exist_ok=True)
    (args.logs / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    failed = sum(not r['passed'] for r in results)
    print(f'{len(results) - failed}/{len(results)} suites passed. Logs: {args.logs}', flush=True)
    return int(failed > 0)

if __name__ == '__main__':
    sys.exit(main())
