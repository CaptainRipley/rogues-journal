# Character credits

## Town NPCs
PSX Fantasy pack — Nocturnal Watch — toboas
https://toboas.itch.io/psx-fantasy-pack-nocturnal-watch

CC0. The author says no credits are required. Credited here anyway, same place as the other packs.

Shipped meshes (converted from the pack's FBX to GLB, feet on the ground). Root rotations are baked into the vertices and the imported node basis is identity. The painted face is mesh −Z (hood is +Z), measured by rasterizing the head. The rig turns the mesh 180° so the face lies on the rig's +Z, and the look-at (`atan2` of the offset to the player) aims that axis at the camera.

Every GLB in this folder is one static mesh. There is no skin, no skeleton, and no animation clip to retarget, including the bartender. The stand pose already has the arms lowered. The scene paints arm and leg weights from that pose and swings them in place: a walk cycle while an NPC is moving, a small sway and a breath while they stand. The inquisitor's pauldrons stay on the torso; only the hanging forearms swing. Marta does not walk and does not turn to face the player. Her hammer loop is unchanged, and her right arm cocks with that swing. Nix stays the billboard.

| NPC | Mesh | Texture |
|---|---|---|
| Hob | Peasant | PeasantTexture.png |
| Drunk Ralf | Peasant | PeasantBlondeTexture.png |
| Marta | Bartender | Bartender.png |
| Sister Pell | Nun | Nun_Texture.png |
| Guard Bren, Guard Cole | Inquisitor | IniquisitorTexture.png (body) and InquisitorHelmetTexture.png (head) |

Nun, Peasant, and Inquisitor FBX files in the pack point at texture paths that are not in the zip (a maid texture, a missing `NonOverlapping.png`, and no texture binding). The GLBs use the matching PNGs that shipped beside those models. Nix is still the billboard at `res://assets/nix.png`.
