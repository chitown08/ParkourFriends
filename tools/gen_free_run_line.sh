#!/bin/bash
# Generates levels/free_run_line.tscn: one long straight course that shows off
# every move at superhuman scale, in order. It runs north (toward -Z) from the
# spawn at z = 0. Lanes are 8 m wide (x = -4..4) unless noted.
#
# Usage (from the project folder):  bash tools/gen_free_run_line.sh > levels/free_run_line.tscn
# Note: re-running this overwrites any changes made to that scene in the editor.

calc() { awk "BEGIN{printf \"%g\", $1}"; }
box() { # name parent cx cy cz sx sy sz material
  printf '\n[node name="%s" type="CSGBox3D" parent="%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nuse_collision = true\nsize = Vector3(%s, %s, %s)\nmaterial = ExtResource("%s")\n' "$@"; }
# A floor slab 2 m thick: name z_from z_to top [width] [x]   (z_from > z_to)
floor() {
  local w="${5:-8}" x="${6:-0}"
  box "$1" Course "$x" "$(calc "$4 - 1")" "$(calc "(($2) + ($3)) / 2")" "$w" 2 "$(calc "($2) - ($3)")" 3_ground
}
# A block standing on a surface: name z depth bottom top [width] [x] [material]
block() {
  local w="${6:-8}" x="${7:-0}" mat="${8:-4_platform}"
  box "$1" Course "$x" "$(calc "(($4) + ($5)) / 2")" "$2" "$w" "$(calc "($5) - ($4)")" "$3" "$mat"
}
label() { printf '\n[node name="%s" type="Label3D" parent="Labels"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nbillboard = 1\npixel_size = 0.02\ntext = "%s"\nfont_size = 64\noutline_size = 16\n' "$@"; }
checkpoint() { printf '\n[node name="%s" parent="Checkpoints" instance=ExtResource("2_checkpoint")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n' "$@"; }
relic() { printf '\n[node name="%s" parent="Relics" instance=ExtResource("10_relic")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n' "$@"; }
gate() { printf '\n[node name="%s" parent="Gates" instance=ExtResource("11_gate")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, %s)\nkind = %s\n' "$@"; }

cat <<'EOF'
[gd_scene format=3]

[ext_resource type="Script" path="res://levels/level.gd" id="1_level"]
[ext_resource type="PackedScene" path="res://levels/checkpoint.tscn" id="2_checkpoint"]
[ext_resource type="Material" path="res://materials/grid_ground.tres" id="3_ground"]
[ext_resource type="Material" path="res://materials/grid_platform.tres" id="4_platform"]
[ext_resource type="Material" path="res://materials/grid_wall.tres" id="5_wall"]
[ext_resource type="Material" path="res://materials/grid_goal.tres" id="6_goal"]
[ext_resource type="PackedScene" path="res://levels/relic.tscn" id="10_relic"]
[ext_resource type="PackedScene" path="res://levels/race_gate.tscn" id="11_gate"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]
sky_top_color = Color(0.32, 0.5, 0.78, 1)
sky_horizon_color = Color(0.7, 0.76, 0.84, 1)
ground_bottom_color = Color(0.45, 0.55, 0.7, 1)
ground_horizon_color = Color(0.7, 0.76, 0.84, 1)

[sub_resource type="Sky" id="Sky_main"]
sky_material = SubResource("ProceduralSkyMaterial_sky")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 2
sky = SubResource("Sky_main")
ambient_light_source = 3
tonemap_mode = 2
ssao_enabled = true
fog_enabled = true
fog_light_color = Color(0.7, 0.76, 0.84, 1)
fog_density = 0.0008

[node name="FreeRunLine" type="Node3D"]
script = ExtResource("1_level")
kill_height = -60.0

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.383, 0.3214, 0, 0.6428, 0.766, -0.5, -0.6634, 0.5567, 0, 60, -250)
shadow_enabled = true
directional_shadow_max_distance = 200.0

[node name="SpawnPoint" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.05, 0)

[node name="Course" type="Node3D" parent="."]

[node name="Labels" type="Node3D" parent="."]

[node name="Checkpoints" type="Node3D" parent="."]

[node name="Relics" type="Node3D" parent="."]

[node name="Gates" type="Node3D" parent="."]
EOF

# --- 0. Runway: build up your flow. The timer starts at the gate. ---
floor Runway 5 -45 0
gate StartGate 0 -6 0
label LabelStart 0 5 -10 "FREE-RUN LINE\\nhold Shift and steer with the camera"

