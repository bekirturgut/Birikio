from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
logo = (root/'artifacts/birikio-logo.svg').read_text()
paths = re.search(r'<svg[^>]*>(.*)</svg>', logo).group(1)
hero = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="400" viewBox="0 0 1200 400" role="img" aria-label="Birikio — Biriktir. Büyüt. Hayaline ulaş.">
<defs>
  <linearGradient id="bg" x2="1" y2="1"><stop stop-color="#101726"/><stop offset="1" stop-color="#211d36"/></linearGradient>
  <radialGradient id="glow"><stop stop-color="#70e5bc" stop-opacity=".16"/><stop offset="1" stop-color="#70e5bc" stop-opacity="0"/></radialGradient>
</defs>
<rect width="1200" height="400" rx="28" fill="url(#bg)"/>
<circle cx="981" cy="187" r="230" fill="url(#glow)"/>
<g fill="none" stroke="#b9a3ff" stroke-opacity=".13"><circle cx="974" cy="200" r="150"/><circle cx="974" cy="200" r="184"/></g>
<g transform="translate(828 58) scale(2.8)">{paths}</g>
<text x="64" y="69" fill="#70e5bc" font-family="Arial,sans-serif" font-size="12" font-weight="700" letter-spacing="3">KİŞİSEL FİNANS · TAMAMEN YEREL</text>
<text x="60" y="166" fill="#f4f6fb" font-family="Arial,sans-serif" font-size="84" font-weight="800" letter-spacing="-4">Birikio</text>
<text x="64" y="224" fill="#ded7ef" font-family="Arial,sans-serif" font-size="28" font-weight="600">Biriktir. Büyüt. Hayaline ulaş.</text>
<text x="64" y="266" fill="#9ca8bc" font-family="Arial,sans-serif" font-size="17">Gelirlerin, giderlerin ve bir sonraki büyük hayalin.</text>
<g font-family="Arial,sans-serif" font-size="12" font-weight="600">
<rect x="64" y="313" width="102" height="32" rx="16" fill="#70e5bc" fill-opacity=".11"/><text x="115" y="334" text-anchor="middle" fill="#70e5bc">Flutter + Dart</text>
<rect x="178" y="313" width="128" height="32" rx="16" fill="#b9a3ff" fill-opacity=".12"/><text x="242" y="334" text-anchor="middle" fill="#c6b5ff">İnternetsiz kullanım</text>
<rect x="318" y="313" width="127" height="32" rx="16" fill="#ffd780" fill-opacity=".10"/><text x="381" y="334" text-anchor="middle" fill="#ffd780">Açık &amp; koyu tema</text>
</g>
</svg>'''
(root/'docs/images/birikio-banner.svg').write_text(hero, encoding='utf-8')
(root/'docs/images/birikio-logo.svg').write_text(logo, encoding='utf-8')
