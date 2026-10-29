"""Blender authoring recipe for the reference-inspired tricolour cyclist.
Run: blender -b --factory-startup --python tools/build_tricolour_cyclist.py
The existing rider supplies only the bicycle, skeleton and animation clips.
All visible character surfaces below are newly authored geometry.
"""
import bpy
import bmesh
from mathutils import Vector, Matrix
import math
import json
import struct
import hashlib
from pathlib import Path
from collections import defaultdict

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/models/imported-cyclist/cycliste-universel.glb'
OUTPUT=ROOT/'assets/models/tricolour-cyclist/cycliste-tricolore.glb'
source_bytes=SOURCE.read_bytes();b=source_bytes;length=struct.unpack_from('<I',b,12)[0]
g=json.loads(b[20:20+length]);offset=20+length
binary=bytearray(b[offset+8:offset+8+struct.unpack_from('<I',b,offset)[0]])
a=g['accessors'][g['skins'][0]['inverseBindMatrices']];v=g['bufferViews'][a['bufferView']]
raw=struct.unpack_from('<'+'f'*(a['count']*16),binary,v.get('byteOffset',0)+a.get('byteOffset',0))
JOINTS={g['nodes'][node]['name']:i for i,node in enumerate(g['skins'][0]['joints'])}
BIND={name:Matrix([[raw[i*16+c*4+r] for c in range(4)] for r in range(4)]).inverted().translation for name,i in JOINTS.items()}
V=lambda x:Vector(x)
PARTS=[]
PALETTE={'navy':(.018,.035,.095),'navy_light':(.028,.052,.14),'blue':(.035,.15,.48),
 'white':(.86,.88,.90),'red':(.72,.035,.045),'skin':(.72,.40,.23),
 'lips':(.40,.15,.12),'hair':(.24,.105,.036),'hair_light':(.32,.16,.063),
 'hair_dark':(.15,.055,.018),'black':(.005,.009,.016),'lens':(.012,.028,.055),'silver':(.34,.39,.45)}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)


def mesh(name,vertices,faces):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    for p in data.polygons:p.use_smooth=True
    return obj


def loft(name,centres,radii,segments=20):
    centres=list(map(V,centres));vertices=[];faces=[]
    for i,c in enumerate(centres):
        direction=(centres[min(i+1,len(centres)-1)]-centres[max(i-1,0)]).normalized()
        u=V((1,0,0))-direction*direction.x
        if u.length<.01:u=V((0,0,1))-direction*direction.z
        u.normalize();w=direction.cross(u).normalized()
        rw,rd=radii[i] if isinstance(radii[i],(tuple,list)) else (radii[i],radii[i])
        for j in range(segments):
            angle=j*math.tau/segments;vertices.append(c+u*(math.cos(angle)*rw)+w*(math.sin(angle)*rd))
    for i in range(len(centres)-1):
        for j in range(segments):
            q=i*segments+j;r=i*segments+(j+1)%segments
            faces.append((q,r,r+segments,q+segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(centres)-1)*segments+j for j in range(segments)))
    return mesh(name,vertices,faces)


def ellipsoid(name,center,scale,segments=24,rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings)
    obj=bpy.context.object;obj.name=name
    for vertex in obj.data.vertices:vertex.co=V(center)+Vector([vertex.co[i]*scale[i] for i in range(3)])
    for p in obj.data.polygons:p.use_smooth=True
    return obj


