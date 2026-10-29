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
    t=project(p,a,b);blend=smoothstep((t-.14)/.25)
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

# Reference proportions in bicycle metres. The animation skeleton is retained,
# but the visible upper body is authored in its own, lower racing posture.
# Head/arms are static in the supplied pedal clip, so these bind-space surfaces
# follow the same Hips/Head bones without editing the original animation.
def curved_loft(name, centres, radii, segments=20, steps=3):
    centres=list(map(V,centres));points=[];sizes=[]
    radii=[V((r,r)) if isinstance(r,(int,float)) else V(r) for r in radii]
    for i in range(len(centres)-1):
        for j in range(steps):
            t=j/steps
            def cat(values):
                a=values[max(0,i-1)];b=values[i];c=values[i+1];d=values[min(len(values)-1,i+2)]
                return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
            points.append(cat(centres));sizes.append(tuple(cat(radii)))
    points.append(centres[-1]);sizes.append(tuple(radii[-1]))
    return loft(name,points,sizes,segments)

hip=BIND['Hips']
# A low racing back angle, short neck and adult head replace the tiny head,
# long neck and upright cylindrical trunk of the first version.
neck=V((0,1.291,.343));head=V((0,1.328,.389))
centres=[V((0,.994,-.208)),V((0,1.069,-.126)),V((0,1.139,-.020)),
         V((0,1.204,.103)),V((0,1.255,.210)),V((0,1.274,.269)),neck]
radii=[(.149,.096),(.137,.106),(.130,.110),(.147,.118),(.164,.108),(.129,.077),(.048,.043)]
TORSO_CENTRES=list(centres);TORSO_RADII=list(radii)
jersey_parts=[curved_loft('Anatomical jersey torso',centres,radii,32)]
ARMS={}
for side,sign in [('L',1),('R',-1)]:
    shoulder=V((sign*.161,1.256,.222))
    elbow=V((sign*.203,1.058,.348))
    hand=BIND['Hand_'+side]+V((0,.003,.005))
    ARMS[side]=(shoulder,elbow,hand)
    jersey_parts.append(curved_loft('Fitted sleeve '+side,
      [shoulder+V((-sign*.037,.003,-.014)),shoulder,shoulder.lerp(elbow,.24),shoulder.lerp(elbow,.48)],
      [(.049,.049),(.051,.051),(.049,.048),(.043,.042)],24))
    jersey_parts.append(ellipsoid('Integrated shoulder '+side,shoulder+V((-sign*.009,-.003,-.009)),(.052,.051,.054),24,16))
jersey=union('Continuous tricolour jersey',jersey_parts,7200)
axis=(neck-hip).normalized();axis_length=(neck-hip).length

def sleeve_region(p):
    # Restrict cuff classification to the outside of the torso, avoiding the
    # old diagonal stripe artifacts where a sleeve plane crosses the chest.
    if abs(p.x)<.147:return None
    for shoulder,elbow,hand in ARMS.values():
        t=project(p,shoulder,elbow)
        if t>.28 and (p-shoulder.lerp(elbow,t)).length<.072:return shoulder,elbow
    return None

def jersey_colour(p):
    sleeve=sleeve_region(p)
    if sleeve:
        t=project(p,*sleeve)
        if .32<t<.365:return 'blue'
        if .365<=t<.415:return 'white'
        if .415<=t<.50:return 'red'
    t=(p-hip).dot(axis)/axis_length
    if .56<t<.605:return 'red'
    if .605<=t<.665:return 'white'
    if .665<=t<.71:return 'blue'
    return 'navy'
add(jersey,jersey_colour)

for side,(shoulder,elbow,hand) in ARMS.items():
    arm=curved_loft('Anatomical arm '+side,
      [shoulder.lerp(elbow,.36),shoulder.lerp(elbow,.66),elbow,
       elbow.lerp(hand,.24),elbow.lerp(hand,.56),elbow.lerp(hand,.86),hand],
      [(.041,.040),(.041,.039),(.035,.035),(.037,.035),(.032,.030),(.024,.024),(.022,.022)],24)
    add(arm)
    add(ellipsoid('Fingerless glove '+side,hand+V((0,-.009,.017)),(.034,.025,.043),24,14),'navy')
    for finger in range(4):
        x=hand.x+(finger-1.5)*.012
        add(curved_loft('Gripping fingers '+side+str(finger),
          [(x,hand.y-.009,hand.z+.035),(x,hand.y-.030,hand.z+.044),(x,hand.y-.044,hand.z+.024)],
          [.006,.006,.0045],10,3))
    sign=1 if side=='L' else -1
    add(curved_loft('Thumb '+side,[hand+V((-sign*.023,-.004,.018)),hand+V((-sign*.028,-.023,.037)),hand+V((-sign*.018,-.032,.039))],[.009,.008,.005],12,3))

