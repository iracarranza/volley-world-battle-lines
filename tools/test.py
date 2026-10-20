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


def discover_suites(workspace, requested):
    """Select tests from the snapshot that will actually run."""
    directory = workspace / 'tests'
    suites = ([directory / (Path(name).stem + '.gd') for name in requested]
              if requested else sorted(directory.glob('*_test.gd')))
    missing = [str(path.name) for path in suites if not path.is_file()]
    if missing:
        raise ValueError('Unknown suite in selected snapshot: ' + ', '.join(missing))
    if not suites:
        raise ValueError('No behavioral suites found in selected snapshot')
    return suites


def run_suite(command, log_path, timeout):
    """Keep failures readable while a suite runs; a script error cannot recover."""
    with log_path.open('wb') as log:
        try:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        except OSError as error:
            log.write(f'PROCESS ERROR: {error}\n'.encode())
            return False, -1
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


def write_results(logs, results):
    """Publish complete JSON without exposing a partially written report."""
    temporary = logs / 'results.json.tmp'
    temporary.write_text(json.dumps(results, indent=2) + '\n')
    temporary.replace(logs / 'results.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suites', nargs='*')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--revision', help='Run an isolated committed snapshot for comparison')
    parser.add_argument('--timeout', type=float, default=90)
    parser.add_argument('--godot', default=os.environ.get('GODOT', shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--logs', type=Path, default=ROOT / 'artifacts' / 'checks')
    args = parser.parse_args()
    if not 0 < args.timeout < float('inf'):
        parser.error('--timeout must be a positive finite number')
    args.logs.mkdir(parents=True, exist_ok=True)
    # A setup/import failure must not expose a previous run's successful report.
    (args.logs / 'results.json').unlink(missing_ok=True)
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
        try:
            suites = discover_suites(workspace, args.suites)
        except ValueError as error:
            parser.error(str(error))
        # Godot derives user:// from the project name. Use a unique identity so
        # even tests that instantiate the title cannot read the user's roster.
        config = workspace / 'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + temp + '/userdata"'))
        (workspace / 'artifacts').mkdir()
        command = [args.godot, '--path', str(workspace)]
        start = time.monotonic()
        passed, code = run_suite(
            command + ['--headless', '--editor', '--import'],
            args.logs / 'import.log', args.timeout,
        )
        if not passed:
            write_results(args.logs, [dict(
                suite='__import__', passed=False,
                seconds=round(time.monotonic() - start, 2), exit_code=code,
            )])
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
    write_results(args.logs, results)
    failed = sum(not r['passed'] for r in results)
    print(f'{len(results) - failed}/{len(results)} suites passed. Logs: {args.logs}', flush=True)
    return int(failed > 0)

if __name__ == '__main__':
    sys.exit(main())