def union(name,objects,target):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    obj=objects[0];obj.name=name
    remesh=obj.modifiers.new('Continuous garment','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.006
    remesh.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=obj.modifiers.new('Tailored joins','SMOOTH');smooth.factor=.55;smooth.iterations=5;bpy.ops.object.modifier_apply(modifier=smooth.name)
    triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
    if triangles>target:
        decimate=obj.modifiers.new('Simulation detail budget','DECIMATE');decimate.ratio=target/triangles
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    for p in obj.data.polygons:p.use_smooth=True
    return obj


def add(obj,material='skin',weight=None):
    PARTS.append((obj,material,weight or (lambda p:{JOINTS['Hips']:1.0})))
    return obj


def rigid(name):return lambda p:{JOINTS[name]:1.0}
def smoothstep(t):t=max(0,min(1,t));return t*t*(3-2*t)
def project(p,a,b):return (p-a).dot(b-a)/(b-a).length_squared

def nearest_leg(p):
    def distance(side):
        a=BIND['UpperLeg_'+side];b=BIND['LowerLeg_'+side];t=max(0,min(1,project(p,a,b)))
        return (p-a.lerp(b,t)).length_squared
    return min(('L','R'),key=distance)


def shorts_weights(p):
    side=nearest_leg(p);a=BIND['UpperLeg_'+side];b=BIND['LowerLeg_'+side]
    t=project(p,a,b);blend=smoothstep((t-.03)/.30)
    return {JOINTS['Hips']:1-blend,JOINTS['UpperLeg_'+side]:blend}


def leg_weights(side):
    knee=BIND['LowerLeg_'+side];hip=BIND['UpperLeg_'+side];ankle=BIND['Foot_'+side]
    # Blend at the knee, retaining the original bind-space shape of each leg.
    def weights(p):
        thigh_t=max(0,min(1,project(p,hip,knee)))
        shin_t=max(0,min(1,project(p,knee,ankle)))
        thigh_distance=(p-hip.lerp(knee,thigh_t)).length_squared
        shin_distance=(p-knee.lerp(ankle,shin_t)).length_squared
        along=(thigh_t-1)*(knee-hip).length if thigh_distance<=shin_distance else shin_t*(ankle-knee).length
        blend=smoothstep((along+.045)/.09)
        return {JOINTS['UpperLeg_'+side]:1-blend,JOINTS['LowerLeg_'+side]:blend}
    return weights

# Fitted, continuous jersey with narrower shoulders and a distinct waist/hip line.
hip=BIND['Hips'];neck=BIND['Neck'];head=BIND['Head']
centres=[hip+V((0,.008,0)),hip+V((0,.07,.055)),hip+V((0,.135,.14)),hip+V((0,.22,.24)),V((0,1.322,.154)),neck+V((0,.018,0))]
radii=[(.158,.105),(.132,.098),(.143,.105),(.166,.108),(.171,.093),(.056,.045)]
TORSO_CENTRES=list(centres);TORSO_RADII=list(radii)
jersey_parts=[loft('Fitted jersey torso',centres,radii,28)]
ARMS={}
for side,sign in [('L',1),('R',-1)]:
    shoulder=BIND['UpperArm_'+side]+V((-sign*.027,0,0));elbow=BIND['LowerArm_'+side]+V((-sign*.023,0,0));hand=BIND['Hand_'+side]
    ARMS[side]=(shoulder,elbow,hand)
    jersey_parts.append(loft('Jersey sleeve '+side,[shoulder,shoulder.lerp(elbow,.23),shoulder.lerp(elbow,.51)],[(.057,.056),(.062,.061),(.058,.057)],20))
    jersey_parts.append(ellipsoid('Rounded deltoid '+side,shoulder+V((0,-.005,0)),(.064,.059,.064),20,12))
jersey=union('Continuous tricolour jersey',jersey_parts,6500)
axis=(neck-hip).normalized();axis_length=(neck-hip).length

def jersey_colour(p):
    for shoulder,elbow,hand in ARMS.values():
        t=project(p,shoulder,elbow)
        if t>.25 and (p-shoulder.lerp(elbow,t)).length<.10:
            if .34<t<.40:return 'blue'
            if .40<=t<.445:return 'white'
            if .445<=t<.52:return 'red'
    t=(p-hip).dot(axis)/axis_length
    if .48<t<.545:return 'red'
    if .545<=t<.61:return 'white'
    if .61<=t<.675:return 'blue'
    return 'navy_light' if t>.73 else 'navy'
add(jersey,jersey_colour)

# Arms are new continuous surfaces, not pieces recoloured from the supplied man.
for side,(shoulder,elbow,hand) in ARMS.items():
    arm=loft('Arm '+side,[shoulder.lerp(elbow,.35),shoulder.lerp(elbow,.65),elbow,elbow.lerp(hand,.28),elbow.lerp(hand,.7),hand], [.057,.055,.048,.053,.038,.027],20)
    add(arm)
    add(ellipsoid('Fingerless glove '+side,hand+V((0,-.005,.018)),(.041,.030,.051)), 'navy')
    for finger in range(4):
        x=hand.x+(finger-1.5)*.014
        add(loft('Gripping fingers '+side+str(finger),[(x,hand.y-.004,hand.z+.043),(x,hand.y-.035,hand.z+.048),(x,hand.y-.047,hand.z+.025)],[.007,.007,.005],8))

# Continuous shorts, with independent thigh weights and tricolour leg grippers.
short_parts=[ellipsoid('Athletic pelvis',hip+V((0,.008,-.01)),(.176,.118,.145))]
for side in ['L','R']:
    a=BIND['UpperLeg_'+side];k=BIND['LowerLeg_'+side]
    short_parts.append(loft('Shorts leg '+side,[a,a.lerp(k,.25),a.lerp(k,.50),a.lerp(k,.68)], [.105,.106,.092,.082],24))
shorts=union('Continuous cycling shorts',short_parts,5500)

def shorts_colour(p):
    side=nearest_leg(p);t=project(p,BIND['UpperLeg_'+side],BIND['LowerLeg_'+side])
    if .56<t<.605:return 'blue'
    if .605<=t<.64:return 'white'
    if .64<=t<.69:return 'red'
    return 'navy'
add(shorts,shorts_colour,shorts_weights)
for side in ['L','R']:
    a=BIND['UpperLeg_'+side];k=BIND['LowerLeg_'+side];f=BIND['Foot_'+side]
    leg=loft('Leg skin '+side,[a.lerp(k,.53),a.lerp(k,.80),k,k.lerp(f,.14),k.lerp(f,.35),k.lerp(f,.65),f],[.078,.072,.062,.055,.057,.039,.028],24)
    add(leg,'skin',leg_weights(side))
    sock=loft('White sock '+side,[k.lerp(f,.57),k.lerp(f,.68),k.lerp(f,.90),f],[.046,.042,.034,.033],24)
    add(sock,'white',rigid('LowerLeg_'+side))
    add(ellipsoid('Sock ankle '+side,f+V((0,-.015,.005)),(.034,.038,.040),20,12),'white',rigid('Foot_'+side))
    add(loft('Sock instep '+side,[f,f+V((0,-.04,.025)),f+V((0,-.065,.065))],[.031,.032,.027],20),'white',rigid('Foot_'+side))
    # A fitted road shoe descends from the ankle towards the pedal/toe, with a
    # slim sole, two fasteners and a BOA dial, all following the foot bone.
    heel=f+V((0,-.046,-.055));toe=f+V((0,-.10,.155))
    shoe=loft('White road shoe '+side,[heel,heel.lerp(toe,.25),heel.lerp(toe,.65),toe],[(.026,.024),(.043,.033),(.044,.031),(.031,.018)],22)
    add(shoe,'white',rigid('Foot_'+side))
    add(loft('Sole '+side,[heel+V((0,-.024,0)),toe+V((0,-.018,0))],[(.028,.006),(.033,.006)],16),'black',rigid('Foot_'+side))
    for t in [.40,.63]:
        c=heel.lerp(toe,t)+V((0,.031,0))
        add(loft('Shoe strap '+side,[c+V((-.038,0,0)),c+V((.038,0,0))],[.005,.005],8),'navy',rigid('Foot_'+side))
    add(ellipsoid('Shoe dial '+side,heel.lerp(toe,.36)+V((.039,.015,0)),(.007,.010,.010),12,8),'black',rigid('Foot_'+side))

# Face, chin and nose are separately modelled, with sports glasses and a helmet.
add(loft('Neck',[neck-V((0,.02,0)),head+V((0,-.015,-.005))],[.043,.042],20))
face_center=head+V((0,.038,.018))
add(ellipsoid('Face and jaw',head+V((0,.075,.020)),(.062,.090,.073),30,20),'skin',rigid('Head'))
nose=[head+V(p) for p in [(-.010,.080,.083),(.010,.080,.083),(-.009,.026,.089),(.009,.026,.089),(0,.043,.106)]]
add(mesh('Shaped nose',nose,[(0,1,4),(1,3,4),(3,2,4),(2,0,4),(0,2,3,1)]),'skin',rigid('Head'))
add(loft('Neutral lips',[head+V((-.015,.018,.092)),head+V((0,.016,.095)),head+V((.015,.018,.092))],[.0023,.0023,.0015],8),'lips',rigid('Head'))
for side in [-1,1]:
    add(ellipsoid('Ear',head+V((side*.062,.064,-.005)),(.011,.025,.016),16,10),'skin',rigid('Head'))
    lens=[head+V((side*x,y,z)) for x,y,z in [(0,.102,.103),(.067,.098,.065),(.074,.068,.040),(.018,.058,.100)]]
    verts=lens+[p-V((0,0,.0015)) for p in lens]
    add(mesh('Wraparound sports lens',verts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]),'lens',rigid('Head'))
    add(loft('Glasses arm',[head+V((side*.074,.092,.042)),head+V((side*.065,.084,-.020))],[.004,.004],8),'navy',rigid('Head'))
    jaw=head+V((side*.045,-.032,.024))
    add(loft('Helmet strap',[head+V((side*.071,.10,-.032)),jaw,head+V((side*.071,.10,.049))],[.004,.004,.004],8),'black',rigid('Head'))