# --- 1. Hurdles (1, 1.5 and 2.5 m): free-run jumps them ---
floor HurdleLane -45 -100 0
block Hurdle1 -58 1 0 1.0 8 0 5_wall
block Hurdle2 -72 1 0 1.5 8 0 5_wall
block Hurdle3 -86 1 0 2.5 8 0 5_wall
label LabelHurdles 0 6 -50 "HURDLES"
# Off the line: a pillar 5 m beyond the lane edge with a relic on top (manual jump + grab).
block RelicPillar -72 3 -40 5 3 10.5
relic RelicPillarTop 10.5 6.6 -72

# --- 2. Low bars (1.2 m clearance): free-run slides under them ---
floor BarLane -100 -140 0
block Bar1 -110 0.6 1.2 1.6 8 0 5_wall
block Bar2 -118 0.6 1.2 1.6 8 0 5_wall
block Bar3 -126 0.6 1.2 1.6 8 0 5_wall
label LabelBars 0 5 -104 "SLIDE UNDER"
checkpoint Checkpoint1 0 0 -136

# --- 3. Gaps of 4, 7 and 10 m (the 10 m one needs full flow) ---
floor GapPlatform1 -144 -160 0
floor GapPlatform2 -167 -183 0
floor GapPlatform3 -193 -230 0
label LabelGaps 0 5 -141 "GAPS: 4 m, 7 m, 10 m\\n(the last one needs full flow)"
relic RelicOverGap 0 2.5 -163.5
checkpoint Checkpoint2 0 0 -197

# --- 4. A 22 m gap with a tall wall alongside: wall-run it ---
floor WallRunLanding -252 -280 0
box WallRunWall Course 4.5 -4 -240 1 32 36 5_wall
label LabelWallRun 0 5 -224 "WALL-RUN GAP"
checkpoint Checkpoint3 0 0 -260

# --- 5. Run off the edge and drop to the street 12 m below ---
floor Street -272 -335 -12
label LabelDrop 0 4 -276 "DROP TO THE STREET"
checkpoint Checkpoint4 0 -12 -292
# Off the line: a raised nook beside the street with a relic.
block StreetNook -303 6 -12 -9 6 -9
relic RelicStreetNook -9 -7.4 -303

# --- 6. Step back up to rooftop height: 4 m steps ---
block Step1 -314 8 -12 -8
block Step2 -322 8 -12 -4
block Step3 -330 8 -12 0
floor Roof2 -334 -372 0
label LabelSteps 0 -5 -306 "STEP UP"

# --- 7. A 5 m wall head-on: free-run grabs it and pulls up ---
block ClimbWall -350 8 0 5
relic RelicClimbWall 0 6.6 -350
label LabelClimb 0 9 -342 "CLIMB"
checkpoint Checkpoint5 0 0 -364

# --- 8. Slide down the slope (hold C), then a 14 m gap ---
# A 52 m ramp from z = -372 (top 0) down to z = -422 (top -15), about 17 degrees.
printf '\n[node name="SlideSlope" type="CSGBox3D" parent="Course"]\ntransform = Transform3D(1, 0, 0, 0, 0.957826, 0.287348, 0, -0.287348, 0.957826, 0, -7.7874, -396.914)\nuse_collision = true\nsize = Vector3(8, 0.6, 52.2015)\nmaterial = ExtResource("4_platform")\n'
floor SlopeRunOut -422 -432 -15
floor SlopeLanding -446 -515 -15
label LabelSlope 0 5 -375 "SLIDE DOWN (hold C)\\nthen a 14 m gap"
checkpoint Checkpoint6 0 -15 -452

# --- 9. A 12 m wall head-on: too tall for free-run, climb it by hand ---
block TallWall -480 6 -15 -3 8 0 5_wall
# Ledge blocks on its south face (x = -4..4, face at z = -477), zig-zagging up.
block TallWallLedge1 -476 2 -13 -10 2 -3
block TallWallLedge2 -476 2 -8 -5 2 -0.5
relic RelicTallWall 0 -1.4 -480
label LabelTallWall 0 1 -470 "TOO TALL FOR FREE-RUN:\\nclimb it yourself"

# --- 10. Finish ---
gate FinishGate -15 -505 1
block FinishLine -507 2 -15 -14.9 8 0 6_goal
label LabelFinish 0 -8 -505 "FINISH"
