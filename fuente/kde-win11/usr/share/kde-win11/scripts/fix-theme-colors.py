#!/usr/bin/env python3
import gzip, re, sys, os
# Quita de los SVG de un tema de Plasma las hojas de estilo ColorScheme-* que no son la
# "current-color-scheme": van detrás y anulan los colores que Plasma inyecta (modo claro/oscuro).
# Uso: fix-theme-colors.py [--fix] <carpetas de tema>...
fix = len(sys.argv) > 1 and sys.argv[1] == "--fix"
roots = sys.argv[2:] if fix else sys.argv[1:]
pat = re.compile(r'<style\b[^>]*>(?:(?!</style>).)*?ColorScheme-[A-Za-z]+(?:(?!</style>).)*?</style>', re.S)
for root in roots:
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if not (f.endswith('.svg') or f.endswith('.svgz')): continue
            p = os.path.join(dp, f)
            raw = open(p, 'rb').read()
            gz = raw[:2] == b'\x1f\x8b'
            try: txt = (gzip.decompress(raw) if gz else raw).decode('utf-8')
            except Exception: continue
            blocks = pat.findall(txt)
            extra = [b for b in blocks if 'id="current-color-scheme"' not in b.split('>')[0]]
            if blocks and extra:
                print(f"{len(extra)} extra\t{p}")
                if fix:
                    for b in extra: txt = txt.replace(b, '', 1)
                    data = txt.encode('utf-8')
                    open(p, 'wb').write(gzip.compress(data) if gz else data)
