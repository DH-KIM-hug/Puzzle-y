## Offline generator for tests/fixtures/tray/*.golden.json (tray-supply AC preamble:
## seed-dependent results are compared with committed golden files). Run once,
## review the diff, commit:
##   godot --headless --path . -s res://tests/fixtures/generators/gen_tray_goldens.gd
## Tests never call this script.
extends SceneTree

const OUT := "res://tests/fixtures/tray/"


func _init() -> void:
	_sequence("default_team_1201.golden.json", TrayFixture.DEFAULT_TEAM, 1201, 12)
	_sequence("eight_way_team_7.golden.json", TrayFixture.team([&"nyangi", &"gaegul", &"piyak"]), 7, 12)
	_sequence("dig_fill_team_42.golden.json", TrayFixture.team([&"gomgom", &"kkangchong", &"mongsil"]), 42, 12)
	_rescue_f5()
	quit()


func _sequence(file_name: String, team: Array[StringName], stage_seed: int, n: int) -> void:
	var played := TrayFixture.play(team, TrayFixture.cfg(), stage_seed, n)
	_write(file_name, {"stage_seed": stage_seed, "team": Array(team), "trays": played[&"trays"]})


## AC-11: first stage_seed whose first generated tray on the F5 board is
## {nyangi I4_H, gomgom O4, piyak D2_V} (rescue off), then the rescued tray.
func _rescue_f5() -> void:
	var board := TrayFixture.board("rescue_f5.txt")
	var want := ["I4_H:nyangi", "O4:gomgom", "D2_V:piyak"]
	for stage_seed: int in range(1, 200000):
		var off := TrayFixture.cfg()
		off.rescue_enabled = false
		var s := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, off, stage_seed, TrayFixture.registry())
		var cand := TraySupplyRules.refill(s, board, TraySupplyRules.BUDGET_UNLIMITED)
		var got := []
		for p: PieceInstance in cand.pieces:
			got.append("%s:%s" % [p.shape.id, p.crew_id])
		var sorted_got := got.duplicate()
		sorted_got.sort()
		var sorted_want := want.duplicate()
		sorted_want.sort()
		if sorted_got != sorted_want:
			continue
		var s2 := TraySupplyRules.init_state(TrayFixture.DEFAULT_TEAM, TrayFixture.cfg(), stage_seed, TrayFixture.registry())
		var res := TraySupplyRules.refill(s2, board, TraySupplyRules.BUDGET_UNLIMITED)
		var rec: Dictionary = res.rescued[0]
		_write("rescue_f5.golden.json", {
			"stage_seed": stage_seed, "team": Array(TrayFixture.DEFAULT_TEAM), "board": "rescue_f5.txt",
			"candidates": TrayFixture.describe_slots(cand.state), "tray": TrayFixture.describe_slots(res.state),
			"rescued": {"slot": rec[TrayRefill.K_SLOT], "from_shape": String(rec[TrayRefill.K_FROM_SHAPE]), "to_shape": String(rec[TrayRefill.K_TO_SHAPE])},
		})
		return
	push_error("no seed found for rescue_f5")


func _write(file_name: String, data: Dictionary) -> void:
	var f := FileAccess.open(OUT + file_name, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
	print("wrote ", file_name)
