"""Godot をヘッドレスで回す入口(取り込み・テスト・書き出し・スクリプト実行)。窓を出さず、音も出さない。
Godot の場所は環境変数 GODOT(無ければ PATH の godot)。user:// は build/appdata に分ける(環境変数 RR_APPDATA で変えられる)。

    python tools/gd.py import
    python tools/gd.py test [test_core ...]
    python tools/gd.py export
    python tools/gd.py run res://tools/api_probe.gd [引数 ...]
    python tools/gd.py smoke [フレーム数] [--auto など]
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")
LAST_OUT = [b""]


def godot(args: list[str], timeout: int = 600) -> int:
    env = dict(os.environ)
    # user:// を手元の本物と分ける(既定は build/appdata)
    appdata = Path(env.get("RR_APPDATA") or ROOT / "build" / "appdata")
    appdata.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(appdata)
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        done = subprocess.run([GODOT, "--headless", "--path", str(ROOT), *args], env=env, timeout=timeout,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=flags)
    except subprocess.TimeoutExpired as e:
        sys.stdout.buffer.write(e.stdout or b"")
        print(f"\n{timeout} 秒で終わらなかった(スクリプトの構文エラーで本体が立ち上がった時に起きる)")
        return 124
    sys.stdout.buffer.write(done.stdout)
    sys.stdout.flush()
    LAST_OUT[0] = done.stdout
    # テストが呼んだ先のスクリプトエラーは、ランナーからは見えない(その関数が黙って止まる)。出力で拾って失敗にする
    if b"SCRIPT ERROR" in done.stdout and done.returncode == 0:
        print("出力に SCRIPT ERROR がある")
        return 1
    return done.returncode


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "import":
        return godot(["--import"])
    if cmd == "test":
        return godot(["--script", "res://tests/run_tests.gd", "--", *rest], timeout=900)
    if cmd == "export":
        (ROOT / "build" / "web").mkdir(parents=True, exist_ok=True)
        return godot(["--export-release", "Web", "build/web/index.html"])
    if cmd == "smoke":  # 本体を窓なしで frames フレーム動かす。例: smoke 300000 --auto
        frames = rest[0] if rest else "600"
        code = godot(["--fixed-fps", "60", "--quit-after", frames, "--", *rest[1:]])
        # --auto は S0 → 結果を 2 回通して SMOKE done を出す。出なければ途中で止まっている
        if code == 0 and "--auto" in rest and (b"SMOKE done" not in LAST_OUT[0] or b"SMOKE resume" not in LAST_OUT[0]):
            print("SMOKE done が出ていない(どこかの画面で止まった)")
            return 1
        return code
    if cmd == "run" and rest:
        return godot(["--script", rest[0], "--", *rest[1:]])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
