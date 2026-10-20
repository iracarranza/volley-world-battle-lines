#!/usr/bin/env python3
"""Regression checks for the isolated Godot runner (no Godot required).

Run with: python3 -m unittest discover -s tools -p '*_test.py'
"""
from pathlib import Path
from contextlib import redirect_stdout
import io
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

import test as runner


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name)
        self.tests = self.workspace / 'tests'
        self.tests.mkdir()
        self.log = self.workspace / 'suite.log'

    def test_discovers_only_selected_snapshot(self):
        for name in ('old_test.gd', 'another_test.gd', 'render_old.gd'):
            (self.tests / name).touch()
        self.assertEqual(
            [path.name for path in runner.discover_suites(self.workspace, [])],
            ['another_test.gd', 'old_test.gd'],
        )
        self.assertEqual(
            runner.discover_suites(self.workspace, ['tests/render_old.gd']),
            [self.tests / 'render_old.gd'],
        )

    def test_missing_requested_test_is_explicit(self):
        with self.assertRaisesRegex(ValueError, 'Unknown suite in selected snapshot'):
            runner.discover_suites(self.workspace, ['new_test'])

    def test_empty_snapshot_cannot_pass_as_zero_tests(self):
        with self.assertRaisesRegex(ValueError, 'No behavioral suites'):
            runner.discover_suites(self.workspace, [])

    def run_script(self, source, timeout=3):
        return runner.run_suite([sys.executable, '-c', source], self.log, timeout)

    def test_clean_exit_passes_and_keeps_output(self):
        self.assertEqual(self.run_script("print('passed')"), (True, 0))
        self.assertIn('passed', self.log.read_text())

    def test_zero_exit_with_engine_error_fails(self):
        self.assertEqual(self.run_script("print('ERROR: broken resource')"), (False, 0))

    def test_nonzero_exit_fails(self):
        self.assertEqual(self.run_script('raise SystemExit(7)'), (False, 7))

    def test_script_error_terminates_hung_suite(self):
        passed, _ = self.run_script(
            "import time; print('SCRIPT ERROR: broken', flush=True); time.sleep(30)"
        )
        self.assertFalse(passed)
        self.assertIn('SCRIPT ERROR:', self.log.read_text())
        self.assertNotIn('TEST TIMEOUT', self.log.read_text())

    def test_timeout_terminates_hung_suite(self):
        self.assertEqual(self.run_script('import time; time.sleep(30)', 0.2), (False, -1))
        self.assertIn('TEST TIMEOUT', self.log.read_text())

    def run_fake_engine(self, source, timeout='3'):
        project = self.workspace / 'source'
        (project / 'tests').mkdir(parents=True)
        (project / 'tests' / 'example_test.gd').touch()
        (project / 'project.godot').write_text('[application]\nconfig/name="fixture"\n')
        engine = self.workspace / 'fake-godot'
        engine.write_text(f'#!{sys.executable}\n{source}\n')
        engine.chmod(0o755)
        logs = self.workspace / 'logs'
        logs.mkdir()
        (logs / 'results.json').write_text('[{"suite":"old_test","passed":true}]')
        argv = ['test.py', '--godot', str(engine), '--logs', str(logs), '--timeout', timeout]
        with patch.object(runner, 'ROOT', project), patch.object(sys, 'argv', argv), redirect_stdout(io.StringIO()):
            code = runner.main()
        return code, logs

    def test_failed_import_replaces_old_success_report(self):
        code, logs = self.run_fake_engine("print('SCRIPT ERROR: import broke'); raise SystemExit(1)")
        self.assertEqual(code, 1)
        results = json.loads((logs / 'results.json').read_text())
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['suite'], '__import__')
        self.assertFalse(results[0]['passed'])

    def test_import_timeout_keeps_output_and_reports_failure(self):
        code, logs = self.run_fake_engine(
            "import time; print('import started', flush=True); time.sleep(30)", '0.2'
        )
        self.assertEqual(code, 1)
        self.assertIn('import started', (logs / 'import.log').read_text())
        self.assertIn('TEST TIMEOUT', (logs / 'import.log').read_text())
        self.assertFalse(json.loads((logs / 'results.json').read_text())[0]['passed'])

    def test_zero_exit_import_error_is_not_success(self):
        code, logs = self.run_fake_engine("print('ERROR: missing resource')")
        self.assertEqual(code, 1)
        self.assertFalse(json.loads((logs / 'results.json').read_text())[0]['passed'])
        self.assertEqual(json.loads((logs / 'results.json').read_text())[0]['suite'], '__import__')

    def test_missing_engine_is_logged(self):
        passed, code = runner.run_suite([str(self.workspace / 'missing-engine')], self.log, 3)
        self.assertEqual((passed, code), (False, -1))
        self.assertIn('PROCESS ERROR:', self.log.read_text())

    def test_success_report_keeps_existing_list_schema(self):
        code, logs = self.run_fake_engine("print('ok')")
        self.assertEqual(code, 0)
        results = json.loads((logs / 'results.json').read_text())
        self.assertEqual([r['suite'] for r in results], ['example_test'])
        self.assertTrue(results[0]['passed'])

    def test_invalid_suite_selection_removes_old_success_report(self):
        with patch.object(runner, 'discover_suites', side_effect=ValueError('missing suite')):
            with patch('sys.stderr', new_callable=io.StringIO):
                with self.assertRaises(SystemExit) as error:
                    self.run_fake_engine("print('ok')")
        self.assertEqual(error.exception.code, 2)
        self.assertFalse((self.workspace / 'logs' / 'results.json').exists())


if __name__ == '__main__':
    unittest.main()
