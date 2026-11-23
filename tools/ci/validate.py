"""Run the same bounded Godot checks locally and on GitHub Actions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LOGS = ROOT / '.ci-logs'
ERROR = re.compile(r'(?:SCRIPT ERROR:|ERROR:|Parse Error:)', re.IGNORECASE)


def run(label, command, timeout=180):
    print(f'[{label}]', flush=True)
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout,
                                env={**os.environ, 'NO_COLOR': '1'})
    except subprocess.TimeoutExpired as exc:
        (LOGS / f'{label}.log').write_bytes(exc.output or b'')
        raise RuntimeError(f'{label}: timed out after {timeout}s') from exc
    output = result.stdout.decode('utf-8', errors='replace')
    (LOGS / f'{label}.log').write_text(output, encoding='utf-8')
    print(output, flush=True)
    # Godot can report script/import errors while returning exit status zero.
    if result.returncode or ERROR.search(output):
        raise RuntimeError(f'{label}: exit={result.returncode}; inspect log')
    return output


def check_lfs():
    manifest = json.loads(run('lfs-manifest', ['git', 'lfs', 'ls-files', '--json']))
    for item in manifest['files']:
        path = ROOT / item['name']
        if not path.is_file():
            raise RuntimeError(f'Missing LFS asset: {item["name"]}')
        with path.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        if path.stat().st_size != item['size'] or digest != item['oid']:
            raise RuntimeError(f'LFS pointer or damaged asset: {item["name"]}')
    print(f'LFS verified: {len(manifest["files"])} files')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    LOGS.mkdir(exist_ok=True)
    check_lfs()
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    forbidden = [p for p in tracked if p.startswith(('.godot/', 'build/'))
                 or Path(p).suffix.lower() in ('.exe', '.pck')]
    if forbidden:
        raise RuntimeError(f'Tracked cache/export files: {forbidden}')
    version = run('version', [args.godot, '--version'], 30).strip()
    if not version.startswith('4.7.2.stable.'):
        raise RuntimeError(f'Expected Godot 4.7.2 stable; got {version}')
    base = [args.godot, '--headless', '--path', str(ROOT)]
    run('import', base + ['--editor', '--import', '--quit'])
    project = (ROOT / 'project.godot').read_text(encoding='utf-8-sig')
    if re.search(r'^run/main_scene=', project, re.MULTILINE):
        run('main-scene', base + ['--quit-after', '10'], 45)
    else:
        print('SKIP main scene: starter project has no run/main_scene yet.')
    # Load the major entry scenes independently; opening alone cannot reach gameplay.
    for name in ('main_menu', 'game', 'game_over'):
        if (ROOT / f'scenes/{name}.tscn').exists():
            run(f'scene-{name}', base + [f'res://scenes/{name}.tscn', '--quit-after', '10'], 45)
    print('CI_OK: LFS, import and available scene startup checks passed.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as exc:
        LOGS.mkdir(exist_ok=True)
        (LOGS / 'failure.log').write_text(str(exc), encoding='utf-8')
        print(f'CI_FAILED: {exc}', file=sys.stderr)
        sys.exit(1)
