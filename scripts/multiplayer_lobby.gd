class_name MultiplayerLobby
extends Control

signal back_requested

enum Form { CHOOSE, HOST, JOIN }

var session: MultiplayerSession
var planning: MatchPlanning
var planning_screen: MatchPlanningScreen
var loadout_panel: LoadoutPanel
var _form: Form = Form.CHOOSE
var _submitting: bool = false
var _last_state: int = -1
var _planning_was_active: bool = false
var _loadout_was_selecting: bool = false

@onready var host_button: Button = %Host
@onready var join_button: Button = %Join
@onready var singleplayer_button: Button = %Singleplayer
@onready var address_input: LineEdit = %Address
@onready var port_input: SpinBox = %Port
@onready var host_create_button: Button = %Create
@onready var join_code_input: LineEdit = %JoinCode
@onready var join_connect_button: Button = %Connect
@onready var code_output: TextEdit = %Code
@onready var copy_button: Button = %Copy
@onready var back_button: Button = %Back
@onready var _choices: VBoxContainer = %Choices
@onready var _host_form: VBoxContainer = %HostForm
@onready var _join_form: VBoxContainer = %JoinForm
@onready var _invitation: VBoxContainer = %Invitation
@onready var _status: Label = %Status
@onready var _title: Label = %Title
@onready var _players: Label = %Players
@onready var _error: RichTextLabel = %Error
@onready var _scroll: ScrollContainer = %Scroll
@onready var _margin: MarginContainer = $Margin
@onready var _background: ColorRect = $Background


func _ready() -> void:
	CloseButtonStyle.apply(back_button)
	MenuAudio.bind_action(back_button)
	planning_screen = preload("res://scenes/planning_screen.tscn").instantiate()
	planning_screen.planning = planning
	planning_screen.hide()
	add_child(planning_screen)
	planning_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	planning_screen.leave_requested.connect(_request_back)
	loadout_panel = LoadoutPanel.new()
	loadout_panel.planning = planning
	loadout_panel.hide()
	add_child(loadout_panel)
	loadout_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loadout_panel.leave_requested.connect(_request_back)
	if planning != null:
		planning.changed.connect(_planning_changed)
	host_button.pressed.connect(_show_host)
	join_button.pressed.connect(_show_join)
	singleplayer_button.pressed.connect(_start_singleplayer)
	host_create_button.pressed.connect(_create_host)
	join_connect_button.pressed.connect(_join_host)
	address_input.text_submitted.connect(_submit_address)
	port_input.get_line_edit().add_theme_font_override("font", address_input.get_theme_font("font"))
	port_input.get_line_edit().text_submitted.connect(_submit_address)
	join_code_input.text_submitted.connect(_submit_code)
	copy_button.pressed.connect(_copy_code)
	back_button.pressed.connect(_request_back)
	visibility_changed.connect(_visibility_changed)
	address_input.text = _default_address()
	if session != null:
		session.changed.connect(_session_changed)
	_refresh()


func open() -> void:
	show()
	if not is_node_ready():
		return
	if session == null or session.state == MultiplayerSession.State.IDLE:
		_form = Form.CHOOSE
	_scroll.scroll_vertical = 0
	_refresh()
	_focus_action.call_deferred()


func prepare_to_leave() -> void:
	if is_instance_valid(planning_screen):
		planning_screen.cancel_strokes()
	if is_instance_valid(planning):
		planning.stop_singleplayer()
	if is_instance_valid(session):
		session.leave()
	_form = Form.CHOOSE
	_last_state = -1


func _exit_tree() -> void:
	prepare_to_leave()


func _visibility_changed() -> void:
	if is_node_ready() and not is_visible_in_tree():
		prepare_to_leave()


func _request_back() -> void:
	prepare_to_leave()
	back_requested.emit()


func _show_host() -> void:
	if not _can_start():
		return
	_form = Form.HOST
	_refresh()
	address_input.grab_focus()


func _show_join() -> void:
	if not _can_start():
		return
	_form = Form.JOIN
	_refresh()
	join_code_input.grab_focus()


func _start_singleplayer() -> void:
	if _can_start() and planning != null:
		planning.start_singleplayer()


