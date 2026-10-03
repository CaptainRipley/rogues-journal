# Character credits

## Town humans
Original meshes, authored for Harth. No downloaded character pack and no Mixamo clips.

Built in Blender by `godot/tools/build_harth_people.py`. Each GLB is one skinned mesh: hexagonal limbs, a real skeleton (hips, spine, chest, neck, head, arms, legs), and hand-keyed clips. Joint rings share the two bones that meet there, so a knee or an elbow bends instead of shearing the limb. Textures are 64×64, nearest-filtered, and unshaded in town like the rest of Harth. The face is local +Z. Walkers aim that axis along their step; standing still they aim it at the player. Nix stays the billboard at `res://assets/nix.png`. Bramble stays the hound sprites.

| NPC | Mesh | Clips |
|---|---|---|
| Hob | hob.glb | idle, walk. Short, hood, beard, muddy tunic. |
| Drunk Ralf | ralf.glb | idle, walk. Lanky, dirty-blonde hair, open vest. |
| Sister Pell | pell.glb | idle, walk. Narrow habit, wimple, veil, wooden cross. |
| Marta | marta.glb | idle, walk, strike. Broad smith, soot tunic, leather apron, bare forearms. She stays at the anvil. The strike clip swings Hand.R, and the hammer prop is parented to that bone. |
| Guard Bren | bren.glb | idle, walk. Broad mail, bucket helm, pauldrons weighted to the chest. |
| Guard Cole | cole.glb | idle, walk. Taller, kettle hat, cloak, rusted shoulders. |

The earlier Nocturnal Watch static meshes had no skeleton. They are not used.