# Pelvis/gluteal volume flows into both thighs before smooth hip/thigh weights.
# The two thighs are deliberately slimmer than the original tubular version.
short_parts=[ellipsoid('Pelvis',hip+V((0,-.016,-.012)),(.156,.101,.122),32,20)]
for side,sign in [('L',1),('R',-1)]:
    a=BIND['UpperLeg_'+side];k=BIND['LowerLeg_'+side]
    short_parts.append(curved_loft('Anatomical shorts leg '+side,
      [a,a.lerp(k,.15),a.lerp(k,.34),a.lerp(k,.52),a.lerp(k,.625)],
      [(.085,.088),(.088,.089),(.085,.084),(.076,.075),(.070,.068)],28))
shorts=union('Continuous cycling shorts',short_parts,6100)

def shorts_colour(p):
    side=nearest_leg(p);t=project(p,BIND['UpperLeg_'+side],BIND['LowerLeg_'+side])
    if .53<t<.557:return 'blue'
    if .557<=t<.592:return 'white'
    if .592<=t<.64:return 'red'
    return 'navy'
add(shorts,shorts_colour,shorts_weights)
for side in ['L','R']:
    a=BIND['UpperLeg_'+side];k=BIND['LowerLeg_'+side];f=BIND['Foot_'+side]
    leg=curved_loft('Anatomical leg '+side,
      [a.lerp(k,.54),a.lerp(k,.72),a.lerp(k,.89),k,k.lerp(f,.16),k.lerp(f,.34),k.lerp(f,.57),k.lerp(f,.82),f],
      [(.067,.065),(.063,.062),(.051,.051),(.047,.049),(.046,.044),(.048,.044),(.039,.035),(.027,.027),(.024,.025)],26)
    add(leg,'skin',leg_weights(side))
    sock=curved_loft('White sock '+side,[k.lerp(f,.61),k.lerp(f,.72),k.lerp(f,.91),f],[(.041,.039),(.036,.035),(.030,.031),(.028,.030)],24)
    add(sock,'white',rigid('LowerLeg_'+side))
    add(ellipsoid('Sock ankle '+side,f+V((0,-.015,.005)),(.029,.034,.034),20,12),'white',rigid('Foot_'+side))
    add(curved_loft('Sock instep '+side,[f,f+V((0,-.037,.025)),f+V((0,-.065,.065))],[.027,.029,.025],20),'white',rigid('Foot_'+side))
    heel=f+V((0,-.046,-.052));toe=f+V((0,-.10,.155))
    shoe=curved_loft('White road shoe '+side,[heel,heel.lerp(toe,.22),heel.lerp(toe,.58),heel.lerp(toe,.86),toe],[(.026,.023),(.039,.032),(.042,.030),(.034,.023),(.019,.014)],24)
    add(shoe,'white',rigid('Foot_'+side))
    add(curved_loft('Sole '+side,[heel+V((0,-.023,0)),heel.lerp(toe,.50)+V((0,-.027,0)),toe+V((0,-.018,0))],[(.027,.005),(.040,.006),(.022,.005)],20),'black',rigid('Foot_'+side))
    for t in [.38,.59]:
        c=heel.lerp(toe,t)+V((0,.030,0))
        add(curved_loft('Shoe strap '+side,[c+V((-.034,-.006,0)),c+V((0,.001,0)),c+V((.034,-.006,0))],[.004,.004,.004],10),'navy',rigid('Foot_'+side))
    add(ellipsoid('Shoe dial '+side,heel.lerp(toe,.35)+V((.037,.012,0)),(.006,.008,.008),12,8),'black',rigid('Foot_'+side))

# Adult head: crown/jaw/chin rings, cheeks, brow, lips and a smoothly rounded
# nose. Larger cranial volume, shorter neck, fitted eyewear and helmet.
head_weight=rigid('Head')
add(curved_loft('Short neck',[neck+V((0,-.026,-.018)),head+V((0,.008,-.014)),head+V((0,.036,-.009))],[.042,.039,.042],24))
face=curved_loft('Sculpted head',
 [head+V((0,-.003,.038)),head+V((0,.018,.027)),head+V((0,.050,.009)),head+V((0,.091,-.003)),head+V((0,.132,-.010)),head+V((0,.165,-.013)),head+V((0,.180,-.013))],
 [(.026,.030),(.044,.047),(.062,.069),(.069,.078),(.068,.077),(.050,.056),(.009,.010)],32)
