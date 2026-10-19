class_name LabCameraTuning
extends Resource
## Camera presentation only. These values never change contact geometry or charge.
@export_range(1.0, 12.0, 0.1) var distance := 4.2
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity := 0.0022
@export_range(30.0, 100.0) var field_of_view := 65.0
@export_range(1.0, 40.0) var follow_response := 18.0
@export_range(0.05, 1.0) var floor_clearance := 0.4
@export var minimum_pitch := -0.65
@export var maximum_pitch := 1.15
