#!/usr/bin/env python3
"""Cuts the demo video from footage recorded by tools/record.sh.

    python tools/make_video.py

Reads from out/video:
    attract.avi            the attract screen with a filled board
    run.avi, run.jsonl     one whole run with the demo player, and its event log
    run_board/             the leaderboard window's frames from the same run
    menu.avi               the booth menu
    card.png               the scouting card page at phone size
Optional:
    ide.mp4                a screen recording of the project in the IDE

Writes out/video/tryout-demo.mp4 (1920x1080, 60 frames a second).

All footage is the game itself, rendered by the engine's movie writer. The
only things added here are the caption bar under the picture, title cards and
the frame around the phone screenshot. Captions are placed from the event log,
so they land on the frame a drill starts.

Needs ffmpeg (set FFMPEG if it is not on the PATH) and Pillow.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "out" / "video"
WORK = SRC / "work"
FONTS = REPO / "assets" / "fonts"
OUT = SRC / "tryout-demo.mp4"

W, H = 1920, 1080
BAR_H = 150                      # caption bar under the picture
PIC_H = H - BAR_H                # 930
PIC_W = round(PIC_H * 16 / 9)    # 1653
PIC_X = (W - PIC_W) // 2
FPS = 60

BG = (7, 11, 23)
BAR = (11, 18, 40)
INK = (244, 248, 255)
DIM = (143, 163, 200)
SKY = (46, 197, 255)
GOLD = (255, 200, 61)

DRILL_LINES = {
    "flick": ("FLICK", "Click every target. Measures aim speed and accuracy."),
    "track": ("TRACK", "Stay on a target that wanders and speeds up. Measures smooth tracking."),
    "react": ("REACT", "Wait for the peek, then click. Reaction time in milliseconds; early clicks count against you."),
    "holdfire": ("HOLD FIRE", "Shoot the red diamonds, leave the blue circles. Measures trigger discipline."),
    "lasthit": ("LAST HIT", "Click a bar the moment it turns gold. Measures timing."),
    "skillshot": ("SKILLSHOT", "Shots take time to travel, so aim ahead. The first target shows where."),
    "mapcheck": ("MAP CHECK", "Six pings flash and vanish. Click where they were. Measures awareness."),
    "clutch": ("CLUTCH", "One against four, five bullets, shorter and shorter windows."),
}


def ffmpeg_bin() -> str:
    env = os.environ.get("FFMPEG")
    if env:
        return env
    found = shutil.which("ffmpeg")
    if found:
        return found
    guess = Path.home() / "AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0-full_build/bin/ffmpeg.exe"
    if guess.exists():
        return str(guess)
    sys.exit("ffmpeg was not found. Set FFMPEG to its path.")


FF = ffmpeg_bin()


def run(args: list[str]) -> None:
    result = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", *args], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("ffmpeg failed:\n" + " ".join(args) + "\n" + result.stderr[-3000:])


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    files = {
        "display": "BarlowCondensed-ExtraBoldItalic.ttf",
        "head": "BarlowCondensed-Bold.ttf",
        "ui": "BarlowCondensed-SemiBold.ttf",
        "body": "BarlowCondensed-Medium.ttf",
        "mono": "JetBrainsMono-Bold.ttf",
    }
    return ImageFont.truetype(str(FONTS / files[kind]), size)


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines: list[str] = []
    line = ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width:
            line = trial
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def caption(name: str, title: str, text: str, note: str = "") -> Path:
    """The bar under the picture: a short title in colour, one or two lines of plain text."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, PIC_H, W, H], fill=BAR + (255,))
    d.rectangle([0, PIC_H, W, PIC_H + 4], fill=SKY + (255,))
    x = 110
    y = PIC_H + 22
    if title:
        d.text((x, y), title, font=font("display", 58), fill=SKY)
        x += int(d.textlength(title, font=font("display", 58))) + 36
    body = font("ui", 44)
    lines = wrap(d, text, body, W - x - 110)
    if len(lines) == 1:
        d.text((x, y + 10), lines[0], font=body, fill=INK)
    else:
        small = font("ui", 40)
        lines = wrap(d, text, small, W - x - 110)[:2]
        for i, line in enumerate(lines):
            d.text((x, y - 6 + i * 48), line, font=small, fill=INK)
    if note:
        nf = font("body", 28)
        d.text((W - 110 - d.textlength(note, font=nf), H - 40), note, font=nf, fill=DIM)
    path = WORK / f"cap_{name}.png"
    img.save(path)
    return path


