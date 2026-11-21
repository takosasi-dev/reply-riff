"""同梱する字体を、画面に出す文字だけに絞る(KeyFlak の tools/subset_font.py の写し)。

- Noto Sans JP(SlingArc と同じ。画面の字): core/strings.gd の文字列リテラルの全文字と、ASCII の印字できる文字、画面で使う記号。太さの軸は残す
- Shrikhand(v0.3.0。題字と数字): DISPLAY_CHARS の字だけ(日本語は Noto に落とす)。OFL.txt も写す

原本は google/fonts の固定コミットから取り、sha256 を照らす。tools/font_src/ に置き、git には入れない。文言を足したら回し直す。

    pip install fonttools
    python tools/subset_font.py
"""

import hashlib
import re
import sys
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/google/fonts/295d98a7a0c17c68f1341eaeea354e7960ea70d3/ofl/"
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
EXTRA = "−×"  # ui が数字に添える記号
DISPLAY_CHARS = "ReplyRif0123456789,+-/ " + EXTRA  # 題字と数字だけ(ui/kit.gd の Logo・big_label。日本語は Noto に落ちる)
# (原本の名前, 取る先, sha256, 書き出す名前, 日本語の文言も入れるか)
SRC = [("NotoSansJP.ttf", BASE + "notosansjp/NotoSansJP%5Bwght%5D.ttf",
        "c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f", "NotoSansJP-Subset.ttf", True),
       ("Shrikhand-Regular.ttf", BASE + "shrikhand/Shrikhand-Regular.ttf",
        "8ba32f6d6a96fb8dbc92fc1acfbc4d2123d5348063d89b2c3dd784e7afcb81af", "Shrikhand-Subset.ttf", False)]
LICENSES = [(BASE + "shrikhand/OFL.txt", "325e890b8b26fe0a683c3ba24c506d902bdd7034d9c47bd7fa2bb72b5433b9c9", "OFL_Shrikhand.txt")]


def strings_chars() -> set[str]:
    text = (ROOT / "core" / "strings.gd").read_text(encoding="utf-8")
    return set("".join(re.findall(r'"((?:[^"\\\n]|\\.)*)"', text)))


def fetch(url: str, sha: str, name: str) -> Path:
    src = ROOT / "tools" / "font_src" / name
    if not src.exists():
        src.parent.mkdir(parents=True, exist_ok=True)
        print(f"取得: {url}")
        urllib.request.urlretrieve(url, src)
    digest = hashlib.sha256(src.read_bytes()).hexdigest()
    if digest != sha:
        sys.exit(f"{src} の sha256 が違う: {digest}(消して取り直す)")
    return src


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for src_name, url, sha, out_name, ja in SRC:
        chars = (set(ASCII) | set(EXTRA) | strings_chars()) if ja else set(DISPLAY_CHARS)
        src = fetch(url, sha, src_name)
        out = ROOT / "assets" / "fonts" / out_name
        font = TTFont(src)
        options = subset.Options()
        options.layout_features = ["*"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=[ord(c) for c in chars])
        subsetter.subset(font)
        out.parent.mkdir(parents=True, exist_ok=True)
        font.save(out)
        missing = sorted(c for c in chars if ord(c) not in font.getBestCmap())
        print(f"{out.name}: {src.stat().st_size:,} -> {out.stat().st_size:,} バイト、{len(chars)} 文字")
        if missing:
            print(f"  原本に無い文字: {''.join(missing)}")
    for url, sha, name in LICENSES:
        (ROOT / "assets" / "fonts" / name).write_bytes(fetch(url, sha, name).read_bytes())


if __name__ == "__main__":
    main()
