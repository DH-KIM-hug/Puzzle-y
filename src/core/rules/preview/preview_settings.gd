## Chain preview display knobs (design/gdd/chain-preview.md rules 13, 17).
## Stage data may override them; defaults are the MVP release values.
class_name PreviewSettings
extends Resource

## Information level (rule 17). MVP release stages are all FULL.
enum Detail { FULL, NO_BANNER, FIRST_STAGE_ONLY }

## Show the one-line predicted total (rule 13). Default off.
@export var show_predicted_score: bool = false
## Information level (rule 17).
@export var preview_detail: Detail = Detail.FULL
## Scoring rules used for the predicted total — the same resource the commit uses.
@export var scoring_rules: ScoringRules


## Settings with [member show_predicted_score] on, scored by [param rules].
static func with_score(rules: ScoringRules) -> PreviewSettings:
	var s := PreviewSettings.new()
	s.show_predicted_score = true
	s.scoring_rules = rules
	return s
