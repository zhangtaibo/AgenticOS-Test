# 🐍 Terminal Snake Game

A classic snake game implemented in pure Bash for your terminal!

## Features

- 🎮 Classic snake gameplay with smooth controls
- 🎨 Colorful terminal graphics using tput
- ⚡ Adjustable game speed (fast/normal/slow)
- 📐 Customizable game board size
- 🏆 Score tracking and snake length display
- 🔄 Restart capability after game over

## Requirements

- Bash 4.0+
- Unix-like system with tput and stty commands
- Terminal with minimum 44x26 characters (for default size)

## Quick Start

```bash
# Make the script executable
chmod +x snake.sh

# Run with default settings
./snake.sh
```

## Controls

| Key | Action |
|-----|--------|
| `W` / `↑` | Move Up |
| `S` / `↓` | Move Down |
| `A` / `←` | Move Left |
| `D` / `→` | Move Right |
| `R` | Restart (after game over) |
| `Q` | Quit game |

## Command Line Options

```bash
./snake.sh --help

Options:
  --speed <fast|normal|slow>  Set game speed (default: normal)
  --size <WxH>                Set game size, e.g., 40x20 (default: 40x20)
  -h, --help                  Show help message
```

## Examples

```bash
# Play with fast speed
./snake.sh --speed fast

# Play on a larger board
./snake.sh --size 60x30

# Combine options
./snake.sh --speed slow --size 30x20
```

## Game Rules

1. Control the snake (shown as `@` for head, `o` for body) to eat food (`*`)
2. Each food eaten increases your score by 10 points and grows the snake
3. Game ends if the snake hits the wall or its own body
4. Try to achieve the highest score possible!

## License

MIT License
