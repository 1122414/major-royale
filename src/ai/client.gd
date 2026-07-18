extends Node
## AI 决策服务客户端（Godot 端）。

signal decision_received(action_id: String, intent_text: String, ending_flag: String, source: String, request_token: int)
signal decision_failed(request_token: int)

const TIMEOUT_SECONDS := 5.0

var _http_request: HTTPRequest
var _pending := false
var _active_request_token := -1


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)
	_http_request.timeout = TIMEOUT_SECONDS


func request_decision(context: Dictionary) -> bool:
	var request_token := int(context.get("request_token", -1))
	if _pending:
		decision_failed.emit(request_token)
		return false

	if not Settings.ai_enabled:
		decision_failed.emit(request_token)
		return false

	var url := Settings.ai_server_url + "/decide"
	var body := JSON.stringify(context)
	var headers := ["Content-Type: application/json"]

	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("AI 请求失败: %d" % err)
		decision_failed.emit(request_token)
		return false

	_pending = true
	_active_request_token = request_token
	return true


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_token := _active_request_token
	_pending = false
	_active_request_token = -1

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		decision_failed.emit(request_token)
		return

	var json := JSON.new()
	var err := json.parse(body.get_string_from_utf8())
	if err != OK:
		decision_failed.emit(request_token)
		return

	var data := json.data as Dictionary
	if not data.has("action_id") or not data.has("intent_text"):
		decision_failed.emit(request_token)
		return

	decision_received.emit(
		str(data.get("action_id", "")),
		str(data.get("intent_text", "")),
		str(data.get("ending_flag", "")),
		str(data.get("source", "llm")),
		request_token
	)


func is_pending() -> bool:
	return _pending
