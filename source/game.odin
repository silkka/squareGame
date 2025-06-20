/*
	Cool Game
*/

package game

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180

Game_Scene :: enum {
	START_SCREEN,
	PLAYING,
}

Target :: struct {
	pos:    rl.Vector2,
	size:   rl.Vector2,
	active: bool,
	enemy:  bool,
}

Game_Memory :: struct {
	player:  Target,
	targets: [16]Target,
	score:   int,
	run:     bool,
	scene:   Game_Scene,
}

g: ^Game_Memory

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	g^ = Game_Memory {
		run = true,
		targets = {},
		player = Target{pos = rl.Vector2{0, 0}, size = rl.Vector2{10, 10}, active = true},
		score = 0,
		scene = .START_SCREEN,
	}
}


game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {zoom = h / PIXEL_WINDOW_HEIGHT, target = {}, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

spawn_target :: proc() {
	create_target_at_random_position :: proc(enemy: bool) -> Target {
		size := rand.float32_range(5, 20)
		w := f32(rl.GetScreenWidth())
		h := f32(rl.GetScreenHeight())
		camera := game_camera()
		padding := size * camera.zoom
		posScreen := rl.Vector2 {
			rand.float32_range(padding, w - padding * 2),
			rand.float32_range(padding, h - padding * 2),
		}
		pos := rl.GetScreenToWorld2D(posScreen, camera)

		return Target{pos = pos, size = rl.Vector2{size, size}, active = true, enemy = enemy}
	}

	find_and_create_target :: proc(enemy: bool) -> bool {
		for &target in g.targets {
			if !target.active {
				target = create_target_at_random_position(enemy)
				return true
			}
		}
		return false
	}

	enemy := rand.float32() > 0.7


	if find_and_create_target(enemy) {
		// If enemy is created, also create a non-enemy
		if enemy {
			find_and_create_target(false)
		}
		return
	}

	assert(false, "No inactive target slot found, increase target count!!!")
}

update :: proc() {
	if g.scene == .START_SCREEN {
		if rl.IsKeyPressed(.SPACE) {
			g.scene = .PLAYING
			g.score = 0
			g.player.size = rl.Vector2{10, 10}
			g.player.pos = rl.Vector2{0, 0}
			for &target in g.targets {
				target.active = false
			}
			spawn_target()
		}
		return
	}

	input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	input = linalg.normalize0(input)
	g.player.pos += input * rl.GetFrameTime() * 100

	for &target in g.targets {
		if (!target.active) {
			continue
		}
		player_rect := rl.Rectangle {
			x      = g.player.pos.x,
			y      = g.player.pos.y,
			height = g.player.size.x,
			width  = g.player.size.y,
		}

		target_rect := rl.Rectangle {
			x      = target.pos.x,
			y      = target.pos.y,
			height = target.size.x,
			width  = target.size.y,
		}

		if (rl.CheckCollisionRecs(player_rect, target_rect)) {
			if target.enemy {
				// Enemy hit - restart the game
				g.scene = .START_SCREEN
				return
			}

			g.score += 1
			if (g.score % 5 == 0) {
				g.player.size += 1
			}
			target.active = false
			spawn_target()
		}
	}

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	if g.scene == .START_SCREEN {
		// Draw start screen
		rl.BeginMode2D(ui_camera())

		// Title
		rl.DrawText("COLLECT SQUARES", 10, 10, 20, rl.WHITE)

		// Show final score if there was one
		if g.score > 0 {
			rl.DrawText(fmt.ctprintf("Final Score: %v", i32(g.score)), 10, 30, 16, rl.YELLOW)
			rl.DrawText("Press SPACE to restart", 10, 50, 10, rl.GRAY)
		} else {
			rl.DrawText("Press SPACE to start", 10, 30, 10, rl.GRAY)
			rl.DrawText("Collect green squares, avoid red enemies", 10, 50, 10, rl.GRAY)
			rl.DrawText("Use WASD or arrow keys to move", 10, 70, 10, rl.GRAY)
			rl.DrawText("Press ESC to exit", 10, 90, 10, rl.WHITE)
		}

		// Instructions

		rl.EndMode2D()
	} else {
		// Draw normal game
		rl.BeginMode2D(game_camera())
		rl.DrawRectangle(
			i32(g.player.pos.x),
			i32(g.player.pos.y),
			i32(g.player.size.x),
			i32(g.player.size.y),
			rl.BLUE,
		)

		for t in g.targets {
			if (!t.active) {
				continue
			}
			rl.DrawRectangle(
				i32(t.pos.x),
				i32(t.pos.y),
				i32(t.size.x),
				i32(t.size.y),
				t.enemy ? rl.RED : rl.GREEN,
			)
		}

		rl.EndMode2D()

		rl.BeginMode2D(ui_camera())

		rl.DrawText(fmt.ctprintf("Score: %v", i32(g.score)), 5, 5, 8, rl.WHITE)

		rl.EndMode2D()
	}

	rl.EndDrawing()
}

// ######################### HOT RELOAD STUFF #########################

@(export)
game_update :: proc() {
	update()
	draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Collect squares")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(144)
	rl.SetExitKey(nil)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
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
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.R) && (rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.LEFT_CONTROL))
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