add(loft('Glasses bridge',[head+V((-.013,.096,.103)),head+V((.013,.096,.103))],[.005,.005],8),'navy',rigid('Head'))

helmet_center=head+V((0,.125,0))
add(loft('Helmet black vent interiors',[helmet_center+V((0,-.008,0)),helmet_center+V((0,.01,0)),helmet_center+V((0,.035,0)),helmet_center+V((0,.052,0))],[(.084,.108),(.083,.107),(.066,.08),(.004,.006)],28),'black',rigid('Head'))
# Long white ribs leave actual open ventilation channels over the dark liner.
for lo,hi in [(-.99,-.80),(-.69,-.51),(-.37,-.17),(-.065,.065),(.17,.37),(.51,.69),(.80,.99)]:
    verts=[];faces=[];rows=30;columns=3
    for inner in [False,True]:
        for i in range(rows+1):
            t=-1.72+3.44*i/rows
            for j in range(columns+1):
                x=lo+(hi-lo)*j/columns;rad=math.sqrt(max(0,1-x*x))
                verts.append(helmet_center+V((x*(.089-(.003 if inner else 0)),rad*(.067-(.004 if inner else 0))*math.cos(t),rad*(.116-(.004 if inner else 0))*math.sin(t))))
    n=(rows+1)*(columns+1)
    for i in range(rows):
        for j in range(columns):
            q=i*(columns+1)+j;r=q+columns+1
            faces.extend([(q,q+1,r+1,r),(n+q,n+r,n+r+1,n+q+1)])
        q=i*(columns+1);r=q+columns+1;faces.append((q,r,n+r,n+q))
        q+=columns;r+=columns;faces.append((q,n+q,n+r,r))
    for j in range(columns):
        faces.append((j,n+j,n+j+1,j+1));q=rows*(columns+1)+j;faces.append((q,q+1,n+q+1,n+q))
    add(mesh('Vented white helmet rib',verts,faces),'white',rigid('Head'))

