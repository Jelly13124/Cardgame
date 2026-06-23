#!/usr/bin/env python3
"""Generate game art via Google's Imagen 4 (Gemini API).

The API key is read from `.gemini_key` (gitignored — NEVER commit it). This is the
art pipeline used for backgrounds (events / shop / base) — opaque full-bleed images
that Godot cover-fits behind UI. (Codex / ADR-0005 still applies for transparent
icons + frames; Imagen does not do alpha.)

Usage:
  python scripts/gen_art_gemini.py <out.png> <aspect:1:1|16:9|9:16|4:3|3:4> "<prompt>"

Exit 0 on success. Retries on 429/503 with backoff so a batch survives rate limits.
"""
import sys, json, base64, time, os, urllib.request, urllib.error

KEY_FILE = ".gemini_key"
# imagen-4.0-fast = great quality, cheaper/faster; bump to imagen-4.0-generate-001
# for hero pieces if a fast result underwhelms.
MODEL = os.environ.get("IMAGEN_MODEL", "imagen-4.0-fast-generate-001")

# Shared house style so every generated background reads as one game.
STYLE = (
    " — hand-painted 2D cartoon game art, painterly, warm rusty post-apocalyptic "
    "wasteland palette, soft atmospheric light, gentle vignette, cohesive with a "
    "SteamWorld-style salvage aesthetic. No text, no words, no logos, no UI, no "
    "characters, no people. Background plate only."
)


def gen(out: str, aspect: str, prompt: str, retries: int = 5) -> bool:
    key = open(KEY_FILE).read().strip()
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{MODEL}:predict?key={key}"
    )
    body = json.dumps(
        {
            "instances": [{"prompt": prompt + STYLE}],
            "parameters": {"sampleCount": 1, "aspectRatio": aspect},
        }
    ).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url, data=body, headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=150) as r:
                d = json.loads(r.read())
            preds = d.get("predictions", [])
            if preds and preds[0].get("bytesBase64Encoded"):
                os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
                open(out, "wb").write(base64.b64decode(preds[0]["bytesBase64Encoded"]))
                kb = os.path.getsize(out) // 1024
                print(f"OK  {out}  ({kb} KB)")
                return True
            print("no-image:", json.dumps(d)[:200])
            return False
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:160]
            print(f"HTTP {e.code} (attempt {attempt + 1}/{retries}): {msg}")
            if e.code in (429, 500, 503):
                time.sleep(10 * (attempt + 1))
                continue
            return False
        except Exception as e:  # noqa: BLE001
            print(f"err (attempt {attempt + 1}/{retries}): {e}")
            time.sleep(6)
            continue
    return False


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    sys.exit(0 if gen(sys.argv[1], sys.argv[2], sys.argv[3]) else 1)
