# -*- coding: utf-8 -*-
"""Compress MC page images: resize + recompress JPEG."""
from PIL import Image
import os

src_dir = r'C:\Users\21972\Desktop\blog-ydj001\static\mc\img'
specs = {
    'hero.jpg': 1600,
    'feature-1.jpg': 1200, 'feature-2.jpg': 1200, 'feature-3.jpg': 1200,
    'gallery-1.jpg': 1200, 'gallery-2.jpg': 1200, 'gallery-3.jpg': 1200,
    'gallery-4.jpg': 1200, 'gallery-5.jpg': 1200,
}
total_in = 0
total_out = 0
for name, maxw in specs.items():
    p = os.path.join(src_dir, name)
    if not os.path.exists(p):
        print('MISSING', name)
        continue
    total_in += os.path.getsize(p)
    im = Image.open(p)
    if im.width > maxw:
        im = im.resize((maxw, int(im.height * maxw / im.width)), Image.LANCZOS)
    im = im.convert('RGB')
    im.save(p, 'JPEG', quality=78, optimize=True, progressive=True)
    total_out += os.path.getsize(p)
    print('%s: %dx%d -> %.2fMB' % (name, im.width, im.height, os.path.getsize(p) / 1024 / 1024))
print('TOTAL: %.1fMB -> %.1fMB' % (total_in / 1024 / 1024, total_out / 1024 / 1024))
