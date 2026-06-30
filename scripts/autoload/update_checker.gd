extends Node

## Checks GitHub Releases for newer builds; opens the launcher or itch page to update.

signal update_available(remote_label: String)
signal check_finished(has_update: bool)

const DISTRIBUTION_PATH := "res://distribution.json"
const UPDATE_BAT := "UpdateAndRestart.bat"

var has_update: bool = false
var remote_label: String = ""
var _http: HTTPRequest
var _pending_owner: String = ""
var _pending_repo: String = ""
var _using_fallback: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func check_for_updates() -> void:
	has_update = false
	remote_label = ""
	_using_fallback = false
	var dist := _load_distribution()
	if dist.is_empty():
		check_finished.emit(false)
		return
	_pending_owner = str(dist.get("github_owner", ""))
	_pending_repo = str(dist.get("github_repo", ""))
	if _pending_owner.is_empty() or _pending_repo.is_empty():
		check_finished.emit(false)
		return
	_request_latest_release()


func _request_latest_release() -> void:
	var url := "https://api.github.com/repos/%s/%s/releases/latest" % [_pending_owner, _pending_repo]
	var headers := PackedStringArray(["User-Agent: MazeWars-UpdateChecker"])
	_http.request(url, headers)


func _request_newest_release() -> void:
	_using_fallback = true
	var url := "https://api.github.com/repos/%s/%s/releases?per_page=5" % [_pending_owner, _pending_repo]
	var headers := PackedStringArray(["User-Agent: MazeWars-UpdateChecker"])
	_http.request(url, headers)


func launch_updater() -> bool:
	var update_bat := _install_dir().path_join(UPDATE_BAT)
	if FileAccess.file_exists(update_bat):
		var err := OS.create_process(update_bat, PackedStringArray(), false)
		if err == OK:
			get_tree().quit()
			return true

	var dist := _load_distribution()
	var itch_url := str(dist.get("itch_url", ""))
	if not itch_url.is_empty():
		OS.shell_open(itch_url)
		return true

	var owner: String = str(dist.get("github_owner", ""))
	var repo: String = str(dist.get("github_repo", ""))
	if not owner.is_empty() and not repo.is_empty():
		OS.shell_open("https://github.com/%s/%s/releases/latest" % [owner, repo])
		return true

	return false


func get_local_build_stamp() -> String:
	var stamp_path := _install_dir().path_join("version.txt")
	if FileAccess.file_exists(stamp_path):
		var text := FileAccess.get_file_as_string(stamp_path).strip_edges()
		if text.contains("+") and text.split("+", false, 1)[0].contains("."):
			return text
	var fallback := _install_dir().path_join("update.stamp")
	if FileAccess.file_exists(fallback):
		return FileAccess.get_file_as_string(fallback).strip_edges()
	return GameVersion.version_label


func _remote_build_stamp(data: Dictionary) -> String:
	var body := str(data.get("body", ""))
	var version := ""
	var sha := ""
	var ver_re := RegEx.new()
	ver_re.compile("Version:\\s*(\\S+)")
	var m_ver := ver_re.search(body)
	if m_ver:
		version = m_ver.get_string(1)
	var sha_re := RegEx.new()
	sha_re.compile("Auto-built from `([a-f0-9]+)`")
	var m_sha := sha_re.search(body)
	if m_sha:
		sha = m_sha.get_string(1).substr(0, 7)
	if not version.is_empty() and not sha.is_empty():
		return "%s+%s" % [version, sha]
	if not sha.is_empty():
		return sha
	var assets: Array = data.get("assets", [])
	for asset in assets:
		if asset is Dictionary and str(asset.get("name", "")) == "MazeWars-win64.zip":
			return "%s|%s" % [str(asset.get("id", "")), str(asset.get("updated_at", ""))]
	return str(data.get("published_at", data.get("tag_name", "")))


func _install_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://build")
	return OS.get_executable_path().get_base_dir()


func _load_distribution() -> Dictionary:
	if not FileAccess.file_exists(DISTRIBUTION_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DISTRIBUTION_PATH))
	return data if data is Dictionary else {}


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if not _using_fallback and response_code == 404:
			_request_newest_release()
			return
		check_finished.emit(false)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var data: Dictionary = {}
	if parsed is Dictionary:
		data = parsed
	elif parsed is Array and not (parsed as Array).is_empty():
		var first = (parsed as Array)[0]
		if first is Dictionary:
			data = first
	if data.is_empty():
		check_finished.emit(false)
		return

	var remote_stamp := _remote_build_stamp(data)
	var local_stamp := get_local_build_stamp()

	has_update = not remote_stamp.is_empty() and remote_stamp != local_stamp
	remote_label = remote_stamp
	if has_update:
		update_available.emit(remote_label)
	check_finished.emit(has_update)
