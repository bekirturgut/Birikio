"""Render Birikio's original vector-style monogram for each platform."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
S = 10
mark = Image.new('RGBA', (100*S,100*S))
for box, radius, hole, hole_radius, color in [((22,47,81,83),18,(39,58,66,71),6.5,'#b9a3ff'), ((22,23,75,58),17.5,(39,34,60,46),6,'#70e5bc')]:
    mask = Image.new('L', mark.size)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(tuple(round(v*S) for v in box), radius=radius*S, fill=255)
    d.rounded_rectangle(tuple(round(v*S) for v in hole), radius=hole_radius*S, fill=0)
    mark.paste(Image.new('RGBA', mark.size, color), (0,0), mask)
d = ImageDraw.Draw(mark)
d.rounded_rectangle((220,230,370,830),radius=60,fill='#70e5bc')
d.ellipse((690,80,870,260), fill='#ffd780')
d.line((780,130,780,210),fill='#0c101b',width=17)
d.line((750,170,810,170),fill='#0c101b',width=17)
image = Image.new('RGB',(1024,1024),'#0c101b')
glyph = mark.resize((760,760),Image.Resampling.LANCZOS)
image.paste(glyph,(132,132),glyph)
# Older launchers receive a circular icon with transparent corners.
legacy = Image.new('RGBA', image.size)
circle = Image.new('L', image.size)
ImageDraw.Draw(circle).ellipse((0, 0, 1023, 1023), fill=255)
legacy.paste(image, (0, 0), circle)
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    legacy.resize((size,size),Image.Resampling.LANCZOS).save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
folder=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((folder/'Contents.json').read_text())['images']:
    size=round(float(item['size'].split('x')[0])*float(item['scale'].removesuffix('x')))
    image.resize((size,size),Image.Resampling.LANCZOS).save(folder/item['filename'])
launch=root/'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for item in json.loads((launch/'Contents.json').read_text())['images']:
    size=168*int(item['scale'][0]);mark.resize((size,size),Image.Resampling.LANCZOS).save(launch/item['filename'])
for size in [192,512]:
    for name in [f'Icon-{size}.png',f'Icon-maskable-{size}.png']:
        image.resize((size,size),Image.Resampling.LANCZOS).save(root/'web/icons'/name)
image.resize((32,32),Image.Resampling.LANCZOS).save(root/'web/favicon.png')
image.save(root/'artifacts/birikio-icon.png')
mark.save(root/'artifacts/birikio-mark.png')
# Same geometry as the Flutter painter, also supplied as an editable vector.
def rounded(x,y,w,h,r):
    return f'M{x+r},{y} H{x+w-r} Q{x+w},{y} {x+w},{y+r} V{y+h-r} Q{x+w},{y+h} {x+w-r},{y+h} H{x+r} Q{x},{y+h} {x},{y+h-r} V{y+r} Q{x},{y} {x+r},{y} Z'
paths=[(rounded(22,47,59,36,18)+' '+rounded(39,58,27,13,6.5),'#B9A3FF'),(rounded(22,23,53,35,17.5)+' '+rounded(39,34,21,12,6),'#70E5BC'),(rounded(22,23,15,60,6),'#70E5BC'),('M69,17 A9,9 0 1,0 87,17 A9,9 0 1,0 69,17','#FFD780'),('M77,13 H79 V16 H82 V18 H79 V21 H77 V18 H74 V16 H77 Z','#0C101B')]
svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'+''.join(f'<path fill="{color}" fill-rule="evenodd" d="{path}"/>' for path,color in paths)+'</svg>'
(root/'artifacts/birikio-logo.svg').write_text(svg)
vector='<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="144dp" android:height="144dp" android:viewportWidth="100" android:viewportHeight="100">'+''.join(f'<path android:fillColor="{color}" android:fillType="evenOdd" android:pathData="{path}"/>' for path,color in paths)+'</vector>'
(root/'android/app/src/main/res/drawable/birikio_mark.xml').write_text(vector)
# Android 8+ owns the outer mask; the foreground contains only the transparent mark.
foreground = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108"><group android:scaleX="0.78" android:scaleY="0.78" android:translateX="11.49" android:translateY="18.51">'+''.join(f'<path android:fillColor="{color}" android:fillType="evenOdd" android:pathData="{path}"/>' for path,color in paths)+'</group></vector>'
(root/'android/app/src/main/res/drawable/birikio_launcher_foreground.xml').write_text(foreground)
adaptive = root/'android/app/src/main/res/mipmap-anydpi-v26'
adaptive.mkdir(exist_ok=True)
(adaptive/'ic_launcher.xml').write_text('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/launch_background"/><foreground android:drawable="@drawable/birikio_launcher_foreground"/></adaptive-icon>')
legacy.save(root/'artifacts/birikio-icon-round.png')