# Brown scalp and three interwoven tapered strands resting behind the jersey.
add(ellipsoid('Hair at nape',head+V((0,.075,-.040)),(.055,.045,.035)),'hair_dark',rigid('Head'))
controls=[head+V((0,.05,-.082)),head+V((0,-.025,-.15)),head+V((0,-.10,-.24)),head+V((0,-.16,-.36)),head+V((0,-.21,-.41))]
def braid_center(t):
    x=t*(len(controls)-1);i=min(len(controls)-2,int(x));return controls[i].lerp(controls[i+1],x-i)
for strand,colour in enumerate(['hair','hair_light','hair_dark']):
    centres=[];radii=[]
    for i in range(81):
        t=i/80;c=braid_center(t);d=(braid_center(min(1,t+.01))-braid_center(max(0,t-.01))).normalized()
        u=V((1,0,0));w=d.cross(u).normalized();angle=t*math.tau*6+strand*math.tau/3
        centres.append(c+(u*math.cos(angle)+w*math.sin(angle))*(.014*(1-t*.55)))
        radii.append(.0125*(1-t*.60))
    add(loft('Braided strand '+str(strand),centres,radii,8),colour,rigid('Head'))
end=braid_center(.96)
add(loft('Braid tie',[end-V((0,.006,0)),end+V((0,.006,0))],[.015,.015],12),'navy',rigid('Head'))

