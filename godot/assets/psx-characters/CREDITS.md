# Character credits

## Town NPCs
PSX Fantasy pack — Nocturnal Watch — toboas
https://toboas.itch.io/psx-fantasy-pack-nocturnal-watch

CC0. The author says no credits are required. Credited here anyway, same place as the other packs.

Shipped meshes (converted from the pack's FBX to GLB, feet on the ground). Root rotations are baked into the vertices and the imported node basis is identity. The painted face is mesh −Z (hood is +Z), measured by rasterizing the head. The rig turns the mesh 180° so the face lies on the rig's +Z, and the look-at (`atan2` of the offset to the player) aims that axis at the camera. The pack ships a bind-pose T with no skeleton and no clips, so the rest pose has the arms lowered to a stand. Marta keeps this mesh. She stands at the anvil and a separate hammer swings on a loop; she does not turn to face the player. The other named NPCs still do.

| NPC | Mesh | Texture |
|---|---|---|
| Hob | Peasant | PeasantTexture.png |
| Drunk Ralf | Peasant | PeasantBlondeTexture.png |
| Marta | Bartender | Bartender.png |
| Sister Pell | Nun | Nun_Texture.png |
| Guard Bren, Guard Cole | Inquisitor | IniquisitorTexture.png (body) and InquisitorHelmetTexture.png (head) |

Nun, Peasant, and Inquisitor FBX files in the pack point at texture paths that are not in the zip (a maid texture, a missing `NonOverlapping.png`, and no texture binding). The GLBs use the matching PNGs that shipped beside those models. Nix is still the billboard at `res://assets/nix.png`.
