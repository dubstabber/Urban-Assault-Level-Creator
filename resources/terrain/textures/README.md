Urban Assault ground textures (SurfaceType 0–5) per environment set

Place extracted PNGs here using this structure:

- res://resources/terrain/textures/
  - common/
    - ground_0.png .. ground_5.png           # optional shared fallback
  - set1/
    - ground_0.png .. ground_5.png           # set 1 textures
  - set2/
    - ground_0.png .. ground_5.png
  - set3/
    - ground_0.png .. ground_5.png
  - set4/
    - ground_0.png .. ground_5.png
  - set5/
    - ground_0.png .. ground_5.png
  - set6/
    - ground_0.png .. ground_5.png

Notes
- The editor loads set-specific textures first (set{N}/ground_{i}.png), then falls back to common/ground_{i}.png, and finally to a procedural color if neither exist.
- Each i is a UA SurfaceType index 0..5, as referenced by set.sdf mapping typ_id -> SurfaceType.
- Textures should be seamless/tileable. Recommended size: 256–1024, power-of-two. Godot will import and mipmap automatically.

Extraction guidance
- The open-source UA code (.usor) contains loaders for legacy ILBM/IFF formats but does NOT include proprietary game art assets. You must legally obtain textures from your own Urban Assault installation.
- Ground textures are embedded per set inside .usor/openua/DATA/SET{N}/OBJECTS/SET.BAS as EMRS resources under ilbm.class, typically named BODEN1.ILBM .. BODEN5.ILBM (German: “Boden” = ground). The image payloads are ILBM or VBMP forms.
- Important: Many VBMPs have no embedded CMAP palette. UA falls back to PALETTE/Standard.pal per set. The extractor mirrors this behavior and applies that palette automatically when needed.

Suggested workflow
1) Run the extractor to pull ground textures directly from SET.BAS and write PNGs:
   python3 scripts/ua_extract_ground_textures.py --in .usor/openua/DATA/SET1 --set 1 --auto-objects --out resources/terrain/textures/set1
   Repeat for sets 2..6.
2) The script decodes VBMP/ILBM and maps:
   - SurfaceType 0: WATER/WASSER if present; otherwise falls back to BODEN1
   - SurfaceType 1..5: BODEN1..BODEN5 (missing entries are filled by the previous one)
3) Run the editor and switch sets; textures hot‑reload on EventSystem.level_set_changed.

Tools (optional)
- Python + Pillow is required to write PNGs; the script includes ILBM/VBMP decoders so no external converter is needed.
- External ILBM tools are still useful for inspection.

See also
- res://scripts/generate_ground_textures.gd can generate placeholder tileable textures in common/ if you don’t have the originals yet.



Auto-extraction note
- Preferred: scripts/ua_extract_ground_textures.py --auto-objects (extracts BODEN*.ILBM from OBJECTS/SET.BAS) and applies PALETTE/Standard.pal when VBMP has no CMAP.
- Legacy/for reference only: --auto-ilb pointed at HI/{ALPHA,BETA,GAMMA}/FX{1,2}.ILB extracts SFX textures, not terrain, and should not be used for ground.
