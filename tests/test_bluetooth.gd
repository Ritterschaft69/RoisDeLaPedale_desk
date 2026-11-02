extends SceneTree
const InputAdapter=preload("res://scripts/trainer_input.gd")
var passed:=0
var failed:=0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1;print("PASS ",message)
 else:failed+=1;push_error(message)
func wait_for(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+7000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 var input:=InputAdapter.new();input.mode="bluetooth"
 input.observe_metrics({"watts":220},1000);input.observe_metrics({"cadence":83},2000)
 check(input.read(2500).watts==220 and input.read(2500).cadence==83,"independent Bluetooth power and cadence timestamps merge partial packets")
 input.observe_metrics({"cadence":90},4000)
 check(input.read(4000).watts==0 and input.read(4000).cadence==90,"cadence updates do not keep stale power alive")
 input.observe_metrics({"watts":"999","cadence":NAN},4500)
 check(input.read(4500).watts==0,"invalid measurements never refresh a real observation")
 input.invalidate();check(input.read(4500).watts==0 and input.mode=="bluetooth","disconnect clears values without falling back to demo")
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false)
 var b=app.bluetooth
 var ok:bool=b.start_bridge("python3",PackedStringArray([ProjectSettings.globalize_path("res://tests/fixtures/ble_peer.py")]))
 check(ok and await wait_for(func():return b.peer!=null),"authenticated loopback helper connects asynchronously")
 if b.peer==null:
  app.free();quit(1);return
 check(not b.connected,"a local client with the wrong token cannot inject a connected device")
 b.scan()
 check(await wait_for(func():return b.devices.has("test-suito")) and b.devices["test-suito"].name=="Elite Suito-T · test logiciel","scan results survive fragmented UTF-8 frames")
 app.show_devices()
 check(app.overlay.find_child("BluetoothScan",true,false)!=null,"Bluetooth search is available in the device screen")
 b.connect_device("test-suito")
 check(await wait_for(func():return b.connected and app.input.last_observation_ms>=0),"FTMS connection supplies real-input measurements to the application")
 app.input.demo_watts=500;app.start_bluetooth_session()
 for i in range(150):app._physics_process(.02)
 check(app.input.mode=="bluetooth" and app.watts==210 and app.cadence==80 and app.distance>1,"trainer watts rather than demo watts drive physics and pedalling")
 check(app.overlay.get_child_count()==1,"demo power controls are absent from a Bluetooth ride")
 var last:int=app.input.last_observation_ms
 b.handle_event({"type":"measurement","at_ms":Time.get_ticks_msec()-b.clock_delta_ms-4000,"watts":900,"cadence":200})
 check(app.input.last_observation_ms==last,"buffered notifications older than two seconds cannot be replayed as fresh watts")
 app.input.last_observation_ms=Time.get_ticks_msec()-2500;app.input.last_cadence_ms=Time.get_ticks_msec()-2500
 app._physics_process(.02)
 check(app.watts==0 and app.cadence==0 and app.input.mode=="bluetooth","signal loss zeros physical input while keeping its Bluetooth provenance")
 app.toggle_pause();var station:float=app.distance;app.show_devices();app.return_from_devices()
 check(app.screen=="paused" and app.distance==station,"reconnection screen preserves the paused activity")
 var saved:Dictionary=app.recorder.save(app.distance,false)
 var activity:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(saved.path))
 check(activity.input_source=="bluetooth" and "Suito" in activity.trainer_name and activity.missing_power_s>0,"recorded activities distinguish trainer measurements from demo")
 DirAccess.remove_absolute(saved.path)
 b.disconnect_device();app.show_home();app.start_demo_session()
 check(app.input.mode=="demo" and app.input.read(Time.get_ticks_msec()).watts==500,"demo remains an explicit user choice after disconnection")
 var pid:int=b.process_id;b.shutdown()
 check(await wait_for(func():return not OS.is_process_running(pid)),"closing the game connection lets the helper stop and exit")
 app.finish_session();app.input.demo_watts=180;app.show_home();app.save_settings();app.free();await process_frame
 print("RESULT_BLUETOOTH passed=",passed," failed=",failed)
 quit(0 if failed==0 else 1)
