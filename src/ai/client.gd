extends Node
## AI 决策服务客户端（Godot 端）。

signal decision_received(action_id: String, intent_text: String, ending_flag: String, source: String)
signal decision_failed

const TIMEOUT_SECONDS := 5.0

var _http_request: HTTPRequest
var _pending := false


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)
	_http_request.timeout = TIMEOUT_SECONDS


func request_decision(context: Dictionary) -> void:
	if _pending:
		return

	if not Settings.ai_enabled:
		decision_failed.emit()
		return

	var url := Settings.ai_server_url + "/decide"
	var body := JSON.stringify(context)
	var headers := ["Content-Type: application/json"]

	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("AI 请求失败: %d" % err)
		decision_failed.emit()
		return

	_pending = true


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_pending = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		decision_failed.emit()
		return

	var json := JSON.new()
	var err := json.parse(body.get_string_from_utf8())
	if err != OK:
		decision_failed.emit()
		return

	var data := json.data as Dictionary
	if not data.has("action_id") or not data.has("intent_text"):
		decision_failed.emit()
		return

	decision_received.emit(
		str(data.get("action_id", "")),
		str(data.get("intent_text", "")),
		str(data.get("ending_flag", "")),
		str(data.get("source", "llm"))
	)


func is_pending() -> bool:
	return _pending
