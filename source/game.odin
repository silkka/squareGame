/*
	Collect Squares - A simple arcade game
	Collect green squares while avoiding red enemies
*/

package game

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

// Game constants
PIXEL_WINDOW_HEIGHT :: 180
PLAYER_SPEED :: 100.0
PLAYER_START_SIZE :: 10.0
TARGET_MIN_SIZE :: 5.0
TARGET_MAX_SIZE :: 20.0
ENEMY_SPAWN_CHANCE :: 0.3
SCORE_PER_TARGET :: 1
SIZE_INCREASE_INTERVAL :: 5
SIZE_INCREASE_AMOUNT :: 1.0
MAX_TARGETS :: 16

// Game states
Game_Scene :: enum {
	START_SCREEN,
	PLAYING,
	GAME_OVER,
}

// Game entities
Entity :: struct {
	pos:    rl.Vector2,
	size:   rl.Vector2,
	active: bool,
}

Target :: struct {
	using entity: Entity,
	enemy:        bool,
}

Player :: struct {
	using entity: Entity,
	score:        int,
}

// Input system
Input_State :: struct {
	movement:       rl.Vector2,
	space_pressed:  bool,
	escape_pressed: bool,
}

// Camera system
Camera_System :: struct {
	game_camera: rl.Camera2D,
	ui_camera:   rl.Camera2D,
}

// Game state
Game_State :: struct {
	player:         Player,
	targets:        [MAX_TARGETS]Target,
	input:          Input_State,
	camera:         Camera_System,
	scene:          Game_Scene,
	should_run:     bool,
	spawn_timer:    f32,
	spawn_interval: f32,
}

// Global game state (for hot reload compatibility)
g: ^Game_State

// =============================================================================
// INITIALIZATION
// =============================================================================

@(export)
game_init :: proc() {
	g = new(Game_State)
	init_game_state(g)
}

init_game_state :: proc(state: ^Game_State) {
	state^ = Game_State {
		should_run     = true,
		scene          = .START_SCREEN,
		spawn_interval = 2.0, // Spawn new target every 2 seconds
	}

	init_player(&state.player)
	init_targets(&state.targets)
	init_cameras(&state.camera)
}

init_player :: proc(player: ^Player) {
	player^ = Player {
		entity = Entity {
			pos = {0, 0},
			size = {PLAYER_START_SIZE, PLAYER_START_SIZE},
			active = true,
		},
		score = 0,
	}
}

init_targets :: proc(targets: ^[MAX_TARGETS]Target) {
	for i in 0 ..< MAX_TARGETS {
		targets[i] = Target {
			entity = Entity{active = false},
			enemy = false,
		}
	}
}

init_cameras :: proc(camera: ^Camera_System) {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	camera.game_camera = rl.Camera2D {
		zoom   = h / PIXEL_WINDOW_HEIGHT,
		target = {},
		offset = {w / 2, h / 2},
	}

	camera.ui_camera = rl.Camera2D {
		zoom = h / PIXEL_WINDOW_HEIGHT,
	}
}

// =============================================================================
// INPUT SYSTEM
// =============================================================================

update_input :: proc(input: ^Input_State) {
	// Reset input state
	input^ = Input_State{}

	// Movement input
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.movement.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.movement.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.movement.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.movement.x += 1
	}

	// Normalize movement vector
	if linalg.length(input.movement) > 0 {
		input.movement = linalg.normalize(input.movement)
	}

	// Action inputs
	input.space_pressed = rl.IsKeyPressed(.SPACE)
	input.escape_pressed = rl.IsKeyPressed(.ESCAPE)
}

// =============================================================================
// TARGET SYSTEM
// =============================================================================

spawn_target :: proc(targets: ^[MAX_TARGETS]Target, camera: ^Camera_System) -> bool {
	// Find inactive target slot
	for i in 0 ..< MAX_TARGETS {
		if !targets[i].active {
			targets[i] = create_target_at_random_position(camera)
			return true
		}
	}
	return false
}

create_target_at_random_position :: proc(camera: ^Camera_System) -> Target {
	size := rand.float32_range(TARGET_MIN_SIZE, TARGET_MAX_SIZE)
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	// Calculate safe spawn area
	padding := size * camera.game_camera.zoom
	pos_screen := rl.Vector2 {
		rand.float32_range(padding, w - padding * 2),
		rand.float32_range(padding, h - padding * 2),
	}

	// Convert screen position to world position
	pos := rl.GetScreenToWorld2D(pos_screen, camera.game_camera)

	// Determine if this is an enemy
	is_enemy := rand.float32() < ENEMY_SPAWN_CHANCE

	return Target{entity = Entity{pos = pos, size = {size, size}, active = true}, enemy = is_enemy}
}

update_targets :: proc(targets: ^[MAX_TARGETS]Target, camera: ^Camera_System, delta_time: f32) {
	// Spawn timer logic could go here for automatic spawning
	// For now, targets are spawned when collected
}

// =============================================================================
// COLLISION SYSTEM
// =============================================================================

check_collision :: proc(a, b: Entity) -> bool {
	a_rect := rl.Rectangle {
		x      = a.pos.x,
		y      = a.pos.y,
		width  = a.size.x, // Fixed: was using height
		height = a.size.y, // Fixed: was using width
	}

	b_rect := rl.Rectangle {
		x      = b.pos.x,
		y      = b.pos.y,
		width  = b.size.x,
		height = b.size.y,
	}

	return rl.CheckCollisionRecs(a_rect, b_rect)
}

