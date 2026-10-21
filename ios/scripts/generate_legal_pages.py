#!/usr/bin/env python3
"""Generate static Pages documents from the same copy bundled in the native app."""
from pathlib import Path
import html
import json

ROOT = Path(__file__).resolve().parents[2]
info = json.loads((ROOT / 'ios/Resources/AppInformation.json').read_text())
escape = html.escape
style = """
:root{color-scheme:dark;font-family:system-ui,-apple-system,BlinkMacSystemFont,sans-serif;background:#09111f;color:#edf3f8;line-height:1.65}
*{box-sizing:border-box}body{margin:0}main{max-width:820px;margin:auto;padding:48px 24px 72px}nav{display:flex;gap:24px;flex-wrap:wrap;font-size:.95rem}a{color:#79e8c8;text-underline-offset:4px}a:focus-visible{outline:2px solid #79e8c8;outline-offset:5px}h1{font-size:clamp(2rem,6vw,3rem);line-height:1.15;margin-top:44px}h2{font-size:1.2rem;line-height:1.35;margin-top:32px}p{color:#bfcbd8}.eyebrow{color:#79e8c8;font-size:.85rem;letter-spacing:.1em;text-transform:uppercase}footer{border-top:1px solid #314258;margin-top:40px;padding-top:24px} @media(prefers-color-scheme:light){:root{color-scheme:light;background:#f5f8fb;color:#10243b}p{color:#3a5067}a,.eyebrow{color:#006c57}}
"""
for name, key, title in [('privacy.html', 'privacy', 'Privacy policy'), ('support.html', 'support', 'Help & support')]:
    sections = '\n'.join(f'<section><h2>{escape(s["title"])}</h2><p>{escape(s["text"])}</p></section>' for s in info[key])
    content = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="description" content="Sky Tonight {escape(title.lower())} and contact details for {escape(info['developer'])}."><title>{title} · Sky Tonight</title><style>{style}</style></head>
<body><main><nav aria-label="Main"><a href="/">Sky Tonight website</a><a href="/privacy.html">Privacy</a><a href="/support.html">Support</a></nav>
<h1>{title}</h1><p class="eyebrow">Sky Tonight · {escape(info['developer'])}</p><p>Updated {escape(info['updated'])}</p>
{sections}
<footer><p>Contact <a href="mailto:{escape(info['email'])}">{escape(info['email'])}</a></p>
<p>Provider information: <a href="https://www.apple.com/legal/privacy/">Apple privacy policy</a> · <a href="https://www.apple.com/legal/privacy/data/en/location-services/">Location Services</a> · <a href="https://www.apple.com/weather/">Apple Weather data sources</a> · <a href="https://www.cloudflare.com/privacypolicy/">Cloudflare privacy</a> · <a href="https://open-meteo.com/en/terms">Website weather provider</a></p></footer>
</main></body></html>
'''
    (ROOT / name).write_text(content)
    print(f'Generated {name}')
