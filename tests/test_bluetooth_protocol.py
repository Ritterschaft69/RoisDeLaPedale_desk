import asyncio,contextlib,struct,sys,unittest
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'bluetooth'))
from protocol import indoor_bike,CyclingPower,simulation,BIKE,POWER,CONTROL,FEATURE,FTMS
from bridge import Bridge


class ProtocolTests(unittest.TestCase):
    def test_ftms_speed_cadence_and_signed_power(self):
        packet=struct.pack('<HHHh',0x44,2870,173,264)
        self.assertEqual(indoor_bike(packet),{'trainer_speed_kmh':28.7,'cadence':86.5,'watts':264})
        self.assertEqual(indoor_bike(struct.pack('<Hh',0x41,-12)),{'watts':0})

    def test_all_optional_fields_and_more_data_do_not_shift_power(self):
        packet=struct.pack('<H',0x1ffe)+struct.pack('<HHHH',2400,2200,160,150)+b'\x01\x02\x03'+struct.pack('<hhH',45,318,300)+b'\0'*5+b'\x60\x20'+b'\0'*4
        data=indoor_bike(packet)
        self.assertEqual(data['watts'],318);self.assertEqual(data['cadence'],80)
        self.assertEqual(indoor_bike(b'\x01\x00'),{})

    def test_truncation_never_produces_a_partial_measurement(self):
        packet=struct.pack('<HHHh',0x44,2500,164,240)
        for size in range(len(packet)):
            with self.assertRaises(ValueError):indoor_bike(packet[:size])
        with self.assertRaises(ValueError):indoor_bike(struct.pack('<HHHh',0x44,2500,501,200))

    def test_cycling_power_optional_offsets_and_counter_wrap(self):
        decoder=CyclingPower()
        def packet(rev,ticks):return struct.pack('<HhBHIHH',0x35,220,50,3,1234,88,rev)+struct.pack('<H',ticks)
        self.assertEqual(decoder.decode(packet(65535,65000))['watts'],220)
        rpm=decoder.decode(packet(0,488))['cadence']
        self.assertAlmostEqual(rpm,60)
        before=decoder.previous
        with self.assertRaises(ValueError):decoder.decode(packet(1,1512)[:-1])
        self.assertEqual(decoder.previous,before)

    def test_stopped_cranks_zero_cadence_after_two_seconds(self):
        now=[0.];d=CyclingPower(lambda:now[0]);p=struct.pack('<HhHH',32,0,1,1024)
        d.decode(p);now[0]=3
        self.assertEqual(d.decode(p)['cadence'],0)

    def test_slope_encoding_is_bounded_and_finite(self):
        self.assertEqual(simulation(4.8),struct.pack('<BhhBB',0x11,0,480,40,51))
        self.assertEqual(struct.unpack('<BhhBB',simulation(99))[2],1000)
        self.assertEqual(struct.unpack('<BhhBB',simulation(-99))[2],-1000)
        for value in [float('nan'),float('inf'),True,'10']:
            with self.assertRaises(ValueError):simulation(value)


class FakeClient:
    def __init__(self,device,disconnected_callback=None,**_kwargs):
        self.name=device.name;self.callback=disconnected_callback;self.callbacks={};self.writes=[];self.closed=False
        self.services=[SimpleNamespace(characteristics=[SimpleNamespace(uuid=u) for u in [BIKE,POWER,FEATURE,CONTROL]])]
    async def connect(self):pass
    async def disconnect(self):self.closed=True
    async def start_notify(self,u,callback):self.callbacks[u]=callback
    async def read_gatt_char(self,_uuid):return struct.pack('<II',1<<14,1<<13)
    async def write_gatt_char(self,_uuid,data,response):
        self.writes.append(bytes(data));self.callbacks[CONTROL](CONTROL,bytes([0x80,data[0],1]))


class BridgeTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.events=[];self.now=[100.]
        device=SimpleNamespace(address='test',name='Elite Suito-T')
        class Scanner:
            @staticmethod
            async def discover(**kwargs):return {'test':(device,SimpleNamespace(service_uuids=[FTMS],local_name=device.name,rssi=-45))}
        self.bridge=Bridge(self.events.append,Scanner,FakeClient,lambda:self.now[0])
        await self.bridge.scan();await self.bridge.connect('test')
        self.client=self.bridge.client
    async def asyncTearDown(self):await self.bridge.disconnect()
    def power(self,watts=210):self.client.callbacks[BIKE](BIKE,struct.pack('<HHHh',0x44,2500,160,watts))

    async def test_scan_connect_and_notifications_use_real_profile(self):
        self.assertTrue(self.bridge.control_available)
        self.power()
        self.assertEqual(self.events[-1]['watts'],210);self.assertEqual(self.events[-1]['cadence'],80)
        self.assertIn('at_ms',self.events[-1])
        count=len(self.events);last=self.bridge.last_power;self.now[0]+=1
        self.client.callbacks[BIKE](BIKE,b'\x44\x00')
        self.assertEqual(len(self.events),count);self.assertEqual(self.bridge.last_power,last)

    async def test_read_only_default_never_writes_resistance(self):
        self.power();await self.bridge.heartbeat({'ride':True,'control':False,'grade':9})
        self.assertEqual(self.client.writes,[])

    async def test_control_request_start_grade_and_neutral_on_pause(self):
        self.power();await self.bridge.heartbeat({'ride':True,'control':True,'grade':4.8})
        self.assertEqual([p[0] for p in self.client.writes],[0,7,0x11])
        self.assertEqual(self.client.writes[-1],simulation(4.8))
        await self.bridge.heartbeat({'ride':False,'control':True,'grade':9})
        self.assertEqual(self.client.writes[-2:],[simulation(0),b'\x08\x02'])
        self.assertFalse(self.bridge.running)

    async def test_stale_data_never_activates_grade_and_watchdog_stops(self):
        await self.bridge.heartbeat({'ride':True,'control':True,'grade':10});self.assertFalse(self.client.writes)
        self.power();await self.bridge.heartbeat({'ride':True,'control':True,'grade':10})
        self.now[0]+=4
        task=asyncio.create_task(self.bridge.watchdog());await asyncio.sleep(.55);task.cancel()
        with contextlib.suppress(asyncio.CancelledError):await task
        self.assertFalse(self.bridge.running)
        self.assertEqual(self.client.writes[-2:],[simulation(0),b'\x08\x02'])

    async def test_disconnect_ignores_late_packets_and_releases(self):
        self.power();generation=self.bridge.generation
        await self.bridge.heartbeat({'ride':True,'control':True,'grade':3})
        await self.bridge.disconnect();before=len(self.events)
        self.bridge.notification(BIKE,struct.pack('<HHHh',0x44,2500,160,600),generation)
        self.assertEqual(len(self.events),before);self.assertTrue(self.client.closed)
        self.assertEqual(self.client.writes[-1],b'\x01')

    async def test_rejected_control_retains_measurement_connection(self):
        async def reject(_uuid,data,response):
            self.client.writes.append(bytes(data));self.client.callbacks[CONTROL](CONTROL,bytes([0x80,data[0],5]))
        self.client.write_gatt_char=reject;self.power()
        await self.bridge.heartbeat({'ride':True,'control':True,'grade':3})
        self.assertFalse(self.bridge.control_available);self.assertIsNotNone(self.bridge.client)
        self.power(230);self.assertEqual(self.events[-1]['watts'],230)

    async def test_unknown_device_does_not_disconnect_existing_trainer(self):
        with self.assertRaises(ValueError):await self.bridge.connect('unknown')
        self.assertIs(self.bridge.client,self.client)

    async def test_pause_supersedes_a_slow_pending_control_request(self):
        release=asyncio.Event();old_write=self.client.write_gatt_char
        async def slow(uuid,data,response):
            if data[0]==0:await release.wait()
            await old_write(uuid,data,response)
        self.client.write_gatt_char=slow;self.power()
        await self.bridge.handle({'op':'heartbeat','ride':True,'control':True,'grade':8})
        await asyncio.sleep(0)
        await asyncio.wait_for(self.bridge.handle({'op':'heartbeat','ride':False,'control':True,'grade':8}),.1)
        release.set();await self.bridge.control_task
        self.assertFalse(self.bridge.running)
        self.assertFalse(any(p[0]==7 or p==simulation(8) for p in self.client.writes))

    async def test_buffered_game_heartbeats_are_not_executed_as_fresh_control(self):
        await self.bridge.handle({'op':'sync','clock_ms':1000})
        self.now[0]+=5;self.power()
        await self.bridge.handle({'op':'heartbeat','clock_ms':1000,'ride':True,'control':True,'grade':8})
        await self.bridge.control_task
        self.assertFalse(self.client.writes)

    async def test_control_feature_failure_preserves_measurement_subscription(self):
        await self.bridge.disconnect()
        class ReadOnly(FakeClient):
            async def read_gatt_char(self,_uuid):raise RuntimeError('feature unavailable')
        self.bridge.client_factory=ReadOnly
        await self.bridge.connect('test');self.client=self.bridge.client
        self.assertFalse(self.bridge.control_available)
        self.power(220);self.assertEqual(self.events[-1]['watts'],220)

    async def test_cycling_power_only_device_remains_usable_without_ftms(self):
        await self.bridge.disconnect()
        class PowerOnly(FakeClient):
            def __init__(self,*args,**kwargs):
                super().__init__(*args,**kwargs)
                self.services=[SimpleNamespace(characteristics=[SimpleNamespace(uuid=POWER)])]
        self.bridge.client_factory=PowerOnly
        await self.bridge.connect('test');self.client=self.bridge.client
        self.client.callbacks[POWER](POWER,struct.pack('<Hh',0,230))
        self.assertEqual(self.events[-1]['watts'],230);self.assertFalse(self.bridge.control_available)

    async def test_write_and_indication_timeouts_do_not_block_measurements(self):
        from unittest import mock
        real_wait=asyncio.wait_for
        async def limited(awaitable,timeout):return await real_wait(awaitable,min(timeout,.02))
        for blocked_write in [True,False]:
            self.bridge.control_available=True;self.client.writes.clear();self.power()
            async def no_ack(_uuid,data,response):
                self.client.writes.append(bytes(data))
                if blocked_write:await asyncio.Event().wait()
            self.client.write_gatt_char=no_ack
            with mock.patch('bridge.asyncio.wait_for',side_effect=limited):
                await real_wait(self.bridge.heartbeat({'ride':True,'control':True,'grade':9}),.2)
            self.assertFalse(self.bridge.control_available)
            self.assertEqual(self.client.writes,[b'\x00'])
            self.power(225);self.assertEqual(self.events[-1]['watts'],225)
