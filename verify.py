from pathlib import Path
from html.parser import HTMLParser
root=Path(__file__).parent/'dist'
class Parser(HTMLParser):
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='a' and a.get('href','').startswith('/'):
   href=a['href'].split('?')[0].split('#')[0]
   assert (root/href.lstrip('/')/'index.html').exists(),href
pages=list(root.rglob('index.html'))
for p in pages:
 html=p.read_text(encoding='utf-8');Parser().feed(html)
 assert '<title>' in html and 'rel="canonical"' in html and 'lang="pt-BR"' in html
assert len(pages)==16,len(pages)
assert 'service_role' not in (root/'config.js').read_text()
print(f'PASS: {len(pages)} HTML pages; internal header/footer links; metadata; no privileged key in config.')
