# Modèle courant — 0.6.6

Le jeu utilise désormais le GLB fourni par l’utilisateur dans [imported-cyclist](imported-cyclist/README.md). Les surfaces décrites ci-dessous sont conservées pour l’historique et les outils de création ; elles ne sont plus chargées ni exportées par le jeu.

# Continuous cyclist garments

`jersey.res` and `bib.res` are compressed Godot ArrayMesh resources generated from this project's procedural cyclist. The jersey joins torso, deltoids and sleeves into one closed surface. The bib joins pelvis and both shorts legs, with four-slot skin weights for a three-bone rig (pelvis, left thigh, right thigh).

No external artwork or downloaded human model is embedded. These generated assets follow the repository licence. Runtime and ordinary CI builds need Godot only; Blender is an optional authoring tool, not a game dependency.

Regenerate with Godot 4.6.3 and Blender 4.3.2 from the repository root:

```sh
godot --headless --path . --script tools/export_rider_parts.gd
blender --background --python tools/fuse_rider.py
godot --headless --path . --script tools/import_rider_garments.gd
godot --headless --path . --script tests/test_garment_joints.gd
```

Intermediates stay in ignored build/. The authoring flag in tools/legacy_rider.gd enables the retained procedural recipe; versions before 0.6.6 used the baked surfaces. The bind pose separates the thighs slightly, so union does not bridge them below the groin. Runtime rotates each thigh bone to the corresponding IK direction and blends weights at the hips. Godot stores weights with 16-bit precision.

The voxel size is 6 mm, followed by eight smoothing passes and decimation to 22% of the remeshed topology. The shipped jersey has 7,775 vertices / 15,546 triangles; the bib has 6,584 vertices / 13,164 triangles. Both are checked for one connected component and exactly two incident faces per edge. Skin deformation is checked across 32 pedal phases.