# Small front zipper and rear jersey pocket seams, placed outside the cloth.
zip_points=[]
for i in range(24):
    t=.04+.94*i/23;x=t*(len(TORSO_CENTRES)-1);j=min(len(TORSO_CENTRES)-2,int(x));fraction=x-j
    c=TORSO_CENTRES[j].lerp(TORSO_CENTRES[j+1],fraction)
    direction=(TORSO_CENTRES[j+1]-TORSO_CENTRES[j]).normalized()
    front=-direction.cross(V((1,0,0))).normalized()
    depth=TORSO_RADII[j][1]*(1-fraction)+TORSO_RADII[j+1][1]*fraction
    zip_points.append(c+front*(depth+.0015))
add(loft('Front zipper',zip_points,[.0018]*len(zip_points),8),'silver')

# Drop every original character mesh, keeping the donor bicycle and its rig.
remove=set()
def descendants(i):
    remove.add(i)
    for child in g['nodes'][i].get('children',[]):descendants(child)
descendants(next(i for i,n in enumerate(g['nodes']) if n.get('name')=='Cyclist'))
for i,node in enumerate(g['nodes']):
    if i in remove or node.get('name')=='Hy3dUpperBody':node.pop('mesh',None);node.pop('skin',None)
used=sorted({n['mesh'] for n in g['nodes'] if 'mesh' in n})
remap={old:new for new,old in enumerate(used)}
g['meshes']=[g['meshes'][old] for old in used]
for n in g['nodes']:
    if 'mesh' in n:n['mesh']=remap[n['mesh']]

material_ids={}
for name,colour in PALETTE.items():
    material_ids[name]=len(g['materials'])
    g['materials'].append({'name':'Tricolour_'+name,'pbrMetallicRoughness':{'baseColorFactor':[*colour,1],
        'metallicFactor':0,'roughnessFactor':.24 if name=='lens' else .72},'doubleSided':False})

def append_accessor(values,component_type,kind,components):
    while len(binary)%4:binary.append(0)
    start=len(binary);fmt='f' if component_type==5126 else 'H' if component_type==5123 else 'I'
    flat=[v for row in values for v in row] if components>1 else values
    binary.extend(struct.pack('<'+fmt*len(flat),*flat))
    view=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(binary)-start})
    a={'bufferView':view,'componentType':component_type,'count':len(values),'type':kind}
    if component_type==5126 and kind=='VEC3':a.update(min=[min(row[j] for row in values) for j in range(3)],max=[max(row[j] for row in values) for j in range(3)])
    index=len(g['accessors']);g['accessors'].append(a);return index

# Batch the whole new character by material. Every vertex keeps its own skin weights.
groups=defaultdict(lambda:{'p':[],'n':[],'j':[],'w':[]})
def split_polygon(polygon,scalar,boundary):
    halves=[[],[]]
    for k,current in enumerate(polygon):
        previous=polygon[k-1];cv=scalar(current[0])-boundary;pv=scalar(previous[0])-boundary
        if (cv<0)!=(pv<0):
            t=pv/(pv-cv);point=previous[0].lerp(current[0],t);normal=previous[1].lerp(current[1],t).normalized()
            for half in halves:half.append((point,normal))
        halves[0 if cv<0 else 1].append(current)
    return [half for half in halves if len(half)>=3]

