# 🐍 Snake Game - Terminal Edition

A classic snake game implemented entirely in bash, rendered in your terminal using `tput` for drawing.

## Features

- 🎮 Classic snake gameplay with smooth controls
- 📺 Adaptive terminal rendering with tput
- ⚡ Configurable game speed (fast/normal/slow)
- 📐 Customizable board size
- 🏆 Score tracking and snake length display
- 🔄 Restart or quit after game over
- 🎯 Win condition when snake fills the entire board

## Requirements

- Bash 4.0+
- Terminal with Unicode support (for emoji display)
- `tput` command (part of ncurses)

## Usage

```bash
# Start with default settings
./snake.sh

# Fast-paced game
./snake.sh --speed fast

# Custom board size (60x30)
./snake.sh --size 60x30

# Slow speed with smaller board
./snake.sh -s slow -S 30x20

# Show help
./snake.sh --help
```

## Controls

| Key | Action |
|-----|--------|
| `W` / `↑` | Move Up |
| `S` / `↓` | Move Down |
| `A` / `←` | Move Left |
| `D` / `→` | Move Right |
| `R` | Restart (after game over) |
| `Q` | Quit (after game over) |

## Command-Line Options

```
OPTIONS:
  -s, --speed <speed>    Game speed: fast, normal, slow (default: normal)
  -S, --size <WxH>       Board size in WxH format (default: 40x20)
  -h, --help             Show this help message and exit
  -v, --version          Show version information and exit
```

### Speed Settings

| Speed | Delay | Description |
|-------|-------|-------------|
| `fast` | 50ms | Quick, challenging gameplay |
| `normal` | 100ms | Balanced speed (default) |
| `slow` | 200ms | Relaxed, easier to control |

### Size Constraints

- Minimum: 10x10
- Maximum: 100x50
- Format: `WIDTHxHEIGHT` (e.g., `40x20`, `60x30`)

## Game Rules

1. **Eat food** (🍎) to grow and earn points (+10 per food)
2. **Avoid walls** - hitting the border ends the game
3. **Avoid yourself** - colliding with your own tail is game over
4. **Win** by filling the entire board with your snake

## Display

- 🟢 = Snake head
- 🟩 = Snake body
- 🍎 = Food

## License

MIT License - Feel free to modify and distribute.