# Fuse the nose into the face to avoid a detached pointed pyramid.
nose=ellipsoid('Nose bridge',head+V((0,.071,.077)),(.012,.027,.018),20,14)
tip=ellipsoid('Nose tip',head+V((0,.048,.089)),(.015,.010,.012),20,12)
face=union('Sculpted face',[face,nose,tip],3200)
add(face,'skin',head_weight)
add(curved_loft('Lips',[head+V((-.016,.024,.068)),head+V((0,.022,.072)),head+V((.016,.024,.068))],[.0018,.0028,.0018],10),'lips',head_weight)
for sign in [-1,1]:
    add(ellipsoid('Ear',head+V((sign*.067,.073,-.008)),(.010,.023,.014),20,12),'skin',head_weight)
    add(ellipsoid('Ear inner',head+V((sign*.075,.073,-.006)),(.003,.012,.007),16,10),'lips',head_weight)
    # Curved four-corner lens with raised intermediate points.
    lenses=[]
    for row in range(3):
        for col in range(9):
            t=col/8;x=sign*(.006+.065*t)
            z=.092-.046*t*t;y=.103-.016*t-(.029-row*.014)
            lenses.append(head+V((x,y,z)))
    faces=[]
    for row in range(2):
        for col in range(8):
            q=row*9+col;faces.append((q,q+1,q+10,q+9))
    lens=mesh('Curved sports lens',lenses,faces)
    solid=lens.modifiers.new('Lens thickness','SOLIDIFY');solid.thickness=.002
    bpy.context.view_layer.objects.active=lens;bpy.ops.object.modifier_apply(modifier=solid.name)
    add(lens,'lens',head_weight)
    rim=[head+V((sign*(.006+.065*t),.105-.016*t,.094-.046*t*t)) for t in [i/12 for i in range(13)]]
    add(loft('Eyewear upper frame',rim,[.0035]*len(rim),10),'navy',head_weight)
    add(curved_loft('Glasses temple',[head+V((sign*.072,.091,.047)),head+V((sign*.074,.085,-.014)),head+V((sign*.066,.070,-.029))],[.004,.004,.003],10),'navy',head_weight)
    jaw=head+V((sign*.042,-.012,.025))
    add(loft('Helmet strap',[head+V((sign*.067,.155,-.043)),jaw,head+V((sign*.067,.155,.039))],[.003,.003,.003],10),'black',head_weight)
add(curved_loft('Glasses bridge',[head+V((-.010,.100,.093)),head+V((0,.102,.095)),head+V((.010,.100,.093))],[.004,.004,.004],10),'navy',head_weight)

helmet_center=head+V((0,.148,-.014))
add(curved_loft('Dark helmet liner',[helmet_center+V((0,-.012,0)),helmet_center+V((0,.009,0)),helmet_center+V((0,.041,0)),helmet_center+V((0,.064,0))],[(.086,.108),(.087,.109),(.066,.082),(.007,.009)],32),'black',head_weight)
# Actual white shell ribs and channels; taller crown follows the reference.
shell_patches=[(lo,hi,-1.72,1.72) for lo,hi in [(-.995,-.82),(-.70,-.52),(-.38,-.19),(-.07,.07),(.19,.38),(.52,.70),(.82,.995)]]
# Forehead/rear bridges and crown leave bounded vents rather than open stripes.
shell_patches += [(lo,hi,start,end) for lo,hi in [(-.82,-.70),(-.52,-.38),(-.19,-.07),(.07,.19),(.38,.52),(.70,.82)] for start,end in [(-1.72,-1.16),(-.18,.18),(1.16,1.72)]]
for lo,hi,t_start,t_end in shell_patches:
    verts=[];faces=[];rows=max(3,round(20*(t_end-t_start)/3.44));columns=2
    for inner in [False,True]:
        for i in range(rows+1):
            t=t_start+(t_end-t_start)*i/rows
            for j in range(columns+1):
                x=lo+(hi-lo)*j/columns;rad=math.sqrt(max(0,1-x*x))
                verts.append(helmet_center+V((x*(.095-(.003 if inner else 0)),rad*(.080-(.004 if inner else 0))*math.cos(t),rad*(.121-(.004 if inner else 0))*math.sin(t))))
    n=(rows+1)*(columns+1)
    for i in range(rows):
        for j in range(columns):
            q=i*(columns+1)+j;r=q+columns+1
            faces.extend([(q,q+1,r+1,r),(n+q,n+r,n+r+1,n+q+1)])
        q=i*(columns+1);r=q+columns+1;faces.append((q,r,n+r,n+q))
        q+=columns;r+=columns;faces.append((q,n+q,n+r,r))
    for j in range(columns):
        faces.append((j,n+j,n+j+1,j+1));q=rows*(columns+1)+j;faces.append((q,q+1,n+q+1,n+q))
    add(mesh('Vented white helmet rib',verts,faces),'white',head_weight)