for obj,material,weight in PARTS:
    data=obj.data;data.calc_loop_triangles()
    for triangle in data.loop_triangles:
        polygon=[(data.vertices[i].co.copy(),data.vertices[i].normal.normalized()) for i in triangle.vertices]
        center=sum((p for p,n in polygon),V((0,0,0)))/3
        pieces=[polygon];boundaries=[];scalar=None
        if material==jersey_colour:
            scalar=lambda p:(p-hip).dot(axis)/axis_length
            boundaries=[.48,.545,.61,.675,.73]
            for shoulder,elbow,hand in ARMS.values():
                t=project(center,shoulder,elbow)
                if t>.25 and (center-shoulder.lerp(elbow,t)).length<.10:
                    scalar=lambda p,a=shoulder,b=elbow:project(p,a,b)
                    boundaries=[.34,.40,.445,.52];break
        elif material==shorts_colour:
            side=nearest_leg(center);a=BIND['UpperLeg_'+side];b=BIND['LowerLeg_'+side]
            scalar=lambda p,a=a,b=b:project(p,a,b);boundaries=[.56,.605,.64,.69]
        # Split triangles on the actual colour boundaries instead of assigning
        # whole decimated faces across stripes (which produces jagged borders).
        for boundary in boundaries:
            pieces=[half for piece in pieces for half in split_polygon(piece,scalar,boundary)]
        for piece in pieces:
            center=sum((p for p,n in piece),V((0,0,0)))/len(piece)
            name=material(center) if callable(material) else material;group=groups[name]
            for j in range(1,len(piece)-1):
                for p,n in [piece[0],piece[j],piece[j+1]]:
                    weights=weight(p)
                    entries=sorted([(bone,w) for bone,w in weights.items() if w>0],key=lambda x:-x[1])[:4]
                    total=sum(w for _,w in entries);entries=[(bone,w/total) for bone,w in entries]
                    entries+= [(0,0)]*(4-len(entries))
                    group['p'].append(tuple(p));group['n'].append(tuple(n))
                    group['j'].append(tuple(bone for bone,w in entries));group['w'].append(tuple(w for bone,w in entries))

primitives=[]
for name,data in groups.items():
    attributes={'POSITION':append_accessor(data['p'],5126,'VEC3',3),'NORMAL':append_accessor(data['n'],5126,'VEC3',3),
        'JOINTS_0':append_accessor(data['j'],5123,'VEC4',4),'WEIGHTS_0':append_accessor(data['w'],5126,'VEC4',4)}
    primitives.append({'attributes':attributes,'material':material_ids[name],'mode':4})
mesh_index=len(g['meshes']);g['meshes'].append({'name':'TricolourFemaleCharacter','primitives':primitives})
node_index=len(g['nodes']);g['nodes'].append({'name':'TricolourFemaleCharacter','mesh':mesh_index,'skin':0})
g['nodes'][0].setdefault('children',[]).append(node_index)
g['buffers']=[{'byteLength':len(binary)}]
g.setdefault('asset',{})['generator']='Rois de la Pedale reference-inspired tricolour authoring recipe'
encoded=json.dumps(g,separators=(',',':')).encode()
encoded+=b' '*((-len(encoded))%4);binary.extend(b'\0'*((-len(binary))%4))
result=struct.pack('<4sII',b'glTF',2,12+8+len(encoded)+8+len(binary))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(binary),b'BIN\0')+binary
OUTPUT.parent.mkdir(exist_ok=True);OUTPUT.write_bytes(result)
triangles=sum(len(d['p'])//3 for d in groups.values())
(OUTPUT.parent/'metadata.json').write_text(json.dumps({'name':'Cycliste tricolore','source_bicycle_sha256':hashlib.sha256(source_bytes).hexdigest(),
 'sha256':hashlib.sha256(result).hexdigest(),'character_triangles':triangles,'character_materials':len(groups),
 'reference':'User supplied multi-view image, navy tricolour kit, white vented helmet, brown braid',
 'authoring':'tools/build_tricolour_cyclist.py; original character geometry removed; donor bicycle, rig and animation retained'},indent=2)+'\n')
print('TRICOLOUR_BUILT',OUTPUT,len(result),triangles,'character triangles',flush=True)
