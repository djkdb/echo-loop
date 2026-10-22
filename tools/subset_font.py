"""Noto Sans KR 서브셋 만들기(웹 빌드 용량 줄이기). 웹 내보내기에서 제외되는 개발 도구.

    pip install fonttools
    python3 tools/subset_font.py <원본 NotoSansKR-Bold.otf> assets/fonts/NotoSansKR-Bold.otf

남기는 글자: ASCII·라틴-1, 문장부호·화살표·도형·★ 같은 기호, 한글 자모, KS X 1001 상용 한글 2,350자,
그리고 프로젝트 스크립트·씬·릴스 문구(tools/reels_copy.json)에 실제로 쓰인 모든 글자(상용 밖의 한글이 들어가도 빠지지 않게).
새 문구에 상용 밖 글자를 쓰면 이 스크립트를 다시 돌린다(원본은 Google Fonts의 Noto Sans KR).
"""
import os
import sys

from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def wanted_codepoints() -> set:
    cps = set(range(0x20, 0x7F)) | set(range(0xA0, 0x100))
    for lo, hi in [(0x2010, 0x205E), (0x2190, 0x21FF), (0x2200, 0x22FF), (0x25A0, 0x25FF), (0x2600, 0x26FF),
                   (0x3000, 0x303F), (0x3131, 0x318E), (0xFF01, 0xFF5E)]:
        cps |= set(range(lo, hi + 1))
    # KS X 1001 상용 한글 2,350자 = EUC-KR 0xB0A1 ~ 0xC8FE
    for hi in range(0xB0, 0xC9):
        for lo in range(0xA1, 0xFF):
            try:
                cps.add(ord(bytes([hi, lo]).decode("euc-kr")))
            except UnicodeDecodeError:
                pass
    # 프로젝트에 실제로 쓰인 글자
    for base, _dirs, files in os.walk(ROOT):
        if "/.godot" in base or "/.git" in base or "/build" in base:
            continue
        for f in files:
            if f.endswith((".gd", ".tscn", ".tres", ".cfg")) or f == "reels_copy.json":
                with open(os.path.join(base, f), encoding="utf-8", errors="ignore") as fh:
                    cps |= {ord(c) for c in fh.read() if ord(c) > 0x7F}
    return cps


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.hinting = False
    font = subset.load_font(src, options)
    sub = subset.Subsetter(options)
    sub.populate(unicodes=sorted(wanted_codepoints()))
    sub.subset(font)
    subset.save_font(font, dst, options)
    print("%s: %d -> %d bytes" % (dst, os.path.getsize(src), os.path.getsize(dst)))


if __name__ == "__main__":
    main()