func _submit_address(_text: String) -> void:
	MenuAudio.activate(host_create_button)


func _submit_code(_text: String) -> void:
	MenuAudio.activate(join_connect_button)


func _create_host() -> void:
	if not _can_start() or _form != Form.HOST:
		return
	_submitting = true
	_refresh()
	port_input.apply()
	session.host(_advertised_addresses(address_input.text.strip_edges(), IP.get_local_interfaces()), int(port_input.value))
	_submitting = false
	_refresh()
	_focus_action.call_deferred()


func _join_host() -> void:
	if not _can_start() or _form != Form.JOIN:
		return
	_submitting = true
	_refresh()
	session.join(join_code_input.text)
	_submitting = false
	_refresh()
	_focus_action.call_deferred()


func _can_start() -> bool:
	return session != null and not _submitting and session.state in [MultiplayerSession.State.IDLE, MultiplayerSession.State.ERROR]


func _copy_code() -> void:
	if copy_button.disabled or session == null:
		return
	DisplayServer.clipboard_set(session.invite_code)
	copy_button.text = "Copied"


func _session_changed() -> void:
	if not is_node_ready():
		return
	var state_changed: bool = _last_state != session.state
	_refresh()
	if state_changed and is_visible_in_tree():
		_focus_action.call_deferred()


func _planning_changed() -> void:
	if not is_node_ready():
		return
	var planning_active: bool = planning != null and planning.active
	var selecting: bool = planning != null and planning.selecting_loadout
	var activity_changed: bool = planning_active != _planning_was_active or selecting != _loadout_was_selecting
	_planning_was_active = planning_active
	_loadout_was_selecting = selecting
	_refresh()
	if activity_changed and is_visible_in_tree():
		_focus_action.call_deferred()


func _refresh() -> void:
	var planning_active: bool = planning != null and planning.active
	var selecting: bool = planning != null and planning.selecting_loadout
	_margin.visible = not planning_active and not selecting
	_background.visible = not planning_active
	_scroll.visible = not planning_active and not selecting
	planning_screen.visible = planning_active
	loadout_panel.visible = selecting
	var available: bool = _can_start()
	var active: bool = session != null and session.state in [MultiplayerSession.State.HOSTING, MultiplayerSession.State.CONNECTING, MultiplayerSession.State.CONNECTED]
	var editable: bool = session != null and not active
	var has_code: bool = active and not planning_active and session.is_host and not session.invite_code.is_empty()
	_choices.visible = not active
	host_button.set_pressed_no_signal(_form == Form.HOST)
	join_button.set_pressed_no_signal(_form == Form.JOIN)
	singleplayer_button.theme_type_variation = &"PrimaryButton" if _form == Form.CHOOSE else &""
	_title.visible = not active
	host_button.disabled = not available
	join_button.disabled = not available
	singleplayer_button.disabled = not available
	_host_form.visible = not active and _form == Form.HOST
	_join_form.visible = not active and _form == Form.JOIN
	address_input.editable = editable
	port_input.editable = editable
	join_code_input.editable = editable
	host_create_button.disabled = not available
	join_connect_button.disabled = not available
	_invitation.visible = has_code
	copy_button.disabled = not has_code
	var code: String = session.invite_code if has_code else ""
	if code_output.text != code:
		code_output.text = code
		copy_button.text = "Copy code"
	_error.text = session.error_message if session != null else "No session was supplied. Return to the menu and reopen Play."
	_error.visible = not _error.text.is_empty()
	_players.text = ""
	_players.hide()
	_status.visible = session == null or session.state not in [MultiplayerSession.State.IDLE, MultiplayerSession.State.ERROR]
	if session == null:
		_status.text = "Connection unavailable"
		return
	_last_state = session.state
	match session.state:
		MultiplayerSession.State.IDLE, MultiplayerSession.State.ERROR:
			_status.text = ""
		MultiplayerSession.State.HOSTING:
			_status.text = "Waiting for friend"
			_players.text = "Host · %d / 2 players" % session.player_count()
		MultiplayerSession.State.CONNECTING:
			_status.text = "Connecting to host…"
		MultiplayerSession.State.CONNECTED:
			_status.text = "Connected"
			_players.text = "%s · %d / 2 players" % ["Host" if session.is_host else "Guest", session.player_count()]
	_players.visible = not _players.text.is_empty()


