# AI-to-sprite pipeline

Use this guide when generating, editing, or preparing Gorcs artwork. This is development tooling, not a runtime dependency for players.

## Start here

1. Pick an accepted sprite as the reference. State the requested change, camera angle, native output size, and what must remain recognizable.
2. Launch **Gorcs Pixel Art** from the laptop's application menu, or run `~/.local/bin/gorcs-pixelart`. Open <http://127.0.0.1:8188>.
3. In **Workflows**, open **Gorcs - Rune upgrade Klein 9B** for an original-reference edit. **Gorcs - Rune level 2 (9B Selected)** reproduces the successful architecture pass using an earlier generated reference, not the original level-one sprite.
4. Edit the instruction and reference image; use batch size one. Keep the distilled model's **4 steps, CFG 1, Euler, Flux2Scheduler** settings.
5. Generate one candidate, inspect it at native size beside the original, then change the specific failing feature. Deliver a useful still sprite before adding optional layers or animation previews.
6. Keep candidates outside `assets/`. User approval and game integration are separate steps.

If the sidebar is empty, refresh it. ComfyUI's default Z-Image workflow is unrelated and can report missing models; do not download unrelated models just to satisfy that template.

## Installed laptop setup

The verified machine has an RTX 4060 Laptop GPU with 8 GB VRAM and 32 GB RAM. These paths describe this laptop; they are not a repository installer or a guarantee that another machine is configured.

| Item | Location |
| --- | --- |
| ComfyUI and isolated Python environment | `~/.local/opt/ComfyUI/`, `.venv/` |
| Launcher | `~/.local/bin/gorcs-pixelart` |
| Manual-start user service | `comfyui-pixelart.service` |
| Shared model paths | `~/.local/share/gorcs-pixelart/model-paths.yaml` |
| Models | `~/.local/share/gorcs-pixelart/models/` |
| Workflow backups | `~/.local/share/gorcs-pixelart/workflows/` |
| Workflows shown in the UI | `~/.local/opt/ComfyUI/user/default/workflows/` |
| Generated images | `~/Pictures/Gorcs-PixelArt/` |

The current reference editor uses:

