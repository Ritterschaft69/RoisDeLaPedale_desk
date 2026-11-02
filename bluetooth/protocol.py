"""Bluetooth SIG FTMS Indoor Bike and Cycling Power binary formats.
No Bluetooth dependencies; malformed/truncated packets never refresh a measure.
"""
import math,struct,time


def uuid(short):return f'0000{short:04x}-0000-1000-8000-00805f9b34fb'
FTMS=uuid(0x1826);CPS=uuid(0x1818)
BIKE=uuid(0x2ad2);POWER=uuid(0x2a63);FEATURE=uuid(0x2acc);CONTROL=uuid(0x2ad9)


class Packet:
    def __init__(self,data):self.data=bytes(data);self.offset=0
    def take(self,size):
        if self.offset+size>len(self.data):raise ValueError('truncated Bluetooth measurement')
        result=self.data[self.offset:self.offset+size];self.offset+=size;return result
    def u16(self):return struct.unpack('<H',self.take(2))[0]
    def i16(self):return struct.unpack('<h',self.take(2))[0]


def indoor_bike(data):
    p=Packet(data);flags=p.u16();out={}
    if flags&0xe000:raise ValueError('unsupported Indoor Bike flags')
    if not flags&1:out['trainer_speed_kmh']=p.u16()/100
    if flags&2:p.take(2)
    if flags&4:out['cadence']=p.u16()/2
    if flags&8:p.take(2)
    if flags&16:p.take(3)
    if flags&32:p.take(2)
    if flags&64:out['watts']=max(0,p.i16())
    if flags&128:p.take(2)
    if flags&256:p.take(5)
    if flags&512:p.take(1)
    if flags&1024:p.take(1)
    if flags&2048:p.take(2)
    if flags&4096:p.take(2)
    if out.get('watts',0)>2500 or out.get('cadence',0)>250:raise ValueError('measurement outside cycling limits')
    return out


class CyclingPower:
    def __init__(self,clock=time.monotonic):self.previous=None;self.last_turn=None;self.clock=clock
    def decode(self,data):
        p=Packet(data);flags=p.u16();out={'watts':max(0,p.i16())}
        if flags&0xe000:raise ValueError('unsupported Cycling Power flags')
        if flags&1:p.take(1)
        if flags&4:p.take(2)
        if flags&16:p.take(6)
        crank=(p.u16(),p.u16()) if flags&32 else None
        for bit,size in [(6,4),(7,4),(8,3),(9,2),(10,2),(11,2)]:
            if flags&(1<<bit):p.take(size)
        if out['watts']>2500:raise ValueError('power outside cycling limits')
        # Commit counters only after the complete flagged packet is validated.
        if crank is not None:
            now=self.clock()
            if self.previous is not None:
                revolutions=(crank[0]-self.previous[0])&0xffff
                ticks=(crank[1]-self.previous[1])&0xffff
                if revolutions and ticks:
                    cadence=60*1024*revolutions/ticks
                    if cadence<=250:out['cadence']=cadence;self.last_turn=now
                elif revolutions==0 and self.last_turn is not None and now-self.last_turn>2:
                    out['cadence']=0.
            else:self.last_turn=now
            self.previous=crank
        return out


def simulation(grade):
    if isinstance(grade,bool) or not isinstance(grade,(int,float)) or not math.isfinite(grade):raise ValueError('invalid slope')
    # SIG units: wind 0.001 m/s; grade .01%; rolling .0001; drag .01 kg/m.
    return struct.pack('<BhhBB',0x11,0,round(max(-10,min(10,grade))*100),40,51)
