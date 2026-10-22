"""플레이 테스트 결과 모아 보기. 친구들이 보낸 "테스트 결과 복사" 내용(요약 + --- + JSON)이나 playtest.json 파일을 받아
스테이지별 중앙값 시간·포기율 표를 출력한다. 기준: 중앙값 5분 안이면 적정, 10분 넘으면 표시.

    python3 tools/playtest_report.py 친구1.txt 친구2.txt user_playtest.json
"""
import json
import statistics
import sys

STAGE_ORDER = [f"level_{c}_{k}" for c in (1, 2, 3) for k in range(1, 6)]
OK_SEC = 5 * 60
SLOW_SEC = 10 * 60


def load(path: str) -> dict:
    text = open(path, encoding="utf-8").read()
    # 복사한 글이면 마지막 "---" 뒤가 JSON
    if "---" in text:
        text = text.rsplit("---", 1)[1]
    start = text.find("{")
    return json.loads(text[start:])


def mmss(sec: float) -> str:
    s = int(round(sec))
    return f"{s // 60}:{s % 60:02d}"


def main(paths: list) -> None:
    players = []
    for p in paths:
        try:
            players.append((p, load(p)))
        except (OSError, ValueError) as e:
            print(f"읽지 못함: {p} ({e})", file=sys.stderr)
    if not players:
        print(__doc__)
        return
    print(f"플레이어 {len(players)}명: " + ", ".join(p for p, _ in players))
    print()
    print("| 스테이지 | 시작 | 클리어 | 포기율 | 클리어 시간 중앙값 | 루프 중앙값 | 되돌리기 | 처음부터 | 고스트 중앙값 | 판정 |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    ids = STAGE_ORDER + sorted({s for _, d in players for s in d.get("stages", {})} - set(STAGE_ORDER))
    for sid in ids:
        rows = [d["stages"][sid] for _, d in players if sid in d.get("stages", {}) and d["stages"][sid].get("starts", 0) > 0]
        if not rows:
            continue
        cleared = [r for r in rows if r.get("cleared")]
        quit_rate = 1.0 - len(cleared) / len(rows)
        times = [r["first_clear_sec"] for r in cleared if r.get("first_clear_sec", -1) >= 0]
        med_time = statistics.median(times) if times else None
        loops = statistics.median([r.get("loops", 0) for r in rows])
        undos = sum(r.get("undos", 0) for r in rows)
        restarts = sum(r.get("restarts", 0) for r in rows)
        ghosts = statistics.median([r["best_ghosts"] for r in cleared]) if cleared else None
        if med_time is None:
            verdict = "⚠ 아무도 못 깸"
        elif med_time > SLOW_SEC:
            verdict = "⚠ 10분 초과"
        elif med_time <= OK_SEC:
            verdict = "적정"
        else:
            verdict = "주의(5~10분)"
        if quit_rate >= 0.5 and med_time is not None:
            verdict += " · 포기 많음"
        code = sid.replace("level_", "").replace("_", "-")
        print(f"| {code} | {len(rows)} | {len(cleared)} | {quit_rate:.0%} | {mmss(med_time) if med_time is not None else '-'} | "
              f"{loops:g} | {undos} | {restarts} | {ghosts if ghosts is not None else '-'} | {verdict} |")


if __name__ == "__main__":
    main(sys.argv[1:])
