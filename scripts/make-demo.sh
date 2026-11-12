#!/usr/bin/env bash
# Render docs/demo.gif + docs/demo.mp4 from docs/screenshots/demo-*.png.
# Requires: python3 with Pillow, ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/make-demo.py

F=/tmp/mackey-demo
ffmpeg -y \
  -loop 1 -t 3.2 -i "$F/slide-0.png" \
  -loop 1 -t 4.2 -i "$F/slide-1.png" \
  -loop 1 -t 3.8 -i "$F/slide-2.png" \
  -loop 1 -t 4.4 -i "$F/slide-3.png" \
  -loop 1 -t 3.8 -i "$F/slide-4.png" \
  -loop 1 -t 3.0 -i "$F/slide-5.png" \
  -filter_complex "\
[0:v]scale=1600:1000,setsar=1,fps=30,format=yuv420p[v0];\
[1:v]scale=1600:1000,setsar=1,fps=30,format=yuv420p[v1];\
[2:v]scale=1600:1000,setsar=1,fps=30,format=yuv420p[v2];\
[3:v]scale=1600:1000,setsar=1,fps=30,format=yuv420p[v3];\
[4:v]scale=1600:1000,setsar=1,fps=30,format=yuv420p[v4];\
[5:v]scale=1600:1000,setsar=1,fps=30,format=yuv420p[v5];\
[v0][v1]xfade=transition=fade:duration=0.5:offset=2.7[x1];\
[x1][v2]xfade=transition=fade:duration=0.5:offset=6.4[x2];\
[x2][v3]xfade=transition=fade:duration=0.5:offset=9.7[x3];\
[x3][v4]xfade=transition=fade:duration=0.5:offset=13.6[x4];\
[x4][v5]xfade=transition=fade:duration=0.5:offset=16.9,trim=duration=19.9[out]" \
  -map "[out]" -c:v libx264 -pix_fmt yuv420p -crf 19 -preset slow \
  -movflags +faststart docs/demo.mp4

ffmpeg -y -i docs/demo.mp4 \
  -vf "fps=12,scale=1000:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
  -loop 0 docs/demo.gif

cp "$F/slide-1.png" docs/demo-poster.png
echo "→ docs/demo.gif"
echo "→ docs/demo.mp4"
