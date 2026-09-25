"""Build the static, dependency-free Proje&MOC guide from Markdown."""
from html import escape
from pathlib import Path
import re

base = Path(__file__).resolve().parents[1] / "Değişiklik Yönetimi MOC"
source = (base / "PROJE_MOC_KULLANICI_KILAVUZU.md").read_text(encoding="utf-8")

def inline(text):
    value = escape(text)
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", value)

blocks = []
paragraph = []
listing = False

def flush():
    global paragraph
    if paragraph:
        blocks.append("<p>" + inline(" ".join(paragraph)) + "</p>")
        paragraph = []

for line in source.splitlines():
    stripped = line.strip()
    if not stripped:
        flush()
        if listing:
            blocks.append("</ol>")
            listing = False
        continue
    if stripped.startswith("#"):
        flush()
        level = min(3, len(stripped) - len(stripped.lstrip("#")))
        blocks.append(f"<h{level}>{inline(stripped[level:].strip())}</h{level}>")
        continue
    image = re.fullmatch(r"!\[(.*?)\]\((.*?)\)", stripped)
    if image:
        flush()
        blocks.append(
            f'<figure><img src="{escape(image.group(2), quote=True)}" '
            f'alt="{escape(image.group(1), quote=True)}" loading="lazy">'
            f"<figcaption>{inline(image.group(1))}</figcaption></figure>"
        )
        continue
    item = re.match(r"\d+\.\s+(.*)", stripped)
    if item:
        flush()
        if not listing:
            blocks.append("<ol>")
            listing = True
        blocks.append("<li>" + inline(item.group(1)) + "</li>")
        continue
    paragraph.append(stripped)
flush()
if listing:
    blocks.append("</ol>")

html = """<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Proje&MOC Kullanıcı Kılavuzu · Qdataline</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#17131f;color:#f4f1fa;font:16px/1.7 Inter,system-ui,sans-serif}
header{position:sticky;top:0;background:#211a2c;border-bottom:1px solid #453853;padding:13px max(18px,calc((100vw - 900px)/2));z-index:3}
header a{color:#d7bbff;text-decoration:none;font-weight:700}main{max-width:900px;margin:auto;padding:26px 18px 64px}
h1,h2,h3{line-height:1.23;letter-spacing:-.025em}h1{font-size:clamp(28px,4vw,42px)}h2{margin-top:45px;border-top:1px solid #40364c;padding-top:28px}
p,li{color:#d2cbdc}strong{color:#fff}li{margin:8px 0}figure{margin:25px 0;padding:10px;border:1px solid #40364c;border-radius:12px;background:#211a2c}
figure img{display:block;width:100%;height:auto;border-radius:7px}figcaption{color:#ab9db8;font-size:12px;margin:8px 4px 2px}
</style></head><body><header><a href="/">← Proje&MOC</a></header><main>"""
html += "\n".join(blocks) + "</main></body></html>"
(base / "PROJE_MOC_KULLANICI_KILAVUZU.html").write_text(html, encoding="utf-8")
