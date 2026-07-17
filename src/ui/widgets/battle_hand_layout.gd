class_name BattleHandLayout
extends RefCounted
## 手牌区纯布局计算，保证 3～10 张牌始终落在固定安全区。

const AREA_LEFT := 168.0
const AREA_RIGHT := 1120.0
const MAX_CARD_WIDTH := 148.0
const SEPARATION := 7.0


static func calculate(card_count: int) -> Dictionary:
	var count := maxi(0, card_count)
	var area_width := AREA_RIGHT - AREA_LEFT
	if count == 0:
		return {"start_x": AREA_LEFT, "card_width": MAX_CARD_WIDTH, "total_width": 0.0, "separation": SEPARATION}
	var card_width := MAX_CARD_WIDTH
	if count > 1:
		card_width = minf(MAX_CARD_WIDTH, (area_width - SEPARATION * float(count - 1)) / float(count))
	var total_width := float(count) * card_width + float(maxi(0, count - 1)) * SEPARATION
	var start_x := AREA_LEFT + (area_width - total_width) * 0.5
	return {
		"start_x": start_x,
		"card_width": card_width,
		"total_width": total_width,
		"separation": SEPARATION,
	}
