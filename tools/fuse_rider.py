"""Offline garment union (Blender Python). No Blender dependency at runtime.
Run after Godot tools/export_rider_parts.gd:
 blender --background --python tools/fuse_rider.py
Then Godot tools/import_rider_garments.gd saves the production mesh resources.
"""
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
source = json.loads((ROOT/'build/rider_parts.json').read_text())
result = {}
for name, parts in source.items():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    vertices, faces = [], []
    for part in parts:
        offset = len(vertices)
        vertices.extend(part['vertices'])
        indices = part['indices']
        # Godot uses clockwise front faces; Blender uses counterclockwise.
        faces.extend((offset+indices[i],offset+indices[i+2],offset+indices[i+1]) for i in range(0,len(indices),3))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.remesh_voxel_size = .006
    obj.data.use_remesh_preserve_volume = True
    bpy.ops.object.voxel_remesh()
    smooth = obj.modifiers.new('Continuous garment joins', 'SMOOTH')
    smooth.factor = .7
    smooth.iterations = 8
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    decimate = obj.modifiers.new('Runtime topology', 'DECIMATE')
    decimate.ratio = .22
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    triangulate = obj.modifiers.new('Triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.update()
    result[name] = {
        'vertices': [[round(c,7) for c in v.co] for v in obj.data.vertices],
        'normals': [[round(c,7) for c in v.normal] for v in obj.data.vertices],
        'indices': [index for p in obj.data.polygons for index in (p.vertices[0],p.vertices[2],p.vertices[1])],
    }
    print(name, len(obj.data.vertices), 'vertices', len(obj.data.polygons), 'triangles')
(ROOT/'build/rider_garments.json').write_text(json.dumps(result,separators=(',',':')))
