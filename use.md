


```bash
curl -LsSf https://astral.sh/uv/install.sh | sh

uv sync --python 3.12 --frozen

source .venv/bin/activate

git clone https://huggingface.co/Lightricks/LTX-2.3

uv tool install "huggingface_hub[cli]"

hf auth login

hf download Lightricks/LTX-2.3 ltx-2.3-22b-dev.safetensors \
  --local-dir ./LTX-2.3 \
  --local-dir-use-symlinks False

hf download Lightricks/LTX-2.3 ltx-2.3-22b-distilled-lora-384-1.1.safetensors \
  --local-dir ./LTX-2.3 \
  --local-dir-use-symlinks False

hf download Lightricks/LTX-2.3 ltx-2.3-spatial-upscaler-x2-1.1.safetensors \
  --local-dir ./LTX-2.3 \
  --local-dir-use-symlinks False

hf download google/gemma-3-12b-it-qat-q4_0-unquantized \
  --repo-type model \
  --local-dir ./gemma-3-12b-it-qat-q4_0-unquantized \
  --local-dir-use-symlinks False

ls -lh ./LTX-2.3/ltx-2.3-22b-dev.safetensors
ls -lh ./LTX-2.3/ltx-2.3-22b-distilled-lora-384-1.1.safetensors
ls -lh ./LTX-2.3/ltx-2.3-spatial-upscaler-x2-1.1.safetensors
ls -lh ./gemma-3-12b-it-qat-q4_0-unquantized

python -m ltx_pipelines.keyframe_interpolation --help

python -m ltx_pipelines.keyframe_interpolation \
    --checkpoint-path ./LTX-2.3/ltx-2.3-22b-dev.safetensors \
    --distilled-lora ./LTX-2.3/ltx-2.3-22b-distilled-lora-384-1.1.safetensors 1.0 \
    --spatial-upsampler-path ./LTX-2.3/ltx-2.3-spatial-upscaler-x2-1.1.safetensors \
    --gemma-root ./gemma-3-12b-it-qat-q4_0-unquantized \
    --prompt "A continuous first-person indoor shot from a low eye-level camera inside a quiet dormitory room at night. The shot opens facing an open wooden door and a narrow exit, with white walls, pale ceramic floor tiles, and soft neutral indoor lighting. The camera glides forward out of the room, crossing the doorway threshold into a clean residential corridor, and the frame gently swings to the right, revealing a long straight hallway lined with closed light-wood doors on both sides. The hallway remains empty and still, with fluorescent ceiling panels, smooth white walls, and a calm, realistic atmosphere. As the camera continues steadily forward, six closed doors pass by in sequence, the doorframes sliding past the edges of the frame one after another while the tiled floor and ceiling lights create strong forward depth. After those doors, a white open side passage appears on the right, and the view smoothly pivots into that opening. The new corridor is narrower and quieter, with the same pale floor tiles and white walls, and the camera keeps moving forward in a straight line. At the far end, a bright white drinking water dispenser gradually comes into view beside the wall, becoming larger and clearer as the camera approaches. The shot slows down naturally and comes to a clean stop when the water dispenser is fully visible in front of the camera. Realistic handheld-stabilized motion, consistent geometry, no people, no sudden cuts, no object deformation, no extra doors appearing or disappearing." \
    --negative-prompt "third-person view, external camera, side view, overhead shot, top-down view, drone view, selfie view, mirror reflection, visible body, visible hands, visible feet, visible shadow, people, pedestrians, crowd, moving person, opened doors, opening doors, closing doors, extra doors, missing doors, wrong door count, disappearing doors, duplicated doors, shifted door positions, changing hallway layout, inconsistent corridor geometry, warped walls, bent floor lines, distorted perspective, fisheye lens, wide-angle distortion, broken depth, floating objects, duplicated objects, object popping, object flicker, scene cut, jump cut, sudden transition, teleportation, abrupt camera rotation, fast turning, violent shaking, unstable motion, heavy motion blur, blurry frame, low detail, bad lighting flicker, exposure flicker, color shift, unrealistic lighting, messy background, clutter, random objects, wrong turn, wrong corridor, wrong destination, missing side passage, incorrect right turn, missing drinking water dispenser, misplaced dispenser, distorted dispenser, unreadable structure, text close-up, gibberish text, changing stickers, changing door numbers, deformed architecture, surreal scene, fantasy elements, outdoor scene" \
    --output-path ./navigation_10s.mp4 \
    --height 704 \
    --width 1216 \
    --num-frames 241 \
    --frame-rate 24 \
    --num-inference-steps 50 \
    --enhance-prompt \
    --image ./image/1.jpg 0 1.0 \
    --image ./image/2.jpg 10 1.0 \
    --image ./image/3.jpg 29 1.0 \
    --image ./image/4.jpg 38 1.0 \
    --image ./image/5.jpg 48 1.0 \
    --image ./image/6.jpg 96 1.0 \
    --image ./image/7.jpg 173 1.0 \
    --image ./image/8.jpg 202 1.0 \
    --image ./image/9.jpg 211 1.0 \
    --image ./image/10.jpg 221 1.0 \
    --image ./image/11.jpg 240 1.0
```