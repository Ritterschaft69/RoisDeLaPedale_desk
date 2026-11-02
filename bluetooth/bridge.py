"""Native BLE central, isolated from the game's rendering thread.
Authenticated loopback JSON-lines. No Internet, telemetry or simulated sensors.
"""
import argparse,asyncio,contextlib,json,math,os,sys,time
from protocol import BIKE,POWER,FEATURE,CONTROL,FTMS,CPS,CyclingPower,indoor_bike,simulation


def bluetooth_error(error):
    detail=str(error).lower()
    if isinstance(error,TimeoutError):return 'Connexion trop longue. Réveillez le Suito-T et fermez les autres applications vélo.'
    if any(word in detail for word in ('denied','unauthorized','permission','access is')):return 'Accès Bluetooth refusé. Vérifiez les autorisations du système.'
    if any(word in detail for word in ('adapter','org.bluez','no such file','bluetooth is turned off')):return 'Bluetooth indisponible. Activez le Bluetooth du PC et vérifiez son pilote.'
    return 'Connexion Bluetooth impossible : '+str(error)[:180]


class Bridge:
    def __init__(self,emit,scanner,client_factory,clock=time.monotonic):
        self.emit=emit;self.scanner=scanner;self.client_factory=client_factory;self.clock=clock
        self.devices={};self.client=None;self.generation=0;self.tasks={}
        self.control_available=False;self.owned=False;self.running=False
        self.last_heartbeat=0.;self.last_power=0.;self.last_grade=None;self.last_grade_at=0.
        self.waiting=None;self.lock=asyncio.Lock();self.context={};self.control_task=None;self.control_pending=False;self.game_clock_delta=None;self.decoder=CyclingPower(clock);self.ftms_power_at=-1000.

    def state(self,state,**fields):self.emit({'type':'state','state':state,**fields})

    async def cancel_operations(self):
        for task in self.tasks.values():
            if task is not asyncio.current_task():task.cancel()
        for task in self.tasks.values():
            if task is not asyncio.current_task():
                with contextlib.suppress(asyncio.CancelledError,Exception):await task
        self.tasks.clear()

    def schedule(self,key,coroutine):
        task=asyncio.create_task(coroutine);self.tasks[key]=task
        def done(t):
            if not t.cancelled():
                error=t.exception()
                if error:self.emit({'type':'error','message':bluetooth_error(error)})
        task.add_done_callback(done)

    async def scan(self):
        self.devices.clear();self.emit({'type':'scan','scanning':True})
        try:
            found=await self.scanner.discover(timeout=10.,return_adv=True)
            for device,adv in found.values():
                services={s.lower() for s in (adv.service_uuids or [])}
                name=(adv.local_name or device.name or 'Périphérique Bluetooth')[:70]
                if not services.intersection({FTMS,CPS}) and 'suito' not in name.lower():continue
                self.devices[device.address]=device
                self.emit({'type':'device','id':device.address,'name':name,'ftms':FTMS in services,'rssi':adv.rssi})
        finally:self.emit({'type':'scan','scanning':False})

    def notification(self,kind,data,generation):
        if generation!=self.generation or self.client is None:return
        try:
            values=indoor_bike(data) if kind==BIKE else self.decoder.decode(data)
        except (ValueError,struct_error):return
        now=self.clock()
        if kind==BIKE and 'watts' in values:self.ftms_power_at=now
        if kind==POWER and now-self.ftms_power_at<2:values.pop('watts',None)
        if 'watts' in values:self.last_power=now
        if values:self.emit({'type':'measurement','at_ms':int(now*1000),**values})

    def indication(self,_sender,data):
        data=bytes(data)
        if len(data)==3 and data[0]==0x80 and self.waiting is not None:
            opcode,future=self.waiting
            if data[1]==opcode and not future.done():future.set_result(data[2])

    async def command(self,payload):
        if self.client is None:raise RuntimeError('Home trainer déconnecté')
        async with self.lock:
            future=asyncio.get_running_loop().create_future();self.waiting=(payload[0],future)
            try:
                deadline=asyncio.get_running_loop().time()+2.
                await asyncio.wait_for(self.client.write_gatt_char(CONTROL,payload,response=True),2.)
                result=await asyncio.wait_for(future,max(.001,deadline-asyncio.get_running_loop().time()))
                if result!=1:raise RuntimeError(f'Commande FTMS refusée (code {result})')
            finally:self.waiting=None

    async def connect(self,identity):
        return await asyncio.wait_for(self.connect_device(identity),25.)

    async def connect_device(self,identity):
        if identity not in self.devices:raise ValueError('Relancez la recherche avant de connecter ce périphérique')
        await self.disconnect(announce=False)
        self.generation+=1;generation=self.generation
        self.state('connecting',name=self.devices[identity].name or 'Home trainer')
        loop=asyncio.get_running_loop()
        def lost(client):
            if generation==self.generation and self.client is client:
                self.client=None;self.owned=False;self.running=False;self.control_available=False
                self.state('disconnected',message='Connexion Bluetooth perdue. Les mesures passent à zéro.')
        client=self.client_factory(self.devices[identity],disconnected_callback=lost,timeout=20.)
        try:
            await client.connect();self.client=client
            chars={c.uuid.lower() for service in client.services for c in service.characteristics}
            if BIKE not in chars and POWER not in chars:raise RuntimeError('Aucun profil FTMS ou puissance compatible')
            self.decoder=CyclingPower(self.clock);self.last_power=-1000.;self.ftms_power_at=-1000.
            subscribed=[]
            for characteristic in [BIKE,POWER]:
                if characteristic in chars:
                    try:
                        await client.start_notify(characteristic,lambda _sender,data,k=characteristic:self.notification(k,data,generation))
                        subscribed.append(characteristic)
                    except Exception:pass
            if not subscribed:raise RuntimeError('Les notifications de puissance ne sont pas disponibles')
            self.control_available=False
            if CONTROL in chars and FEATURE in chars:
                try:
                    features=await client.read_gatt_char(FEATURE)
                    self.control_available=len(features)>=8 and bool(int.from_bytes(features[4:8],'little')&(1<<13))
                    if self.control_available:await client.start_notify(CONTROL,lambda sender,data:self.indication(sender,data) if generation==self.generation else None)
                except Exception:self.control_available=False
            self.state('connected',name=getattr(client,'name',None) or self.devices[identity].name or 'Home trainer',id=identity,
                       profile='FTMS' if BIKE in subscribed else 'Cycling Power',control_available=self.control_available)
        except BaseException:
            if self.client is client:self.client=None
            with contextlib.suppress(Exception):await asyncio.wait_for(client.disconnect(),5.)
            self.state('disconnected',message='Connexion impossible. Vérifiez Bluetooth et fermez les autres applications vélo.')
            raise

    async def stop(self):
        self.running=False;self.last_grade=None
        if self.client is not None and self.owned:
            # One bounded attempt per command, also on EOF or game crash.
            for payload in [simulation(0),bytes([0x08,0x02])]:
                with contextlib.suppress(Exception):await self.command(payload)
        self.running=False;self.last_grade=None

    async def disconnect(self,announce=True):
        self.context={};self.control_pending=False
        if self.control_task is not None and self.control_task is not asyncio.current_task():
            self.control_task.cancel()
            with contextlib.suppress(asyncio.CancelledError,Exception):await self.control_task
            self.control_task=None
        if self.client is not None:
            await self.stop()
            if self.owned:
                with contextlib.suppress(Exception):await self.command(bytes([0x01]))
            client=self.client;self.client=None;self.generation+=1
            with contextlib.suppress(Exception):await asyncio.wait_for(client.disconnect(),5.)
        self.owned=False;self.running=False;self.control_available=False
        if announce:self.state('disconnected',message='Home trainer déconnecté.')

    def can_control(self):
        return (self.context.get('ride') is True and self.context.get('control') is True
            and self.clock()-self.last_heartbeat<=3 and self.clock()-self.last_power<=2.5)

    async def heartbeat(self,message):
        self.last_heartbeat=self.clock();self.context=message
        await self.apply_control()

    def receive_heartbeat(self,message):
        self.last_heartbeat=self.clock();self.context=message;self.control_pending=True
        if self.control_task is None or self.control_task.done():self.control_task=asyncio.create_task(self.control_worker())

    async def control_worker(self):
        while self.control_pending:
            self.control_pending=False
            await self.apply_control()

    async def apply_control(self):
        if not self.can_control():
            if self.running:await self.stop()
            return
        if self.client is None or not self.control_available:return
        try:
            if not self.owned:await self.command(bytes([0x00]));self.owned=True
            # Requests are coalesced, not queued: a pause received during a
            # slow GATT response takes precedence over earlier slope updates.
            if not self.can_control():await self.stop();return
            if not self.running:await self.command(bytes([0x07]));self.running=True
            if not self.can_control():await self.stop();return
            payload=simulation(self.context.get('grade',0.))
            if self.last_grade!=payload and self.clock()-self.last_grade_at>=1:
                await self.command(payload);self.last_grade=payload;self.last_grade_at=self.clock()
        except Exception as error:
            await self.stop();self.control_available=False
            self.emit({'type':'control_error','message':(str(error)[:220] or 'Délai de réponse FTMS dépassé')+' · lecture des mesures conservée'})

    async def watchdog(self):
        while True:
            await asyncio.sleep(.5)
            if self.running and not self.can_control():await self.stop()

    async def handle(self,message):
        operation=message.get('op')
        if operation in ('scan','connect','disconnect'):
            await self.cancel_operations()
            if operation=='scan':self.schedule('scan',self.scan())
            elif operation=='connect':self.schedule('connect',self.connect(message.get('id','')))
            else:await self.disconnect()
        elif operation in ('heartbeat','sync'):
            if isinstance(message.get('clock_ms'),(int,float)):
                self.emit({'type':'clock','remote_ms':int(self.clock()*1000),'echo_ms':message['clock_ms']})
                delta=self.clock()*1000-float(message['clock_ms'])
                self.game_clock_delta=delta if self.game_clock_delta is None else min(delta,self.game_clock_delta)
                if operation=='heartbeat' and delta-self.game_clock_delta>2000:message={**message,'ride':False}
            if operation=='heartbeat':self.receive_heartbeat(message)
        elif operation=='shutdown':return False
        else:raise ValueError('Commande Bluetooth inconnue')
        return True