- `diffusion_models/flux-2-klein-9b-fp8.safetensors`: [FLUX.2 Klein 9B FP8](https://huggingface.co/black-forest-labs/FLUX.2-klein-9b-fp8), the **distilled** editor. Its gated download requires the account holder to accept the non-commercial license. Do not assume unrestricted commercial use or redistribute the weights.
- `text_encoders/qwen_3_8b_fp8mixed.safetensors`: the matching encoder from [Comfy-Org's Klein 9B files](https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b).
- `vae/flux2-vae.safetensors`: the full FLUX.2 VAE, available in [Comfy-Org's Klein files](https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-4b).

Native node conventions come from the [official Klein workflows](https://docs.comfy.org/tutorials/flux/flux-2-klein). Match the diffusion model, encoder, VAE, and sampler settings; an SDXL VAE or a 4B encoder is not a substitute for this setup. The installed undistilled 4B base workflow uses different guidance and step counts; do not apply its settings to distilled 9B.

The service listens only on localhost, uses offline mode, reserves 2 GB VRAM, and enables conservative classic low-VRAM loading with dynamic VRAM, asynchronous offloading, and CUDA malloc disabled. Treat the installed service file as the command source rather than duplicating its full argument list here.

```sh
# Inspect the GPU before a rendering session.
nvidia-smi

# Start without opening a browser, or inspect the running service.
systemctl --user start comfyui-pixelart.service
systemctl --user status comfyui-pixelart.service --no-pager
journalctl --user -u comfyui-pixelart.service -n 30 --no-pager

# Stop and release resources when finished.
systemctl --user stop comfyui-pixelart.service
```

No service autostart at login is required. Keep model binaries, Python environments, caches, and credentials outside the game repository. Do not paste Hugging Face tokens into chat or commit them. A gated model needs the user's authenticated download or local login; never bypass the gate.

## Agent/API route

Agents can use the same local server without operating the node canvas for every candidate.

1. Check `GET /system_stats` and `GET /queue`. Do not restart the service, clear the queue, or interrupt somebody else's render.
2. Upload a reference with multipart `POST /upload/image`, field `image`. Use the returned filename, including its subfolder if present, in `LoadImage`.
3. Load an **API-format prompt graph**. The saved runnable example is `~/Pictures/Gorcs-PixelArt/rune-level-2-klein/klein9-next-prompt.json`; the full successful requests are in `klein9-generation.json`. A canvas workflow JSON is a different format: export API format from ComfyUI or use the frontend's `app.graphToPrompt()` output after the editor is ready.
4. Inspect the graph before modifying it. Find the relevant `CLIPTextEncode`, `LoadImage`, `RandomNoise`, and `SaveImage` nodes rather than assuming node IDs from another graph. Change the positive edit instruction, input filename, explicit seed, and unique output prefixes. Keep the negative/unconditional reference branch intact.
5. Submit `POST /prompt` with `{"prompt": <API graph>, "client_id": <unique ID>}`. Include `extra_data.extra_pnginfo.workflow` when retaining the canvas graph in output PNGs. Inspect both HTTP errors and `node_errors`; successful submission means queued, not rendered.
6. Connect `/ws?clientId=<ID>` before submission. Wait for matching `execution_success` or `execution_error` events. Fetch `GET /history/<prompt_id>` for the resulting status and exact output filenames. Do not treat queued work or an old PNG as a successful new render.
7. Save the actual request, canvas graph, reference dependencies, seeds, output paths, and processing choices. Keep canvas widget values and named values synchronized if constructing variants programmatically.

A minimal submission example using the installed environment and saved API graph:

```sh
~/.local/opt/ComfyUI/.venv/bin/python - <<'PY'
import json
import uuid
from pathlib import Path
from urllib.request import Request, urlopen

path = Path.home() / "Pictures/Gorcs-PixelArt/rune-level-2-klein/klein9-next-prompt.json"
prompt = json.loads(path.read_text())
request = Request(
    "http://127.0.0.1:8188/prompt",
    data=json.dumps({"prompt": prompt, "client_id": str(uuid.uuid4())}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urlopen(request) as response:
    print(json.load(response))
PY
```

This example submits the saved initial edit; it does not wait for completion or perform cleanup. Use the event/history steps above for an actual delivery. A saved reference image must still exist in ComfyUI's input directory.

Free model caches without stopping the UI after the queue is empty:

```sh
curl --fail --silent --show-error -X POST http://127.0.0.1:8188/free \
  -H 'Content-Type: application/json' \
  --data '{"unload_models":true,"free_memory":true}'
```

## Reference preparation and iterative editing

- Preserve the source PNG. For this editor, composite transparency onto a flat white canvas, preserving the source's margins, then enlarge with **nearest-exact** filtering. The Rune trial used a 256×256 reference enlarged to 1024×1024 and exported back to 256×256.
- Use a meaningful reference size and canvas. Do not generate a detailed illustration and assume arbitrary downscaling will make a readable tiny sprite. Native size is an asset decision, not a universal 256px rule.
- Describe an edit, not just a genre: which shapes change, which colors/materials remain, camera and lighting, and where new objects go. Judge silhouette, perspective, pixel scale, and shading before effects.
- Separate changes that compete. A long instruction requesting an architectural evolution and new rocks often preserved the old tower too literally. The successful approach first established the rocks, then requested **only** the wider buttressed base and larger crystal using that generated candidate as the next reference.
- Keep references for every pass. Feeding a previous output into the next pass is a dependency; its seed alone cannot reconstruct the later result.
- Use another focused pass only when the failing feature is clear. Show the candidate promptly; avoid spending a long session on near-identical variants or optional polish without showing the user the result.

The successful Rune architecture instruction was:

> Change only the central tower. Make its stone pillar twice as thick, with a chunky stone buttress attached on each side and a wider square stepped foundation. Replace the small crystal on top with a large tall sharply faceted violet amethyst crystal in a reinforced golden holder. Retain the blue engraved runes and draw the new stonework in the same crisp pixel-art technique, pale gray colors, dark outlines and isometric angle. Leave all three floating stone boulders in their current positions and preserve their carvings. Keep the white background.

This is a useful example, not a universal sprite prompt. Inspect what the model actually changed; a prompt is not proof that every requested detail appeared.

## Export and cleanup

The saved workflows generate images; they do **not** automatically perform the following postprocessing. The Rune exports were prepared with Pillow in the assistant session. Pillow is available in the installed ComfyUI environment; no reusable one-command export tool has been installed.

1. Keep the raw model output and its PNG metadata. Downscale to the chosen native size with nearest-neighbor filtering; inspect that version, not only an enlarged gallery preview.
2. Remove the background without erasing pale stone or highlights. In the white-background Rune trial, flood-fill only edge-connected pixels whose minimum RGB channel was at least 235 and whose channel spread was at most 24; set them to transparent. These thresholds are specific to that image. Inspect halos, enclosed gaps, and pale edges manually rather than applying them blindly to every asset.
3. Preserve sharp alpha for this art style. The Rune exports use only 0/255 alpha; no smoothing, antialiasing, or dithering was added.
4. For strict style continuity, match opaque pixels to an accepted reference palette with nearest-color mapping and dithering disabled. The Rune reference has 58 opaque RGB colors. Keep an unrestricted-color version as well; palette matching is not appropriate when new material/color accents are intentionally requested.
5. Check nonempty alpha bounds and margins. An enlarged base or effect must not be clipped. Compare with the original at equal native scale and on both light and dark backgrounds.
6. Save transparent PNGs, dimensions, alpha bounds, palette/alpha policy, SHA-256, parent images, model/version identifiers, prompts, seeds, and the actual API/canvas graphs. Distinguish raw outputs from cleaned exports.

Palette reduction cannot repair bad geometry, blurry linework, or an inconsistent design. The first SDXL/Pixel Art XL img2img attempt softened the tower and copied crude boulder guides into blobs; it was rejected. Do not describe that workflow as a proven replacement for PixelLab's reference-aware sprite tools. Klein editing performed substantially better in this trial, but user approval remains the quality gate.

### Optional layered effects

Only do this when useful or requested; do not delay delivering a good still sprite for it.

The selected Rune sprite was separated into its tower body and three boulder PNGs using connected foreground components, keeping nearby small sparks with the rocks. `selected/layers.json` records crop origins and dimensions. Reassembling those layers at their recorded positions was checked to reproduce the complete composite pixel-for-pixel.

The orbit GIF is a **composited preview**, not generated animation frames and not an implemented game effect. It translates the generated rocks around an ellipse and draws rear rocks before the tower and foreground rocks after it. Different assets may touch, overlap, or have disconnected body parts; do not assume component extraction always finds one body and three rocks.

## Rune trial: reproducible artifacts and verification

All trial artifacts are currently local, not committed game assets:

```text
~/Pictures/Gorcs-PixelArt/rune-level-2-klein/
  klein9-generation.json             Six successful requests, graphs, seeds, references
  klein9-exports.json                Cleaned candidates and selected asset checksums
  klein9-comparison.png              Accepted level 1 and the two final alternatives
  selected/
    rune_obelisk_level_2.png         Selected 256×256 transparent composite (pass 05)
    tower_body.png                  Separate tower layer
    boulder_01.png                  Separate generated rock layers
    boulder_02.png
    boulder_03.png
    layers.json                     Placement and encoded animation timing
    orbit_preview.gif               Optional layered-motion preview
```

Observed verification: six actual 9B GPU renders completed, taking approximately 53–100 seconds each on this laptop; the selected sprite and alternative were visually compared with the original; native dimensions, hard alpha, reference-palette membership, and layer reconstruction were checked; the orbit GIF was inspected in a running browser. The accepted source SHA-256 remained `c4c3a6b6a2caa470ecd81962c63289753bcdbdad40ced44ddb784a705ec177b8`.

This proves this local editing/export trial, not every model, animation type, hardware configuration, or final art acceptance. No level-two artwork or orbit effect was installed into the game.

## GPU failure handling

An earlier session hit NVIDIA **Xid 79: GPU has fallen off the bus**, and the driver reported that OS reboot was required. Godot and ComfyUI were both active; the root cause was not established. The later conservative configuration completed the six 9B renders, but it is **not a proven fix** for that driver fault.

- Avoid concurrent GPU-heavy game/editor launches while rendering on this laptop. Release caches or stop ComfyUI when returning to game work.
- On an execution failure, preserve the error and partial outputs. Inspect the service log and GPU availability; do not keep submitting requests to a lost device.
- Never reset the GPU, restart the desktop, reboot, or kill unrelated applications without user approval. Preserve unsaved editor work. If the driver explicitly requires reboot, finish saving reachable artifacts and report that prerequisite.

## Approval and game integration

Treat a generated candidate, accepted artwork, and implemented gameplay as three different states. Show a useful comparison and get approval before replacing established art.

For an approved import, follow the [existing development asset guidance](development.md#pixel-art-asset-workflow) and [archive provenance conventions](../archive_assets/README.md). Preserve source PNGs and catalog derivations; ship ordinary losslessly imported Godot resources with nearest filtering and no mipmaps. Update atlas bounds when the visible geometry changes, not reward/save IDs merely to change art.

Verify approved art on the actual collection and board surfaces using the applicable checks in [development](development.md). A bigger drawn base or flying-rock preview does not implement a larger gameplay footprint, damage upgrade, range change, or host-authoritative mechanic.
