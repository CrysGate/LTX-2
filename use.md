


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
    --prompt "A continuous first-person indoor shot from a low eye-level camera inside a quiet dormitory room at night. The shot opens facing an open wooden door and a narrow exit, with white walls, pale ceramic floor tiles, and soft neutral indoor lighting. A dark appliance stands close on the right edge of the frame near the doorway. The view glides forward out of the room, crosses the threshold, and smoothly reveals a clean residential corridor. The frame gently swings to the right, opening onto a long straight hallway with smooth white walls, beige floor tiles, fluorescent ceiling panels, and a calm, empty atmosphere. As the hallway settles into view, six closed light-wood doors pass by one after another along the right side of the frame. The perspective remains stable and realistic, with consistent geometry, soft indoor light, and no people entering the scene. After the sixth closed door, a bright white side opening appears on the right side of the hallway, and the view smoothly pivots into that opening. The new passage is narrower and quieter, with the same pale tiled floor and white walls, and a window and radiator gradually come into view at the far end. As the shot continues forward, a white drinking water dispenser appears on the right side near the wall, becoming larger and clearer until the camera comes to a gentle stop beside it." \
    --negative-prompt "third-person view, external camera, overhead view, side view, visible person, visible body, visible hands, visible feet, visible shadow, mirror reflection, selfie angle, character entering frame, crowded hallway, people in corridor, open doors on the main hallway, wrong number of doors, fewer than six doors, more than six doors, missing right turn, wrong turn direction, extra corridor branch, wrong final destination, missing water dispenser, overshooting the water dispenser, stopping too early, stopping too late, abrupt camera shake, jitter, wobble, jerky motion, sudden acceleration, sudden deceleration, fast motion, running, rolling camera, tilted horizon, fisheye distortion, wide-angle warping, zoom in, zoom out, scene cut, jump cut, camera teleportation, inconsistent layout, broken geometry, warped walls, bent corridor, floating objects, duplicated doors, morphing objects, flickering lights, exposure change, color shift, blurry frames, low detail, low resolution, noisy image, compression artifacts, unrealistic lighting, unrealistic perspective, object deformation, stretched textures, unstable first-person viewpoint" \
    --output-path ./navigation_4.mp4 \
    --height 704 \
    --width 1216 \
    --num-inference-steps 50 \
    --enhance-prompt \
    --num-frames 561 \
    --frame-rate 24 \
    --image ./image/001_f0000.jpg 0 1.0 \
    --image ./image/002_f0062.jpg 62 1.0 \
    --image ./image/003_f0124.jpg 124 1.0 \
    --image ./image/004_f0187.jpg 187 1.0 \
    --image ./image/005_f0249.jpg 249 1.0 \
    --image ./image/006_f0311.jpg 311 1.0 \
    --image ./image/007_f0373.jpg 373 1.0 \
    --image ./image/008_f0436.jpg 436 1.0 \
    --image ./image/009_f0498.jpg 498 1.0 \
    --image ./image/010_f0560.jpg 560 1.0 \
```

问题：插帧设置的对应帧数要比较合理生成的视频才能比较成功

建议流程：先把任意视频归一化到 24fps，再按均匀间隔抽取关键帧，并自动输出 `--image` 参数。

仓库里新增了自动脚本：`./scripts/prepare_keyframe_inputs.sh`

```bash
# 1) 一键完成：转 24fps + 帧数对齐到 (8k+1) + 抽关键帧 + 生成参数片段
./scripts/prepare_keyframe_inputs.sh \
  --source ./4.mp4 \
  --fps 24 \
  --keyframes 10 \
  --strength 1.0 \
  --image-dir ./image \
  --video-out ./4_24fps_aligned.mp4
```

脚本输出内容包含：
- `--num-frames ...`
- `--frame-rate 24`
- 一组 `--image ./image_auto/xxx.jpg 帧号 1.0`

你可以把这段输出直接粘贴到：

```bash
python -m ltx_pipelines.keyframe_interpolation \
  ... \
  <把脚本输出的 --num-frames / --frame-rate / --image 全部粘贴到这里>
```

说明：
- LTX 的 `--num-frames` 建议满足 `(8 * k) + 1`。
- 脚本会自动把 24fps 视频截断到最近的合法帧数，避免末尾帧不对齐。
- 脚本默认会自动检测源视频码率，并使用其 95% 作为安全上限（默认不提高码率）。
- 也可手动指定 `--video-bitrate`，例如 `1500k` 或 `2M`。
- `--keyframes` 常用范围：8~14。场景转向/路径变化多时适当增大。