func _focus_action() -> void:
	if not is_visible_in_tree():
		return
	if session == null:
		back_button.grab_focus()
	elif planning != null and planning.active:
		planning_screen.menu_button.grab_focus()
	elif planning != null and planning.selecting_loadout:
		if not loadout_panel.commit_button.disabled:
			loadout_panel.commit_button.grab_focus()
		else:
			for button: Button in loadout_panel.tower_buttons.values():
				if not button.disabled:
					button.grab_focus()
					break
	elif session.state in [MultiplayerSession.State.HOSTING, MultiplayerSession.State.CONNECTED]:
		if _invitation.visible:
			copy_button.grab_focus()
		else:
			back_button.grab_focus()
	elif session.state == MultiplayerSession.State.CONNECTING:
		back_button.grab_focus()
	elif _form == Form.HOST:
		address_input.grab_focus()
	elif _form == Form.JOIN:
		join_code_input.grab_focus()
	else:
		singleplayer_button.grab_focus()


func _default_address() -> String:
	return _preferred_host_address(IP.get_local_interfaces())


# The shown (most likely) address plus every other usable local address as
# fallbacks, so the guest connects through whichever network they share.
# A typed address replaces the list: VPN/public hosting stays explicit.
static func _advertised_addresses(typed: String, interfaces: Array[Dictionary]) -> String:
	var detected: PackedStringArray = _host_addresses(interfaces)
	if typed.is_empty() or (not detected.is_empty() and typed == detected[0]):
		return ",".join(detected) if not detected.is_empty() else "127.0.0.1"
	return typed


static func _preferred_host_address(interfaces: Array[Dictionary]) -> String:
	var addresses: PackedStringArray = _host_addresses(interfaces)
	return addresses[0] if not addresses.is_empty() else "127.0.0.1"


# Usable IPv4 addresses, most likely reachable by a LAN friend first: physical
# Wi-Fi/Ethernet private addresses, other physical, other private (often VPN
# tunnels), anything else, then virtual machine/container adapters.
static func _host_addresses(interfaces: Array[Dictionary]) -> PackedStringArray:
	var tiers: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray()]
	for interface: Dictionary in interfaces:
		var interface_name: String = String(interface.get("name", "")).to_lower()
		var friendly: String = String(interface.get("friendly", "")).to_lower()
		var virtual: bool = false
		for marker: String in ["docker", "br-", "veth", "virbr", "vbox", "virtualbox", "vmware", "vmnet", "vethernet", "hyper-v", "wsl", "lxc", "lxd"]:
			virtual = virtual or interface_name.contains(marker) or friendly.contains(marker)
		# Interface enumeration can put a non-peer VPN tunnel before Wi-Fi.
		var is_lan: bool = not virtual and (interface_name.begins_with("en") or interface_name.begins_with("eth") or interface_name.begins_with("wl") or friendly.contains("wi-fi") or friendly.contains("wifi") or friendly.contains("wireless") or friendly.contains("ethernet"))
		for address: String in interface.get("addresses", []):
			if not address.is_valid_ip_address() or address.contains(":") or address.begins_with("127.") or address.begins_with("169.254.") or address.get_slice(".", 0).to_int() == 0 or address.get_slice(".", 0).to_int() >= 224:
				continue
			var second_octet: int = address.get_slice(".", 1).to_int()
			var is_private: bool = address.begins_with("192.168.") or address.begins_with("10.") or (address.begins_with("172.") and second_octet >= 16 and second_octet <= 31)
			var tier: int = 4 if virtual else (0 if is_lan and is_private else (1 if is_lan else (2 if is_private else 3)))
			tiers[tier].append(address)
	var ranked := PackedStringArray()
	for tier: PackedStringArray in tiers:
		for address: String in tier:
			if address not in ranked and ranked.size() < MultiplayerSession.MAX_INVITE_ADDRESSES:
				ranked.append(address)
	return ranked
