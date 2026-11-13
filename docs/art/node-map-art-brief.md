# Node map art brief (for GPT)

The act map is a horizontally scrolling chart of octagonal nodes joined by dashed paths.
The code already draws everything as placeholders (`ui/map/node_map_view.gd`,
`ui/map/map_node_button.gd`), and each file below replaces a placeholder as soon as it
exists at its path. Draw art only. Do not change code, scenes or data.

## Style

- **Reference:** the user's hand-drawn map. It has a warm cream watercolour parchment,
  soft washes, loose ink linework, and small vignettes at the edges (trees, hills). The
  middle is left clear for the nodes.
- **Translated to our world:** a nuclear-wasteland western. Edge vignettes are dry scrub,
  rock buttes, leaning telegraph poles, half-buried pipes and a broken windmill, in faded
  rust, sage and dusty blue washes.
- **The characters stay the anchor:** the new enemies
  (`battle_scene/assets/images/enemies/*/attack/*_attack_0.png`) set the ink weight and the
  colour temperature. The map is paler and quieter than the characters, because it sits
  behind them.
- **Keep it simple:** flat washes and a single soft shadow tone. No rendering, no texture
  noise, no text.
- **No player figure anywhere:** the current node is marked by code (an orange ring).

## Files

| File | Size | What it shows |
|---|---|---|
| `run_system/assets/images/map/route_parchment.png` | 3730×1000 RGB | The whole act's background, shown from y=80 under the top bar. Edge vignettes along the top and bottom 140 px and at both ends. The band y 100–860 stays plain parchment with faint wash variation, because nodes and paths sit there. Draw no paths or nodes. |
| `run_system/assets/images/map/node_octagon_available.png` | 96×96 RGBA | Octagon base for a node you can choose now: dark ink-brown fill (#3a2f27 family), a thick cream rim, a hint of a hand-inked edge. The icon is drawn on top by code, so leave the centre flat. |
| `run_system/assets/images/map/node_octagon_visited.png` | 96×96 RGBA | Same octagon, darker fill (#211a15 family), thin dull rim. |
| `run_system/assets/images/map/node_octagon_unreachable.png` | 96×96 RGBA | Same octagon in a light warm grey wash, thin rim (the code also fades it to 45%). |
| `run_system/assets/images/map/node_octagon_boss.png` | 144×144 RGBA | A larger octagon with a heavier rim and a small skull or rust spikes on the rim. |
| `run_system/assets/images/map/nodes/{relic,enemy,elite,rest,merchant,treasure,unknown,boss}.png` | 64×64 RGBA | Redraw the eight room icons as single cream (#efe2c4) silhouettes with one darker cream accent. Readable at 40 px. **enemy:** a revolver or crossed knife. **elite:** a horned skull. **rest:** a campfire. **merchant:** a sack with a coin. **treasure:** a strongbox. **unknown:** a question mark. **relic:** a crystal shard. **boss:** a crowned skull. |
| `run_system/assets/images/map/start_flag.png` | 64×64 RGBA | A small orange cloth flag on a thin pole, ink outline. The pole's foot sits at the bottom centre. |
| `run_system/assets/images/map/legend_card.png` | 360×420 RGBA | A torn parchment card with an ink border for the legend. The code writes the entries on it, so leave the inside plain. |

## Checks before handing over

- Every file is at exactly the size listed, with a transparent background where the format is RGBA.
- Icons stay readable on the available octagon at 40 px.
- The parchment's middle band has no detail that could be mistaken for a node or a path.
