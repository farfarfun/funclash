import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

binary = str(Path(sys.argv[1]).resolve())
env = os.environ.copy()
for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'FUNCLASH_HEADLESS'):
    env.pop(key, None)

with tempfile.TemporaryDirectory(prefix='funclash-headless-') as data:
    def command(*args):
        return [binary, '--data-dir', data, *args]

    terms = subprocess.run(command('--show-disclaimer'), env=env,
                           capture_output=True, text=True, timeout=30)
    assert terms.returncode == 0, terms.stdout + terms.stderr
    denied = subprocess.run(command(), env=env, capture_output=True,
                            text=True, timeout=30)
    assert denied.returncode != 0, denied.stdout
    assert '--accept-disclaimer' in denied.stdout, denied.stdout + denied.stderr
    log_path = Path(data) / 'startup.log'
    with log_path.open('w') as log:
        app = subprocess.Popen(command('--accept-disclaimer'), env=env,
                               stdout=log, stderr=subprocess.STDOUT,
                               start_new_session=True)
        try:
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                output = log_path.read_text()
                if 'Headless startup ready' in output:
                    break
                assert app.poll() is None, output
                time.sleep(0.25)
            else:
                raise AssertionError(log_path.read_text())
            # Safe mode never binds a panel; the CLI can still save/read settings.
            blocked = subprocess.run(command('--panel', '--panel-url'), env=env,
                                     capture_output=True, text=True, timeout=30)
            assert blocked.returncode != 0, blocked.stdout
            assert 'Stop FunClash' in blocked.stdout, blocked.stdout + blocked.stderr
        finally:
            app.terminate()
            try:
                app.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(app.pid, signal.SIGKILL)
                app.wait()
    assert app.returncode == 0, log_path.read_text()
    assert '[APP] exit' in log_path.read_text(), log_path.read_text()
    for args in (('--panel', '--allow-lan', '--panel-url'), ('--panel-url',)):
        link = subprocess.run(command(*args), env=env, capture_output=True,
                              text=True, timeout=30)
        assert link.returncode == 0, link.stdout + link.stderr
        assert 'http://127.0.0.1:47891/' in link.stdout, link.stdout
        assert '#token=' in link.stdout, link.stdout
print('Headless consent, startup, locking and panel CLI checks passed')