def backdrop() -> Image.Image:
    """A frame of the attract screen, blurred and dimmed, as the background for title cards."""
    path = WORK / "backdrop.png"
    if not path.exists():
        run(["-ss", "3", "-i", str(SRC / "attract.avi"), "-frames:v", "1",
             "-vf", "format=rgb24,gblur=sigma=36,eq=brightness=-0.16:saturation=1.15", str(path)])
    return Image.open(path).convert("RGB")


def card(name: str, lines: list[tuple[str, str, int, tuple[int, int, int]]], background: Image.Image | None = None) -> Path:
    """A full-frame title card. Each line is (font kind, text, size, colour); an empty text is a gap."""
    img = (background.copy() if background else backdrop()).convert("RGB")
    d = ImageDraw.Draw(img)
    heights = [int(size * 1.22) if text else size for _, text, size, _ in lines]
    y = (H - sum(heights)) // 2
    for (kind, text, size, colour), h in zip(lines, heights):
        if text:
            fnt = font(kind, size)
            d.text(((W - d.textlength(text, font=fnt)) / 2, y), text, font=fnt, fill=colour)
        y += h
    path = WORK / f"card_{name}.png"
    img.save(path)
    return path


def load_events(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def first(events: list[dict], state: str, drill: str | None = None, after: float = -1.0) -> float:
    for e in events:
        if e.get("state") == state and e["t"] > after and (drill is None or e.get("drill") == drill):
            return float(e["t"])
    raise SystemExit(f"The event log has no '{state}' for {drill}.")


VIDEO_OUT = ["-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS),
             "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709"]
TO_TV = "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p,setsar=1"
AUDIO_OUT = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2"]
PICTURE = f"scale={PIC_W}:{PIC_H}:flags=lanczos,pad={W}:{H}:{PIC_X}:0:color=0x070B17"


def footage(name: str, source: Path, start: float, length: float, captions: list[tuple[float, float, Path]], volume: float = 1.0) -> Path:
    """A stretch of game footage, shrunk a little to make room for the caption bar."""
    out = WORK / f"seg_{name}.mp4"
    args = ["-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(source)]
    for _, _, png in captions:
        args += ["-i", str(png)]
    graph = [f"[0:v]format=rgb24,{PICTURE},drawbox=x=0:y={PIC_H}:w={W}:h={BAR_H}:color=0x0B1228:t=fill[v0]"]
    last = "v0"
    for i, (a, b, _) in enumerate(captions, start=1):
        graph.append(f"[{last}][{i}:v]overlay=enable='between(t,{a:.3f},{b:.3f})'[v{i}]")
        last = f"v{i}"
    graph.append(f"[{last}]{TO_TV}[vout]")
    last = "vout"
    fade = f"afade=t=in:d=0.15,afade=t=out:st={max(length - 0.25, 0):.3f}:d=0.25,volume={volume}"
    args += ["-filter_complex", ";".join(graph), "-map", f"[{last}]", "-map", "0:a?", "-af", fade, *VIDEO_OUT, *AUDIO_OUT, str(out)]
    run(args)
    return out


def still(name: str, png: Path, length: float, music: Path | None, music_start: float = 0.0) -> Path:
    """A still picture held for a while, with quiet music under it."""
    out = WORK / f"seg_{name}.mp4"
    args = ["-loop", "1", "-t", f"{length:.3f}", "-i", str(png)]
    if music:
        args += ["-stream_loop", "-1", "-ss", f"{music_start:.3f}", "-t", f"{length:.3f}", "-i", str(music)]
        audio = ["-map", "1:a", "-af", f"volume=0.5,afade=t=in:d=0.3,afade=t=out:st={max(length - 0.4, 0):.3f}:d=0.4"]
    else:
        args += ["-f", "lavfi", "-t", f"{length:.3f}", "-i", "anullsrc=r=48000:cl=stereo"]
        audio = ["-map", "1:a"]
    args += ["-map", "0:v", *audio, "-vf", f"scale={W}:{H},format=rgb24,{TO_TV}", *VIDEO_OUT, *AUDIO_OUT, "-shortest", str(out)]
    run(args)
    return out


def two_screens(name: str, run_avi: Path, board_dir: Path, start: float, length: float, cap: Path, music_volume: float = 1.0) -> Path:
    """The player's screen and the crowd's leaderboard side by side, from the same seconds of the same run."""
    out = WORK / f"seg_{name}.mp4"
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    left = (50, 170, 50 + 1152, 170 + 648)
    right = (1250, 316, 1250 + 624, 316 + 351)
    for box, label in ((left, "PLAYER SCREEN"), (right, "CROWD SCREEN")):
        d.rounded_rectangle([box[0] - 6, box[1] - 6, box[2] + 6, box[3] + 6], radius=14, outline=SKY + (255,), width=4)
        d.text((box[0], box[1] - 62), label, font=font("ui", 44), fill=DIM)
    frame_png = WORK / f"frame_{name}.png"
    frame.save(frame_png)
    first_frame = int(start * 30)
    args = [
        "-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(run_avi),
        "-framerate", "30", "-start_number", str(first_frame), "-t", f"{length:.3f}", "-i", str(board_dir / "b_%05d.png"),
        "-i", str(frame_png), "-i", str(cap),
        "-filter_complex",
        f"color=c=0x070B17:s={W}x{H}:r={FPS}:d={length:.3f}[bg];"
        f"[0:v]format=rgb24,scale={left[2] - left[0]}:{left[3] - left[1]}:flags=lanczos[a];"
        f"[1:v]fps={FPS},format=rgb24,scale={right[2] - right[0]}:{right[3] - right[1]}:flags=lanczos[b];"
        f"[bg]format=rgb24[bg2];[bg2][a]overlay={left[0]}:{left[1]}[x];[x][b]overlay={right[0]}:{right[1]}[y];"
        f"[y][2:v]overlay[z];[z][3:v]overlay[w];[w]{TO_TV}[v]",
        "-map", "[v]", "-map", "0:a?", "-af", f"volume={music_volume},afade=t=in:d=0.2,afade=t=out:st={max(length - 0.3, 0):.3f}:d=0.3",
        *VIDEO_OUT, *AUDIO_OUT, "-t", f"{length:.3f}", str(out),
    ]
    run(args)
    return out


def phone_picture(card_png: Path, cap: Path) -> Path:
    """The card page as it looks on a phone, inside a plain phone outline, next to a few words."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    shot = Image.open(card_png).convert("RGB")
    # The page is a narrow column in the middle of the browser window: keep that column.
    column = min(shot.width, round(shot.height * 0.5))
    side = (shot.width - column) // 2
    shot = shot.crop((side, 0, side + column, shot.height))
    target_h = 850
    target_w = round(shot.width * target_h / shot.height)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)
    x, y = 330, 36
    d.rounded_rectangle([x - 18, y - 18, x + target_w + 18, y + target_h + 18], radius=44, fill=(20, 28, 54), outline=SKY, width=4)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w, target_h], radius=30, fill=255)
    img.paste(shot, (x, y), mask)
    tx = x + target_w + 110
    d.text((tx, 250), "THEIR CARD,", font=font("display", 110), fill=INK)
    d.text((tx, 360), "ON THEIR PHONE", font=font("display", 110), fill=SKY)
    for i, line in enumerate(["Scan the code on the report.", "The whole card travels in the link.", "The booth PC stays offline."]):
        d.text((tx, 520 + i * 62), line, font=font("ui", 50), fill=DIM)
    img.paste(Image.open(cap).convert("RGBA"), (0, 0), Image.open(cap).convert("RGBA"))
    path = WORK / "card_phone.png"
    img.save(path)
    return path


def concat(parts: list[Path], out: Path) -> None:
    listing = WORK / "concat.txt"
    listing.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
    run(["-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy", "-movflags", "+faststart", str(out)])


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    need = [SRC / "attract.avi", SRC / "run.avi", SRC / "run.jsonl", SRC / "menu.avi", SRC / "card.png"]
    missing = [p.name for p in need if not p.exists()]
    if missing:
        sys.exit("Missing in out/video: " + ", ".join(missing) + ". Record them with tools/record.sh first.")

    music = REPO / "assets" / "audio" / "music_attract.wav"
    events = load_events(SRC / "run.jsonl")
    report = next(e for e in events if "report" in e)
    note = "Played here by the game's built-in demo player"
    parts: list[Path] = []

    # 1. The hook and the problem, over the attract screen.
    parts.append(footage("hook", SRC / "attract.avi", 0.5, 14.5, [
        (0.0, 4.2, caption("hook1", "", "Every fan at an esports event thinks they could go pro.")),
        (4.2, 8.4, caption("hook2", "TRYOUT", "gives them sixty seconds to find out.")),
        (8.4, 14.5, caption("hook3", "THE JOB", "A booth game has to pull people in, explain itself, take about a minute and run all day with no Wi-Fi.")),
    ]))

    # 2. One whole run, uncut, from the first click to the last stamp.
    t_brief = first(events, "briefing")
    t_tag = first(events, "tag")
    caps: list[tuple[float, float, Path]] = [
        (0.0, first(events, "card", "flick") - t_brief, caption("brief", "ONE CLICK TO START", "No tutorial. A word on screen before each drill says what to do.", note)),
    ]
    order = list(DRILL_LINES)
    for i, drill in enumerate(order):
        a = first(events, "card", drill) - t_brief
        b = (first(events, "card", order[i + 1]) if i + 1 < len(order) else t_tag) - t_brief
        title, line = DRILL_LINES[drill]
        caps.append((a, b, caption(f"drill{i}", f"{i + 1}/8 {title}", line, note)))
    parts.append(footage("run", SRC / "run.avi", t_brief, t_tag - t_brief, caps))

    # 3. The tag and the scouting report.
    t_report = first(events, "report")
    t_end = t_report + 12.0
    grade = report["grade"]
    parts.append(footage("report", SRC / "run.avi", t_tag, t_end - t_tag, [
        (0.0, t_report - t_tag, caption("tag", "A TAG", "Typed or clicked. It saves itself after 20 seconds and is filtered before it reaches the big screen.", note)),
        (t_report - t_tag, t_end - t_tag, caption("report", "THE SCOUTING REPORT", f"Six attributes, an overall number, a grade ({grade} here), a role fit, a place on today's board, and a card to keep.", note)),
    ]))

    # 4. What makes it a booth game.
    t_two = first(events, "play", "holdfire") - 1.0
    parts.append(two_screens("screens", SRC / "run.avi", SRC / "run_board", t_two, 9.0,
        caption("screens", "A SECOND SCREEN", "The leaderboard has its own window for a screen facing the crowd, with what the current player is doing. Scores stay on the machine.")))
    phone = phone_picture(SRC / "card.png", caption("phone", "NO WI-FI NEEDED", "The QR code is made on the booth PC. Nothing about the player is stored on a server."))
    parts.append(still("phone", phone, 8.0, music, 2.0))
    parts.append(footage("menu", SRC / "menu.avi", 1.0, 6.5, [
        (0.0, 6.5, caption("menu", "A MENU FOR THE CREW", "Volume, screens, export scores to a spreadsheet, clear the board. Every screen also resets on its own.")),
    ], volume=0.6))

    # 5. How it was checked. The numbers come from out/video/facts.json, written by hand from real runs.
    facts = json.loads((SRC / "facts.json").read_text(encoding="utf-8")) if (SRC / "facts.json").exists() else {}
    proof = card("proof", [
        ("ui", "BUILT TO SURVIVE A LONG DAY", 54, SKY),
        ("ui", "", 30, INK),
        ("display", facts.get("tests", "110 automated tests"), 112, INK),
        ("display", facts.get("soak", "1,000 sessions back to back, nothing growing"), 86, INK),
        ("display", facts.get("web", "Web build played in a real browser by script"), 86, INK),
        ("ui", "", 30, INK),
        ("ui", "One codebase: Windows, Linux and the browser.", 50, DIM),
    ])
    parts.append(still("proof", proof, 7.5, music, 10.0))

    # 6. The tools. Only when there is real footage of the IDE.
    ide = SRC / "ide.mp4"
    if ide.exists():
        ide_caption = (SRC / "ide.txt").read_text(encoding="utf-8").strip() if (SRC / "ide.txt").exists() else "Built in JetBrains Rider."
        seg = WORK / "seg_ide.mp4"
        cap = caption("ide", "JETBRAINS RIDER", ide_caption)
        run(["-i", str(ide), "-i", str(cap), "-stream_loop", "-1", "-i", str(music),
             "-filter_complex", f"[0:v]fps={FPS},format=rgb24,{PICTURE}[v0];[v0][1:v]overlay[v1];[v1]{TO_TV}[v]",
             "-map", "[v]", "-map", "2:a", "-af", "volume=0.4", "-shortest", *VIDEO_OUT, *AUDIO_OUT, str(seg)])
        parts.append(seg)

    # 7. Where to find it.
    end = card("end", [
        ("display", "TRYOUT", 260, INK),
        ("ui", "THINK YOU COULD GO PRO?", 70, SKY),
        ("ui", "", 50, INK),
        ("mono", facts.get("play_url", "osakr6604-create.github.io/tryout"), 54, INK),
        ("mono", facts.get("repo_url", "github.com/osakr6604-create/tryout"), 44, DIM),
    ])
    parts.append(still("end", end, 6.0, music, 0.0))

    joined = WORK / "joined.mp4"
    concat(parts, joined)
    # One loudness for the whole video, so the quiet cards and the loud drills sit together.
    run(["-i", str(joined), "-c:v", "copy", "-af", "loudnorm=I=-15:TP=-1.5:LRA=11", *AUDIO_OUT, "-movflags", "+faststart", str(OUT)])
    probe = subprocess.run([FF, "-hide_banner", "-i", str(OUT)], capture_output=True, text=True).stderr
    length = next((line.strip() for line in probe.splitlines() if "Duration" in line), "")
    print(f"wrote {OUT}")
    print(length)


if __name__ == "__main__":
    main()