// =============================================================================
// GAME LOGIC
// =============================================================================

update_player :: proc(player: ^Player, input: Input_State, delta_time: f32) {
	// Update position based on input
	player.pos += input.movement * delta_time * PLAYER_SPEED

	// Keep player within bounds (optional)
	// clamp_player_position(player)
}

update_gameplay :: proc(state: ^Game_State, delta_time: f32) {
	// Update player
	update_player(&state.player, state.input, delta_time)

	// Check collisions with targets
	for i in 0 ..< MAX_TARGETS {
		target := &state.targets[i]
		if !target.active do continue

		if check_collision(state.player.entity, target.entity) {
			handle_target_collision(state, target)
		}
	}
}

handle_target_collision :: proc(state: ^Game_State, target: ^Target) {
	if target.enemy {
		// Enemy hit - game over
		state.scene = .GAME_OVER
		return
	}

	// Collect target
	state.player.score += SCORE_PER_TARGET
	target.active = false

	// Increase player size every few targets
	if state.player.score % SIZE_INCREASE_INTERVAL == 0 {
		state.player.size += SIZE_INCREASE_AMOUNT
	}

	// Spawn new target
	spawn_target(&state.targets, &state.camera)
}

reset_game :: proc(state: ^Game_State) {
	init_player(&state.player)
	init_targets(&state.targets)
	state.scene = .PLAYING
	spawn_target(&state.targets, &state.camera)
}

// =============================================================================
// RENDERING SYSTEM
// =============================================================================

draw_entity :: proc(entity: Entity, color: rl.Color) {
	rl.DrawRectangle(
		i32(entity.pos.x),
		i32(entity.pos.y),
		i32(entity.size.x),
		i32(entity.size.y),
		color,
	)
}

draw_targets :: proc(targets: ^[MAX_TARGETS]Target) {
	for i in 0 ..< MAX_TARGETS {
		target := targets[i]
		if !target.active do continue

		color := target.enemy ? rl.RED : rl.GREEN
		draw_entity(target.entity, color)
	}
}

draw_ui :: proc(state: ^Game_State) {
	rl.BeginMode2D(state.camera.ui_camera)

	switch state.scene {
	case .START_SCREEN:
		draw_start_screen(state)
	case .PLAYING:
		draw_game_ui(state)
	case .GAME_OVER:
		draw_game_over_screen(state)
	}

	rl.EndMode2D()
}

draw_start_screen :: proc(state: ^Game_State) {
	// Title
	rl.DrawText("COLLECT SQUARES", 10, 10, 20, rl.WHITE)

	if state.player.score > 0 {
		rl.DrawText(
			fmt.ctprintf("Final Score: %v", i32(state.player.score)),
			10,
			30,
			16,
			rl.YELLOW,
		)
		rl.DrawText("Press SPACE to restart", 10, 50, 10, rl.GRAY)
	} else {
		rl.DrawText("Press SPACE to start", 10, 30, 10, rl.GRAY)
		rl.DrawText("Collect green squares, avoid red enemies", 10, 50, 10, rl.GRAY)
		rl.DrawText("Use WASD or arrow keys to move", 10, 70, 10, rl.GRAY)
		rl.DrawText("Press ESC to exit", 10, 90, 10, rl.WHITE)
	}
}

draw_game_ui :: proc(state: ^Game_State) {
	rl.DrawText(fmt.ctprintf("Score: %v", i32(state.player.score)), 5, 5, 8, rl.WHITE)
}

draw_game_over_screen :: proc(state: ^Game_State) {
	rl.DrawText("GAME OVER", 10, 10, 20, rl.RED)
	rl.DrawText(fmt.ctprintf("Final Score: %v", i32(state.player.score)), 10, 30, 16, rl.YELLOW)
	rl.DrawText("Press SPACE to restart", 10, 50, 10, rl.GRAY)
	rl.DrawText("Press ESC to exit", 10, 70, 10, rl.WHITE)
}

// =============================================================================
// MAIN UPDATE LOOP
// =============================================================================

update :: proc(state: ^Game_State) {
	delta_time := rl.GetFrameTime()

	// Update input
	update_input(&state.input)

	// Handle scene-specific logic
	switch state.scene {
	case .START_SCREEN:
		if state.input.space_pressed {
			reset_game(state)
		}
	case .PLAYING:
		update_gameplay(state, delta_time)
	case .GAME_OVER:
		if state.input.space_pressed {
			reset_game(state)
		}
	}

	// Global input handling
	if state.input.escape_pressed {
		state.should_run = false
	}
}

draw :: proc(state: ^Game_State) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	if state.scene == .PLAYING {
		// Draw game world
		rl.BeginMode2D(state.camera.game_camera)
		draw_entity(state.player.entity, rl.BLUE)
		draw_targets(&state.targets)
		rl.EndMode2D()
	}

	// Draw UI
	draw_ui(state)

	rl.EndDrawing()
}

// =============================================================================
// HOT RELOAD INTERFACE
// =============================================================================

@(export)
game_update :: proc() {
	update(g)
	draw(g)

	// Clean up temporary allocations
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Collect Squares")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(144)
	rl.SetExitKey(nil)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		if rl.WindowShouldClose() {
			return false
		}
	}
	return g.should_run
}

@(export)
game_shutdown :: proc() {
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_State)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_State)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.R) && (rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.LEFT_CONTROL))
}

@(export)
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
	// Update camera when window resizes
	if g != nil {
		init_cameras(&g.camera)
	}
}
