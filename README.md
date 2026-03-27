# 🐍 Snake Game - Terminal Edition

A classic snake game implemented in pure Bash for your terminal!

## 🎮 How to Play

- **Move**: Use `WASD` keys or Arrow keys
- **Goal**: Eat the red food (●●) to grow longer and score points
- **Avoid**: Don't hit the walls or your own tail!
- **Quit**: Press `Q` to quit
- **Restart**: Press `R` after Game Over

## 🚀 Quick Start

```bash
# Make executable (if needed)
chmod +x snake.sh

# Run with defaults
./snake.sh

# Fast-paced game
./snake.sh --speed fast

# Custom board size
./snake.sh --size 60x25

# Combine options
./snake.sh --speed slow --size 50x30
```

## 📋 Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--speed fast` | Fast game (50ms delay) | normal |
| `--speed normal` | Normal game (100ms delay) | normal |
| `--speed slow` | Slow game (200ms delay) | normal |
| `--size WxH` | Board size (e.g., 60x25) | 40x20 |
| `--help` | Show help message | - |

## 🎯 Features

- ✅ Adaptive terminal rendering with `tput`
- ✅ Smooth keyboard input with arrow key support
- ✅ Collision detection (walls and self)
- ✅ Score tracking and snake length display
- ✅ Restart functionality after Game Over
- ✅ Clean terminal restoration on exit
- ✅ Comprehensive input validation

## 🛠️ Requirements

- Bash 4.0+
- Standard Unix utilities: `tput`, `stty`, `sleep`
- Terminal with color support (recommended)

## 📝 Controls

| Key | Action |
|-----|--------|
| `W` / `↑` | Move Up |
| `S` / `↓` | Move Down |
| `A` / `←` | Move Left |
| `D` / `→` | Move Right |
| `Q` | Quit Game |
| `R` | Restart (after Game Over) |

---

**Enjoy the game!** 🎉
