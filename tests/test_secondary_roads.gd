extends SceneTree
const Overlay = preload("res://scripts/terrain_overlay.gd")
const Geo = preload("res://scripts/geoworld.gd")
var passed := 0
var failed := 0
class StraightRoute extends RefCounted:
 var structure := ""
 func structure_at(_station: float) -> String:return structure
 func direction(_station: float) -> Vector3:return Vector3.FORWARD
class JunctionWorld extends Node3D:
 var route:=StraightRoute.new()
 func nearest(p: Vector2, _local_only: bool = true) -> Dictionary:
  return {"s":-p.y,"distance":absf(p.x),"cross":p.x}
func check(ok: bool, message: String) -> void:
 if ok:passed+=1;print("PASS ",message)
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var overlay := Overlay.new()
 # A terrain ridge crossing the middle of a road: endpoint-only height sampling
 # would cut through its peak, and ordinary corner samples can float over hollows.
 for span in [[-10.,0.,0.,4.],[0.,10.,4.,0.]]:
  var a=Vector3(span[0],span[2],-10);var b=Vector3(span[1],span[3],-10)
  var c=Vector3(span[1],span[3],10);var d=Vector3(span[0],span[2],10)
  overlay.add_triangle(a,b,c);overlay.add_triangle(a,c,d)
 overlay.hull=PackedVector2Array([Vector2(-10,-10),Vector2(10,-10),Vector2(10,10),Vector2(-10,10)])
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 overlay.paint(surface,PackedVector2Array([Vector2(-8,-2),Vector2(8,-2),Vector2(8,2),Vector2(-8,2)]),.025,Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,0)
 surface.generate_normals();var mesh:=surface.commit();var arrays=mesh.surface_get_arrays(0)
 var maximum_error:=0.;var area:=0.;var upward:=true;var peak:=0.
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 for i in range(0,vertices.size(),3):
  var p=(vertices[i]+vertices[i+1]+vertices[i+2])/3
  maximum_error=maxf(maximum_error,absf(p.y-overlay.height(Vector2(p.x,p.z))-.025))
  area+=absf(Vector2(vertices[i+1].x-vertices[i].x,vertices[i+1].z-vertices[i].z).cross(Vector2(vertices[i+2].x-vertices[i].x,vertices[i+2].z-vertices[i].z)))*.5
 for p in vertices:peak=maxf(peak,p.y)
 for n in arrays[Mesh.ARRAY_NORMAL]:upward=upward and n.y>0
 check(maximum_error<.001 and peak>4,"road triangles follow a terrain ridge through their interiors")
 check(absf(area-64)<.001,"clipped road retains its footprint without holes or duplicate area")
 check(upward and arrays[Mesh.ARRAY_TEX_UV].size()==vertices.size(),"road normals face upward and asphalt receives consistent UVs")
 var paved=Geo.road_style({"highway":"secondary","width":"6.2 m"})
 var track=Geo.road_style({"highway":"track","surface":"gravel"})
 check(absf(paved.width-6.2)<.001 and paved.marked,"explicit OSM width and suitable road markings are respected")
 check(track.dirt and not track.marked,"unpaved tracks do not become marked asphalt roads")
 overlay.clear()
 check(overlay.near_cells.is_empty() and overlay.far_cells.is_empty(),"terrain index is cleared between scenery chunks")
 var fixture:=Geo.new("")
 fixture.roads=[{"tags":{"highway":"secondary"},"points":[[-4,0,-100],[4,0,-100]]}]
 fixture.road_segments=PackedInt64Array([0]);fixture.road_cells={Vector2i(0,-1):[0]}
 var junction_world:=JunctionWorld.new();root.add_child(junction_world)
 fixture.prepare_junctions(junction_world,Vector3(0,0,-100))
 check(fixture.junction_at(100,-1) and fixture.junction_at(100,1) and not fixture.junction_at(120,1),"crossing road opens both shoulders only within the junction")
 junction_world.route.structure="bridge"
 fixture.prepare_junctions(junction_world,Vector3(0,0,-100))
 check(fixture.junctions.is_empty(),"a grade-separated crossing does not open a false junction")
 junction_world.route.structure=""
 fixture.roads[0].points=[[0,0,-104],[0,0,-96]]
 fixture.road_shapes.clear();fixture.road_shape_order.clear()
 fixture.prepare_junctions(junction_world,Vector3(0,0,-100))
 check(fixture.junctions.is_empty(),"the ridden road itself does not create false junction openings")
 junction_world.free()
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false)
 for quality in [1,0]:
  app.world.quality=quality
  for item in [["saint_die",6200],["home_sweet_home",1200],["oderen_grand_ballon",32000],["sortie_matin",32000]]:
   app.select_circuit(item[0]);app.world.update_at(item[1],true)
   var valid:=true;var count:=0;var batches:=0
   for triangle in app.world.road_overlay.far_triangles:
    var p=(triangle[0]+triangle[1]+triangle[2])/3
    if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),app.world.road_overlay.hull):valid=false
   for node in app.world.generated.get_children():
    if not str(node.name).begins_with("Secondary"):continue
    batches+=1
    valid=valid and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if str(node.name)=="SecondaryAsphalt":valid=valid and node.material_override==app.world.road_material
    var data=node.mesh.surface_get_arrays(0)
    var points:PackedVector3Array=data[Mesh.ARRAY_VERTEX]
    for i in range(0,points.size(),3):
     var p=(points[i]+points[i+1]+points[i+2])/3
     var height=app.world.road_overlay.height(Vector2(p.x,p.z))
     var gap=p.y-height
     if not is_finite(height) or gap<.012 or gap>.038:valid=false
     count+=1
    for normal in data[Mesh.ARRAY_NORMAL]:
     if normal.y<=0:valid=false
   check(valid and count>0 and batches<=4,"secondary roads match rendered ground, use shared materials and bounded batches: "+item[0]+" quality="+str(quality))
 check(app.world.geographic.road_shapes.size()<=64,"cached road shapes stay bounded")
 app.free();await process_frame
 print("RESULT_SECONDARY_ROADS passed=",passed," failed=",failed)
 quit(0 if failed==0 else 1)