# Kept explicit so tests exercise the same failure path without importing BLE.
import struct
struct_error=struct.error

async def run(port,token):
    from bleak import BleakClient,BleakScanner
    if sys.platform=='win32':
        from bleak.backends.winrt.util import uninitialize_sta
        uninitialize_sta()
    reader,writer=await asyncio.open_connection('127.0.0.1',port,limit=16384)
    def emit(message):writer.write((json.dumps(message,allow_nan=False,separators=(',',':'))+'\n').encode())
    emit({'type':'hello','version':1,'token':token,'clock_ms':int(time.monotonic()*1000)});await writer.drain()
    bridge=Bridge(emit,BleakScanner,BleakClient);watchdog=asyncio.create_task(bridge.watchdog())
    bridge.state('ready',message='Bluetooth prêt. Lancez une recherche.')
    try:
        while line:=await reader.readline():
            try:
                message=json.loads(line)
                if not isinstance(message,dict):raise ValueError('Invalid command')
                if not await bridge.handle(message):break
            except (ValueError,RuntimeError) as error:emit({'type':'error','message':str(error)[:220]})
            await writer.drain()
    finally:
        watchdog.cancel()
        with contextlib.suppress(asyncio.CancelledError):await watchdog
        await bridge.cancel_operations();await bridge.disconnect(announce=False)
        writer.close()
        with contextlib.suppress(Exception):await writer.wait_closed()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int);parser.add_argument('--token');parser.add_argument('--self-test',action='store_true')
    args=parser.parse_args()
    if args.self_test:
        from bleak import BleakClient,BleakScanner
        if sys.platform=='win32':
            from bleak.backends.winrt.client import BleakClientWinRT
        assert indoor_bike(bytes.fromhex('44000000a000c800'))['watts']==200
        print('BLUETOOTH_SELF_TEST_OK');return
    if args.port is None or not 1024<=args.port<=65535 or not args.token or len(args.token)!=64:parser.error('authenticated local endpoint required')
    asyncio.run(run(args.port,args.token))


if __name__=='__main__':main()
