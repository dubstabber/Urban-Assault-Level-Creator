extends VBoxContainer


func set_labels(key_sector_id: int, beam_gate_id: int) -> void:
	%KeySectorInfoLabel.text = 'Key sector %s' % key_sector_id
	%BeamGateInfoLabel.text = 'This key sector belongs to beam gate %s' % beam_gate_id
