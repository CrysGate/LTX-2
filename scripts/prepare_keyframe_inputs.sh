#!/usr/bin/env bash
set -euo pipefail

# Convert a source video to fixed FPS, align frame count to (8k+1),
# extract evenly spaced keyframes, and print --image args for LTX keyframe interpolation.

usage() {
  cat <<'EOF'
Usage:
  scripts/prepare_keyframe_inputs.sh \
    --source ./input.mp4 \
    [--fps 24] \
    [--keyframes 10] \
    [--strength 1.0] \
    [--video-bitrate 1500k] \
    [--image-dir ./image_auto] \
    [--video-out ./input_24fps_aligned.mp4]

Options:
  --source      Source video path (required)
  --fps         Target FPS (default: 24)
  --keyframes   Number of extracted keyframes (default: 10)
  --strength    Conditioning strength for each --image (default: 1.0)
  --video-bitrate Video bitrate cap for output (supports forms like 1500000, 1500k, 2M)
                  Default: auto-detect source video bitrate, then use 95% as safety cap
  --image-dir   Output folder for extracted keyframe images (default: ./image_auto)
  --video-out   Output path for processed 24fps aligned video
  --help        Show this help

Output:
  1) Processed video with frame count aligned to (8k+1)
  2) Keyframe images
  3) A command snippet you can paste into:
       python -m ltx_pipelines.keyframe_interpolation ...
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

parse_bitrate_to_bps() {
  local raw="$1"

  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "$raw"
    return 0
  fi

  if [[ "$raw" =~ ^([0-9]+)[kK]$ ]]; then
    echo "$(( ${BASH_REMATCH[1]} * 1000 ))"
    return 0
  fi

  if [[ "$raw" =~ ^([0-9]+)[mM]$ ]]; then
    echo "$(( ${BASH_REMATCH[1]} * 1000000 ))"
    return 0
  fi

  return 1
}

detect_source_video_bitrate_bps() {
  local stream_br format_br

  stream_br="$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$source_video" || true)"
  if [[ "$stream_br" =~ ^[0-9]+$ ]] && (( stream_br > 0 )); then
    echo "$stream_br"
    return 0
  fi

  format_br="$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$source_video" || true)"
  if [[ "$format_br" =~ ^[0-9]+$ ]] && (( format_br > 0 )); then
    echo "$format_br"
    return 0
  fi

  return 1
}

if ! command_exists ffmpeg; then
  echo "Error: ffmpeg not found in PATH" >&2
  exit 1
fi

if ! command_exists ffprobe; then
  echo "Error: ffprobe not found in PATH" >&2
  exit 1
fi

source_video=""
fps="24"
keyframes="10"
strength="1.0"
video_bitrate=""
image_dir="./image_auto"
video_out=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      source_video="${2:-}"
      shift 2
      ;;
    --fps)
      fps="${2:-}"
      shift 2
      ;;
    --keyframes)
      keyframes="${2:-}"
      shift 2
      ;;
    --strength)
      strength="${2:-}"
      shift 2
      ;;
    --video-bitrate)
      video_bitrate="${2:-}"
      shift 2
      ;;
    --image-dir)
      image_dir="${2:-}"
      shift 2
      ;;
    --video-out)
      video_out="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$source_video" ]]; then
  echo "Error: --source is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$source_video" ]]; then
  echo "Error: source video not found: $source_video" >&2
  exit 1
fi

