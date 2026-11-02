class_name CyclingBluetooth
extends Node
signal changed
signal measurement(values: Dictionary)
signal lost
var devices: Dictionary = {}
var connected := false
var control_available := false
var follow_grade := false
var device_name := ""
var profile := ""
var status := "Bluetooth non démarré."
var scanning := false
var connecting := false
var server := TCPServer.new()
var peer: StreamPeerTCP
var pending: Array[Dictionary] = []
var incoming := PackedByteArray()
var token := ""
var process_id := -1
var launched_ms := 0
var clock_delta_ms := 0
var best_clock_rtt_ms := 1000000
var last_heartbeat_ms := -10000
var ride_active := false
var grade_percent := 0.0

func start_bridge(executable: String = "", prefix: PackedStringArray = PackedStringArray()) -> bool:
	if process_id>0:return true
	var port := 0
	for i in range(12):
		port=24000+int(Crypto.new().generate_random_bytes(2).decode_u16(0))%20000
		if server.listen(port,"127.0.0.1")==OK:break
		port=0
	if port==0:status="Impossible d’ouvrir la connexion locale Bluetooth.";changed.emit();return false
	token=Crypto.new().generate_random_bytes(32).hex_encode()
	var args := prefix
	if executable.is_empty():
		if OS.get_name()=="Windows":
			executable=OS.get_executable_path().get_base_dir().path_join("RoisBluetooth.exe")
			if not FileAccess.file_exists(executable):
				executable=ProjectSettings.globalize_path("res://build/bluetooth/windows/RoisBluetooth.exe")
			if not FileAccess.file_exists(executable):
				server.stop();status="Module Bluetooth absent. Réinstallez la version complète.";changed.emit();return false
		else:
			var base := OS.get_executable_path().get_base_dir()
			var native := base.path_join("RoisBluetooth")
			if not FileAccess.file_exists(native):native=ProjectSettings.globalize_path("res://build/bluetooth/linux/RoisBluetooth")
			if FileAccess.file_exists(native):executable=native
			else:
				var script := base.path_join("bluetooth/bridge.py")
				if not FileAccess.file_exists(script):script=ProjectSettings.globalize_path("res://bluetooth/bridge.py")
				executable=OS.get_environment("RDP_BLUETOOTH_PYTHON")
				if executable.is_empty():
					var local_python := ProjectSettings.globalize_path("res://.venv/bin/python")
					executable=local_python if FileAccess.file_exists(local_python) else "python3"
				args.append(script)
	args.append_array(PackedStringArray(["--port",str(port),"--token",token]))
	process_id=OS.create_process(executable,args,false)
	if process_id<=0:
		server.stop();status="Impossible de lancer le module Bluetooth.";changed.emit();return false
	launched_ms=Time.get_ticks_msec();status="Initialisation du Bluetooth…";changed.emit();return true

func send_command(command: Dictionary) -> bool:
	if peer==null or peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:return false
	return peer.put_data((JSON.stringify(command)+"\n").to_utf8_buffer())==OK

func scan() -> void:
	if peer==null:status="Bluetooth en cours d’initialisation…";changed.emit();return
	devices.clear();status="Recherche des home trainers et capteurs de puissance…"
	scanning=true;send_command({"op":"scan"});changed.emit()

func connect_device(identity: String) -> void:
	if not devices.has(identity):return
	connecting=true;status="Connexion à "+str(devices[identity].name)+"…"
	send_command({"op":"connect","id":identity});changed.emit()

func disconnect_device() -> void:
	send_command({"op":"disconnect"})
	clear_connection();status="Home trainer déconnecté.";changed.emit()

func clear_connection() -> void:
	connected=false;control_available=false;connecting=false;ride_active=false
	lost.emit()