add(ellipsoid('Brown hair cap',head+V((0,.116,-.030)),(.066,.060,.062),28,16),'hair_dark',head_weight)
# The braid rests along the back, rather than extending into empty space.
controls=[head+V((0,.073,-.070)),V((0,1.399,.243)),V((0,1.370,.158)),V((0,1.329,.067)),V((0,1.280,-.010))]
def braid_center(t):
    x=t*(len(controls)-1);i=min(len(controls)-2,int(x));return controls[i].lerp(controls[i+1],x-i)
for strand,colour in enumerate(['hair','hair_light','hair_dark']):
    centres=[];radii=[]
    for i in range(65):
        t=i/64;c=braid_center(t);d=(braid_center(min(1,t+.01))-braid_center(max(0,t-.01))).normalized()
        u=V((1,0,0));w=d.cross(u).normalized();angle=t*math.tau*5+strand*math.tau/3
        centres.append(c+(u*math.cos(angle)+w*math.sin(angle))*(.012*(1-t*.60)))
        radii.append(.0105*(1-t*.65))
    add(loft('Braided strand '+str(strand),centres,radii,8),colour,head_weight)
end=braid_center(.96)
add(loft('Braid tie',[end-V((0,.004,0)),end+V((0,.004,0))],[.010,.010],12),'navy',head_weight)

zip_points=[]
for i in range(30):
    t=.04+.94*i/29;x=t*(len(TORSO_CENTRES)-1);j=min(len(TORSO_CENTRES)-2,int(x));fraction=x-j
    c=TORSO_CENTRES[j].lerp(TORSO_CENTRES[j+1],fraction)
    direction=(TORSO_CENTRES[j+1]-TORSO_CENTRES[j]).normalized()
    front=-direction.cross(V((1,0,0))).normalized()
    depth=TORSO_RADII[j][1]*(1-fraction)+TORSO_RADII[j+1][1]*fraction
    zip_points.append(c+front*(depth+.0015))
add(loft('Front zipper',zip_points,[.0012]*len(zip_points),8),'silver')

# Apply one bounded reduction offline, rather than spending extra GPU work on
# redundant rings. Material boundaries are cut afterwards and stay crisp.
raw_triangles=sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj,_,_ in PARTS)
ratio=min(1.0,29500/raw_triangles)
for obj,_,_ in PARTS:
    if len(obj.data.polygons)<80:continue
    modifier=obj.modifiers.new('Offline final mesh budget','DECIMATE');modifier.ratio=ratio
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=modifier.name)

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
            boundaries=[.56,.605,.665,.71]
            sleeve=sleeve_region(center)
            if sleeve:
                shoulder,elbow=sleeve
                scalar=lambda p,a=shoulder,b=elbow:project(p,a,b)
                boundaries=[.32,.365,.415,.50]
        elif material==shorts_colour:
            side=nearest_leg(center);a=BIND['UpperLeg_'+side];b=BIND['LowerLeg_'+side]
            scalar=lambda p,a=a,b=b:project(p,a,b);boundaries=[.53,.557,.592,.64]
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
 'revision':2,'proportions':{'back_angle_degrees':round(math.degrees(math.atan2(ARMS['L'][0].y-hip.y,ARMS['L'][0].z-hip.z)),1),'shoulder_width_m':.322,'head_height_m':.18,'upper_arm_radius_m':.041,'thigh_radius_m':.088},
 'authoring':'tools/build_tricolour_cyclist.py; original character geometry removed; donor bicycle, rig and animation retained'},indent=2)+'\n')
print('TRICOLOUR_BUILT',OUTPUT,len(result),triangles,'character triangles',flush=True)
