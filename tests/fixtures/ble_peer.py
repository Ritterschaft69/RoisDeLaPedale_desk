"""Software-only TCP fixture; never distributed in game/bridge exports."""
import argparse,json,socket,time,struct,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'bluetooth'))
from protocol import indoor_bike
p=argparse.ArgumentParser();p.add_argument('--port',type=int);p.add_argument('--token');a=p.parse_args()
def packet(value):return (json.dumps(value,ensure_ascii=False)+'\n').encode()
# Try to inject a fake measurement without the capability; it must be rejected.
s=socket.create_connection(('127.0.0.1',a.port));s.sendall(packet({'type':'hello','version':1,'token':'wrong','clock_ms':0})+packet({'type':'state','state':'connected','name':'UNAUTHENTICATED'}));time.sleep(.05);s.close()
s=socket.create_connection(('127.0.0.1',a.port))
def send(value):
    b=packet(value)
    # Split in the middle of UTF-8 and JSON, not just at message boundaries.
    index=b.find(b'\xc2')+1 if b'\xc2' in b else 13
    s.sendall(b[:index]);time.sleep(.005);s.sendall(b[index:])
send({'type':'hello','version':1,'token':a.token,'clock_ms':int(time.monotonic()*1000)})
send({'type':'state','state':'ready'})
for raw in s.makefile('rb'):
    message=json.loads(raw)
    if message['op']=='scan':
        send({'type':'scan','scanning':True})
        send({'type':'device','id':'test-suito','name':'Elite Suito-T · test logiciel','ftms':True})
        send({'type':'scan','scanning':False})
    elif message['op']=='connect':
        send({'type':'state','state':'connecting'})
        send({'type':'state','state':'connected','name':'Elite Suito-T · test logiciel','profile':'FTMS','control_available':True})
        send({'type':'measurement','at_ms':int(time.monotonic()*1000),**indoor_bike(struct.pack('<HHHh',0x44,2800,160,210))})
    elif message['op'] in ('sync','heartbeat'):
        if 'clock_ms' in message:send({'type':'clock','remote_ms':int(time.monotonic()*1000),'echo_ms':message['clock_ms']})
    elif message['op']=='disconnect':send({'type':'state','state':'disconnected','message':'Déconnecté'})
    elif message['op']=='shutdown':break
s.close()