func handle_event(event: Dictionary) -> void:
	match str(event.get("type","")):
		"clock":
			if not (event.get("remote_ms") is int or event.get("remote_ms") is float):return
			if not (event.get("echo_ms") is int or event.get("echo_ms") is float):return
			var now:=Time.get_ticks_msec();var rtt:=now-int(event.echo_ms)
			if rtt>=0 and rtt<best_clock_rtt_ms:
				best_clock_rtt_ms=rtt;clock_delta_ms=int((now+int(event.echo_ms))/2)-int(event.remote_ms)
			return
		"device":
			var identity: String=str(event.get("id",""))
			if identity.length()>0 and identity.length()<200:
				devices[identity]={"name":str(event.get("name","Home trainer")).left(70),"ftms":event.get("ftms",false)}
		"scan":
			scanning=event.get("scanning",false)==true
			status="Recherche en cours…" if scanning else ("Aucun appareil compatible trouvé. Réveillez le Suito-T en pédalant, puis relancez la recherche." if devices.is_empty() else "Choisissez votre home trainer.")
		"state":
			match str(event.get("state","")):
				"ready":status="Bluetooth prêt. Lancez une recherche."
				"connecting":clear_connection();status="Connexion en cours…";connecting=true
				"connected":
					connected=true;connecting=false;device_name=str(event.get("name","Home trainer")).left(70)
					profile=str(event.get("profile",""));control_available=event.get("control_available",false)==true
					status=device_name+" connecté · "+profile
				"disconnected":clear_connection();status=str(event.get("message","Connexion perdue."))
		"measurement":
			if connected and (event.get("at_ms") is float or event.get("at_ms") is int):
				var observed := int(event.at_ms)+clock_delta_ms
				if Time.get_ticks_msec()-observed<=2000 and observed-Time.get_ticks_msec()<=1000:
					event["received_ms"]=mini(Time.get_ticks_msec(),observed);measurement.emit(event)
			return
		"control_error":
			control_available=false;status="Pilotage de la pente indisponible : "+str(event.get("message",""))
		"error":
			connecting=false;scanning=false;status=str(event.get("message","Bluetooth indisponible.")).left(280)
	changed.emit()

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	while server.is_connection_available():
		var candidate := server.take_connection()
		if pending.size()<4:pending.append({"peer":candidate,"buffer":PackedByteArray(),"at":now})
		else:candidate.disconnect_from_host()
	for i in range(pending.size()-1,-1,-1):
		var item: Dictionary=pending[i]
		var candidate: StreamPeerTCP=item.peer;candidate.poll()
		if now-int(item.at)>3000 or candidate.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
			candidate.disconnect_from_host();pending.remove_at(i);continue
		var size := candidate.get_available_bytes()
		if size>0:
			if size+item.buffer.size()>16384:candidate.disconnect_from_host();pending.remove_at(i);continue
			var buffer: PackedByteArray=item.buffer
			buffer.append_array(candidate.get_data(size)[1]);item.buffer=buffer
			var newline: int=item.buffer.find(10)
			if newline>=0:
				var hello=JSON.parse_string(item.buffer.slice(0,newline).get_string_from_utf8())
				if hello is Dictionary and hello.get("type")=="hello" and hello.get("version")==1 and hello.get("token")==token and (hello.get("clock_ms") is float or hello.get("clock_ms") is int):
					clock_delta_ms=now-int(hello.clock_ms);best_clock_rtt_ms=1000000
					peer=candidate;peer.set_no_delay(true);incoming=item.buffer.slice(newline+1);pending.remove_at(i);server.stop()
					status="Bluetooth prêt. Lancez une recherche.";send_command({"op":"sync","clock_ms":now});changed.emit()
				else:candidate.disconnect_from_host();pending.remove_at(i)
	if peer!=null:
		peer.poll()
		if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
			shutdown();status="Le module Bluetooth s’est arrêté. Relancez la recherche.";changed.emit();return
		var size := peer.get_available_bytes()
		if incoming.size()+size>16384:
			shutdown();status="Le module Bluetooth a envoyé un message invalide.";changed.emit();return
		if size>0:incoming.append_array(peer.get_data(size)[1])
		var newline := incoming.find(10)
		while newline>=0:
			var event=JSON.parse_string(incoming.slice(0,newline).get_string_from_utf8());incoming=incoming.slice(newline+1)
			if event is Dictionary:handle_event(event)
			newline=incoming.find(10)
		if now-last_heartbeat_ms>=1000:
			last_heartbeat_ms=now
			send_command({"op":"heartbeat","clock_ms":now,"ride":ride_active,"control":follow_grade and control_available,"grade":grade_percent})
	elif process_id>0 and (now-launched_ms>30000 or not OS.is_process_running(process_id)):
		shutdown();status="Bluetooth indisponible. Vérifiez l’installation du module et l’activation du Bluetooth sur ce PC.";changed.emit()

func update_ride(active: bool, grade: float) -> void:
	var changed_active := ride_active!=active
	ride_active=active;grade_percent=clampf(grade,-10,10)
	if changed_active:
		send_command({"op":"heartbeat","ride":active,"control":follow_grade and control_available,"grade":grade_percent})
		last_heartbeat_ms=Time.get_ticks_msec()

func shutdown() -> void:
	send_command({"op":"shutdown"})
	var authenticated := peer!=null
	if peer!=null:peer.disconnect_from_host();peer=null
	for item in pending:item.peer.disconnect_from_host()
	pending.clear();server.stop();incoming.clear()
	if not authenticated and process_id>0 and OS.is_process_running(process_id):OS.kill(process_id)
	process_id=-1;scanning=false;clear_connection()

func _exit_tree() -> void:shutdown()