if ! [[ "$fps" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: --fps must be a positive number" >&2
  exit 1
fi

if ! [[ "$keyframes" =~ ^[0-9]+$ ]]; then
  echo "Error: --keyframes must be an integer >= 2" >&2
  exit 1
fi

if (( keyframes < 2 )); then
  echo "Error: --keyframes must be >= 2" >&2
  exit 1
fi

target_video_bitrate_bps=""
if [[ -n "$video_bitrate" ]]; then
  if ! target_video_bitrate_bps="$(parse_bitrate_to_bps "$video_bitrate")"; then
    echo "Error: invalid --video-bitrate value: $video_bitrate" >&2
    echo "Accepted formats: 1500000, 1500k, 2M" >&2
    exit 1
  fi
else
  source_video_bitrate_bps=""
  if source_video_bitrate_bps="$(detect_source_video_bitrate_bps)"; then
    target_video_bitrate_bps="$(( source_video_bitrate_bps * 95 / 100 ))"
    if (( target_video_bitrate_bps < 100000 )); then
      target_video_bitrate_bps="$source_video_bitrate_bps"
    fi
  else
    echo "Warning: unable to detect source bitrate, using CRF fallback (may not strictly cap bitrate)." >&2
  fi
fi

base_name="$(basename "$source_video")"
base_stem="${base_name%.*}"

if [[ -z "$video_out" ]]; then
  video_out="./${base_stem}_${fps}fps_aligned.mp4"
fi

mkdir -p "$image_dir"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

normalized_tmp="$work_dir/${base_stem}_${fps}fps_tmp.mp4"

encode_video_args=(-c:v libx264 -preset medium -pix_fmt yuv420p -an)
if [[ -n "$target_video_bitrate_bps" ]]; then
  encode_video_args+=(-b:v "$target_video_bitrate_bps" -maxrate "$target_video_bitrate_bps" -bufsize "$(( target_video_bitrate_bps * 2 ))")
  echo "[0/4] Video bitrate cap: ${target_video_bitrate_bps} bps"
else
  encode_video_args+=(-crf 23)
  echo "[0/4] Video bitrate cap unavailable, using CRF fallback"
fi

echo "[1/4] Converting source video to ${fps}fps..."
ffmpeg -hide_banner -loglevel error -y \
  -i "$source_video" \
  -vf "fps=${fps}" \
  "${encode_video_args[@]}" \
  "$normalized_tmp"

total_frames="$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$normalized_tmp" || true)"

if [[ -z "$total_frames" || "$total_frames" == "N/A" ]]; then
  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$normalized_tmp")"
  total_frames="$(awk -v d="$duration" -v f="$fps" 'BEGIN { printf "%d", (d*f)+0.5 }')"
fi

if [[ -z "$total_frames" || "$total_frames" -lt 1 ]]; then
  echo "Error: failed to determine frame count" >&2
  exit 1
fi

aligned_frames=$(( ((total_frames - 1) / 8) * 8 + 1 ))

if (( aligned_frames < 9 )); then
  echo "Error: video too short after fps conversion (need at least 9 aligned frames, got ${aligned_frames})" >&2
  exit 1
fi

echo "[2/4] Aligning frame count to (8k+1): ${total_frames} -> ${aligned_frames}"
ffmpeg -hide_banner -loglevel error -y \
  -i "$normalized_tmp" \
  -frames:v "$aligned_frames" \
  "${encode_video_args[@]}" \
  "$video_out"

if (( keyframes > aligned_frames )); then
  keyframes="$aligned_frames"
fi

indices_file="$work_dir/indices.txt"
: > "$indices_file"
max_index=$((aligned_frames - 1))
last=-1
denom=$((keyframes - 1))

for ((i = 0; i < keyframes; i++)); do
  # Round to nearest integer: (i*max)/(n-1)
  idx=$(( (i * max_index + denom / 2) / denom ))
  if (( idx <= last )); then
    idx=$((last + 1))
  fi
  if (( idx > max_index )); then
    idx=$max_index
  fi
  printf "%d\n" "$idx" >> "$indices_file"
  last=$idx
done

# Validate generated indices are strictly increasing and cover [0, max_index].
first_idx=""
last_idx=""
prev_idx=""
while IFS= read -r idx; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
    echo "Error: generated non-numeric index: $idx" >&2
    exit 1
  fi

  if [[ -z "$first_idx" ]]; then
    first_idx="$idx"
  fi

  if [[ -n "$prev_idx" ]] && (( idx <= prev_idx )); then
    echo "Error: generated indices are not strictly increasing (${prev_idx} -> ${idx})." >&2
    echo "Hint: ensure this script is up to date and run with bash (not sh)." >&2
    exit 1
  fi

  prev_idx="$idx"
  last_idx="$idx"
done < "$indices_file"

if [[ "$first_idx" != "0" || "$last_idx" != "$max_index" ]]; then
  echo "Error: generated index range is invalid (first=${first_idx}, last=${last_idx}, expected 0..${max_index})." >&2
  echo "Hint: ensure this script is up to date and run with bash (not sh)." >&2
  exit 1
fi

echo "[3/4] Extracting ${keyframes} keyframes to ${image_dir}..."

args_file="$work_dir/image_args.txt"
: > "$args_file"

count=1
while IFS= read -r idx; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
    echo "Error: invalid frame index generated: $idx" >&2
    exit 1
  fi

  idx_dec=$((10#$idx))
  file_name="$(printf "%03d_f%04d.jpg" "$count" "$idx_dec")"
  out_img="${image_dir%/}/$file_name"

  ffmpeg -hide_banner -loglevel error -y \
    -i "$video_out" \
    -vf "select='eq(n,${idx_dec})'" \
    -vframes 1 \
    "$out_img"

  echo "--image ${out_img} ${idx_dec} ${strength} \\" >> "$args_file"
  count=$((count + 1))
done < "$indices_file"

echo "[4/4] Done"
echo
echo "Processed video: ${video_out}"
echo "Aligned num-frames: ${aligned_frames}"
echo "Frame-rate: ${fps}"
echo
echo "Paste this snippet into your keyframe_interpolation command:"
echo "--num-frames ${aligned_frames} \\" 
echo "--frame-rate ${fps} \\" 
cat "$args_file"
