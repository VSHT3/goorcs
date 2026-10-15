class_name MultiplayerLobby
extends Control

signal back_requested

enum Form { CHOOSE, HOST, JOIN }

var session: MultiplayerSession
var planning: MatchPlanning
var planning_screen: MatchPlanningScreen
var _form: Form = Form.CHOOSE
var _submitting: bool = false
var _last_state: int = -1
var _planning_was_active: bool = false

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
	planning_screen = preload("res://scenes/planning_screen.tscn").instantiate()
	planning_screen.planning = planning
	planning_screen.hide()
	add_child(planning_screen)
	planning_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	planning_screen.leave_requested.connect(_request_back)
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
	_create_host()


func _submit_code(_text: String) -> void:
	_join_host()


func _create_host() -> void:
	if not _can_start() or _form != Form.HOST:
		return
	_submitting = true
	_refresh()
	port_input.apply()
	session.host(address_input.text.strip_edges(), int(port_input.value))
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
	var activity_changed: bool = planning_active != _planning_was_active
	_planning_was_active = planning_active
	_refresh()
	if activity_changed and is_visible_in_tree():
		_focus_action.call_deferred()


func _refresh() -> void:
	var planning_active: bool = planning != null and planning.active
	_margin.visible = not planning_active
	_background.visible = not planning_active
	_scroll.visible = not planning_active
	planning_screen.visible = planning_active
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
	back_button.text = "Leave / Esc" if active else "Back / Esc"
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
			back_button.text = "Cancel / Esc"
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
	var candidate: String = ""
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if candidate.is_empty():
			candidate = address
		if address.begins_with("192.168.") or address.begins_with("10."):
			return address
		var octets: PackedStringArray = address.split(".")
		if octets.size() == 4 and octets[0] == "172" and int(octets[1]) >= 16 and int(octets[1]) <= 31:
			return address
	return candidate if not candidate.is_empty() else "127.0.0.1"
