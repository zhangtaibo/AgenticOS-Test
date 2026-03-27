#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Snake - A Terminal Snake Game
# =============================================================================
# Classic snake game rendered in the terminal using tput for drawing.
# Control the snake with WASD or arrow keys, eat food to grow, avoid walls
# and yourself. Supports custom speed and board size.
# =============================================================================

# --- Constants ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# Default game settings
DEFAULT_WIDTH=40
DEFAULT_HEIGHT=20
DEFAULT_SPEED="normal"

# Direction constants
readonly DIR_UP="up"
readonly DIR_DOWN="down"
readonly DIR_LEFT="left"
readonly DIR_RIGHT="right"

# Game state (global variables)
declare -a SNAKE_X=()
declare -a SNAKE_Y=()
declare -i FOOD_X=0
declare -i FOOD_Y=0
declare -i DIRECTION="$DIR_RIGHT"
declare -i NEXT_DIRECTION="$DIR_RIGHT"
declare -i SCORE=0
declare -i GAME_OVER=0
declare -i BOARD_WIDTH="$DEFAULT_WIDTH"
declare -i BOARD_HEIGHT="$DEFAULT_HEIGHT"
declare -i SPEED_MS=100

# Terminal state
declare -i TERM_WIDTH=0
declare -i TERM_HEIGHT=0

# --- Cleanup & Signal Handling ---

# cleanup: Restore terminal settings on exit
cleanup() {
  local exit_code=$?
  # Restore terminal: show cursor, disable raw mode
  tput cnorm 2>/dev/null || true
  tput rmcup 2>/dev/null || true
  stty sane 2>/dev/null || true
  if [[ $exit_code -ne 0 && $exit_code -ne 130 ]]; then
    echo -e "\n${SCRIPT_NAME} exited with code $exit_code" >&2
  fi
}
trap cleanup EXIT INT TERM

# --- Usage & Help ---

# usage: Display usage information and exit
usage() {
  local exit_code="${1:-0}"
  cat >&2 <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

A classic snake game for the terminal.

OPTIONS:
  -s, --speed <speed>    Game speed: fast, normal, slow (default: normal)
  -S, --size <WxH>       Board size in WxH format (default: ${DEFAULT_WIDTH}x${DEFAULT_HEIGHT})
  -h, --help             Show this help message and exit
  -v, --version          Show version information and exit

CONTROLS:
  W, ↑  - Move up
  S, ↓  - Move down
  A, ←  - Move left
  D, →  - Move right
  R     - Restart (after game over)
  Q     - Quit (after game over)

EXAMPLES:
  $SCRIPT_NAME                    # Start with defaults
  $SCRIPT_NAME --speed fast       # Fast-paced game
  $SCRIPT_NAME --size 60x30       # Larger board
  $SCRIPT_NAME -s slow -S 30x20   # Slow speed, smaller board

EOF
  exit "$exit_code"
}

# show_version: Display version information
show_version() {
  echo "$SCRIPT_NAME version $VERSION"
  exit 0
}

# --- Argument Parsing ---

# parse_arguments: Parse command-line arguments
parse_arguments() {
  local speed_arg=""
  local size_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--speed)
        if [[ -z "${2:-}" ]]; then
          echo "ERROR: --speed requires a value (fast/normal/slow)" >&2
          exit 1
        fi
        speed_arg="$2"
        shift 2
        ;;
      -S|--size)
        if [[ -z "${2:-}" ]]; then
          echo "ERROR: --size requires a value (WxH format)" >&2
          exit 1
        fi
        size_arg="$2"
        shift 2
        ;;
      -h|--help)
        usage 0
        ;;
      -v|--version)
        show_version
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "ERROR: unknown option '$1'" >&2
        usage 1
        ;;
      *)
        break
        ;;
    esac
  done

  # Validate and apply speed setting
  if [[ -n "$speed_arg" ]]; then
    case "$speed_arg" in
      fast)
        SPEED_MS=50
        ;;
      normal)
        SPEED_MS=100
        ;;
      slow)
        SPEED_MS=200
        ;;
      *)
        echo "ERROR: invalid speed '$speed_arg'. Must be: fast, normal, slow" >&2
        exit 1
        ;;
    esac
  fi

  # Validate and apply size setting
  if [[ -n "$size_arg" ]]; then
    if [[ ! "$size_arg" =~ ^([0-9]+)x([0-9]+)$ ]]; then
      echo "ERROR: invalid size '$size_arg'. Must be in WxH format (e.g., 40x20)" >&2
      exit 1
    fi
    BOARD_WIDTH="${BASH_REMATCH[1]}"
    BOARD_HEIGHT="${BASH_REMATCH[2]}"
    
    if [[ $BOARD_WIDTH -lt 10 || $BOARD_HEIGHT -lt 10 ]]; then
      echo "ERROR: board size must be at least 10x10" >&2
      exit 1
    fi
    if [[ $BOARD_WIDTH -gt 100 || $BOARD_HEIGHT -gt 50 ]]; then
      echo "ERROR: board size must be at most 100x50" >&2
      exit 1
    fi
  fi
}

# --- Terminal Setup ---

# setup_terminal: Configure terminal for game display
setup_terminal() {
  # Get terminal dimensions
  TERM_WIDTH="$(tput cols)"
  TERM_HEIGHT="$(tput lines)"
  
  # Check if terminal is large enough
  local required_width=$((BOARD_WIDTH + 4))
  local required_height=$((BOARD_HEIGHT + 4))
  
  if [[ $TERM_WIDTH -lt $required_width || $TERM_HEIGHT -lt $required_height ]]; then
    echo "ERROR: Terminal too small. Need at least ${required_width}x${required_height}, have ${TERM_WIDTH}x${TERM_HEIGHT}" >&2
    exit 1
  fi
  
  # Hide cursor and enable alternate screen buffer
  tput civis
  tput smcup
  
  # Disable line wrapping and echo
  stty -echo -icanon min 0 time 0
}

# --- Game Logic ---

# init_game: Initialize game state
init_game() {
  # Reset score and game state
  SCORE=0
  GAME_OVER=0
  DIRECTION="$DIR_RIGHT"
  NEXT_DIRECTION="$DIR_RIGHT"
  
  # Initialize snake in the middle of the board, length 3
  local start_x=$((BOARD_WIDTH / 2))
  local start_y=$((BOARD_HEIGHT / 2))
  
  SNAKE_X=($start_x $((start_x - 1)) $((start_x - 2)))
  SNAKE_Y=($start_y $start_y $start_y)
  
  # Spawn initial food
  spawn_food
}

# spawn_food: Place food at a random position not occupied by snake
spawn_food() {
  local valid=0
  local attempts=0
  local max_attempts=$((BOARD_WIDTH * BOARD_HEIGHT))
  
  while [[ $valid -eq 0 && $attempts -lt $max_attempts ]]; do
    FOOD_X=$(( (RANDOM % (BOARD_WIDTH - 2)) + 2 ))
    FOOD_Y=$(( (RANDOM % (BOARD_HEIGHT - 2)) + 2 ))
    
    # Check if food position overlaps with snake
    valid=1
    for i in "${!SNAKE_X[@]}"; do
      if [[ ${SNAKE_X[$i]} -eq $FOOD_X && ${SNAKE_Y[$i]} -eq $FOOD_Y ]]; then
        valid=0
        break
      fi
    done
    
    ((attempts++))
  done
  
  if [[ $valid -eq 0 ]]; then
    # Snake fills entire board - player wins!
    GAME_OVER=2  # Special win state
  fi
}

# handle_input: Read and process player input
handle_input() {
  local key=""
  
  # Read a single character with timeout
  if read -rsn1 -t 0.01 key 2>/dev/null; then
    # Handle escape sequences for arrow keys
    if [[ "$key" == $'\x1b' ]]; then
      read -rsn2 -t 0.01 key 2>/dev/null || true
      case "$key" in
        "[A") key="w" ;;  # Up arrow
        "[B") key="s" ;;  # Down arrow
        "[C") key="d" ;;  # Right arrow
        "[D") key="a" ;;  # Left arrow
      esac
    fi
    
    # Convert to lowercase
    key="${key,,}"
    
    # Process direction changes (prevent 180-degree turns)
    case "$key" in
      w|up)
        if [[ "$DIRECTION" != "$DIR_DOWN" ]]; then
          NEXT_DIRECTION="$DIR_UP"
        fi
        ;;
      s|down)
        if [[ "$DIRECTION" != "$DIR_UP" ]]; then
          NEXT_DIRECTION="$DIR_DOWN"
        fi
        ;;
      a|left)
        if [[ "$DIRECTION" != "$DIR_RIGHT" ]]; then
          NEXT_DIRECTION="$DIR_LEFT"
        fi
        ;;
      d|right)
        if [[ "$DIRECTION" != "$DIR_LEFT" ]]; then
          NEXT_DIRECTION="$DIR_RIGHT"
        fi
        ;;
    esac
  fi
}

# move_snake: Update snake position based on current direction
move_snake() {
  # Apply the queued direction change
  DIRECTION="$NEXT_DIRECTION"
  
  # Calculate new head position
  local head_x="${SNAKE_X[0]}"
  local head_y="${SNAKE_Y[0]}"
  local new_x="$head_x"
  local new_y="$head_y"
  
  case "$DIRECTION" in
    "$DIR_UP")    ((new_y--)) ;;
    "$DIR_DOWN")  ((new_y++)) ;;
    "$DIR_LEFT")  ((new_x--)) ;;
    "$DIR_RIGHT") ((new_x++)) ;;
  esac
  
  # Check for food collision before moving
  local ate_food=0
  if [[ $new_x -eq $FOOD_X && $new_y -eq $FOOD_Y ]]; then
    ate_food=1
    ((SCORE += 10))
  fi
  
  # Move snake body (shift positions)
  local snake_len="${#SNAKE_X[@]}"
  
  if [[ $ate_food -eq 1 ]]; then
    # Grow: add new head, keep tail
    SNAKE_X=("$new_x" "${SNAKE_X[@]}")
    SNAKE_Y=("$new_y" "${SNAKE_Y[@]}")
    spawn_food
  else
    # Move: add new head, remove tail
    SNAKE_X=("$new_x" "${SNAKE_X[@]:0:$((snake_len - 1))}")
    SNAKE_Y=("$new_y" "${SNAKE_Y[@]:0:$((snake_len - 1))}")
  fi
}

# check_collision: Check if snake collided with wall or itself
check_collision() {
  local head_x="${SNAKE_X[0]}"
  local head_y="${SNAKE_Y[0]}"
  
  # Check wall collision (playing field is 2 to WIDTH+1, 2 to HEIGHT+1)
  if [[ $head_x -lt 2 || $head_x -gt $((BOARD_WIDTH + 1)) ]]; then
    GAME_OVER=1
    return
  fi
  if [[ $head_y -lt 2 || $head_y -gt $((BOARD_HEIGHT + 1)) ]]; then
    GAME_OVER=1
    return
  fi
  
  # Check self collision (skip head at index 0)
  for ((i = 1; i < ${#SNAKE_X[@]}; i++)); do
    if [[ ${SNAKE_X[$i]} -eq $head_x && ${SNAKE_Y[$i]} -eq $head_y ]]; then
      GAME_OVER=1
      return
    fi
  done
}

# --- Drawing Functions ---

# draw_board: Render the game board
draw_board() {
  # Clear screen and move to top-left
  tput clear
  tput cup 0 0
  
  # Calculate centering offset
  local offset_x=$(( (TERM_WIDTH - BOARD_WIDTH - 4) / 2 ))
  local offset_y=$(( (TERM_HEIGHT - BOARD_HEIGHT - 4) / 2 ))
  
  # Draw title and score
  tput cup "$offset_y" "$offset_x"
  tput bold
  echo "🐍 SNAKE GAME 🐍"
  tput sgr0
  
  tput cup "$((offset_y + 1))" "$offset_x"
  echo "Score: $SCORE | Length: ${#SNAKE_X[@]} | Speed: ${SPEED_MS}ms"
  
  # Draw top border
  tput cup "$((offset_y + 2))" "$offset_x"
  echo "┌$(printf '─%.0s' $(seq 1 $((BOARD_WIDTH + 2))))┐"
  
  # Draw playing field
  for ((y = 0; y <= BOARD_HEIGHT + 1; y++)); do
    tput cup "$((offset_y + 3 + y))" "$offset_x"
    
    if [[ $y -eq 0 || $y -eq $((BOARD_HEIGHT + 1)) ]]; then
      # Top/bottom border already drawn
      continue
    fi
    
    # Left border
    echo -n "│"
    
    # Playing field content
    for ((x = 0; x <= BOARD_WIDTH + 1; x++)); do
      if [[ $x -eq 0 || $x -eq $((BOARD_WIDTH + 1)) ]]; then
        # Right border (will be printed after loop)
        continue
      fi
      
      local cell=" "
      
      # Check if this is the snake head
      if [[ ${SNAKE_X[0]} -eq $x && ${SNAKE_Y[0]} -eq $y ]]; then
        cell="🟢"
      # Check if this is snake body
      else
        for ((i = 1; i < ${#SNAKE_X[@]}; i++)); do
          if [[ ${SNAKE_X[$i]} -eq $x && ${SNAKE_Y[$i]} -eq $y ]]; then
            cell="🟩"
            break
          fi
        done
      fi
      
      # Check if this is food
      if [[ $FOOD_X -eq $x && $FOOD_Y -eq $y ]]; then
        cell="🍎"
      fi
      
      echo -n "$cell"
    done
    
    # Right border
    echo "│"
  done
  
  # Draw bottom border
  tput cup "$((offset_y + BOARD_HEIGHT + 5))" "$offset_x"
  echo "└$(printf '─%.0s' $(seq 1 $((BOARD_WIDTH + 2))))┘"
  
  # Draw controls hint
  tput cup "$((offset_y + BOARD_HEIGHT + 7))" "$offset_x"
  tput dim
  echo "Controls: W/↑ Up | S/↓ Down | A/← Left | D/→ Right"
}

# draw_game_over: Display game over screen
draw_game_over() {
  local offset_x=$(( (TERM_WIDTH - 30) / 2 ))
  local offset_y=$(( (TERM_HEIGHT - 10) / 2 ))
  
  tput cup "$offset_y" "$offset_x"
  tput bold
  tput setaf 1  # Red
  echo "╔══════════════════════════════╗"
  
  tput cup "$((offset_y + 1))" "$offset_x"
  echo "║         GAME OVER!           ║"
  
  tput cup "$((offset_y + 2))" "$offset_x"
  echo "╠══════════════════════════════╣"
  
  tput cup "$((offset_y + 3))" "$offset_x"
  printf "║  Final Score: %-16d ║\n" "$SCORE"
  
  tput cup "$((offset_y + 4))" "$offset_x"
  printf "║  Snake Length: %-15d ║\n" "${#SNAKE_X[@]}"
  
  tput cup "$((offset_y + 5))" "$offset_x"
  echo "╠══════════════════════════════╣"
  
  tput cup "$((offset_y + 6))" "$offset_x"
  echo "║  [R] Restart  |  [Q] Quit    ║"
  
  tput cup "$((offset_y + 7))" "$offset_x"
  echo "╚══════════════════════════════╝"
  tput sgr0
}

# draw_win: Display win screen (snake fills board)
draw_win() {
  local offset_x=$(( (TERM_WIDTH - 30) / 2 ))
  local offset_y=$(( (TERM_HEIGHT - 10) / 2 ))
  
  tput cup "$offset_y" "$offset_x"
  tput bold
  tput setaf 2  # Green
  echo "╔══════════════════════════════╗"
  
  tput cup "$((offset_y + 1))" "$offset_x"
  echo "║          YOU WIN!            ║"
  
  tput cup "$((offset_y + 2))" "$offset_x"
  echo "╠══════════════════════════════╣"
  
  tput cup "$((offset_y + 3))" "$offset_x"
  printf "║  Final Score: %-16d ║\n" "$SCORE"
  
  tput cup "$((offset_y + 4))" "$offset_x"
  echo "║  Board completely filled!     ║"
  
  tput cup "$((offset_y + 5))" "$offset_x"
  echo "╠══════════════════════════════╣"
  
  tput cup "$((offset_y + 6))" "$offset_x"
  echo "║  [R] Play Again  |  [Q] Quit ║"
  
  tput cup "$((offset_y + 7))" "$offset_x"
  echo "╚══════════════════════════════╝"
  tput sgr0
}

# --- Main Game Loop ---

# game_loop: Run the main game loop
game_loop() {
  while [[ $GAME_OVER -eq 0 ]]; do
    draw_board
    handle_input
    move_snake
    check_collision
    sleep "0.$(printf '%03d' $SPEED_MS)"
  done
}

# post_game: Handle post-game actions (restart or quit)
post_game() {
  local running=1
  
  if [[ $GAME_OVER -eq 2 ]]; then
    draw_win
  else
    draw_game_over
  fi
  
  # Re-enable canonical mode for reading restart choice
  stty icanon echo
  
  while [[ $running -eq 1 ]]; do
    local choice=""
    read -rsn1 choice
    
    case "${choice,,}" in
      r)
        # Restart game
        stty -echo -icanon min 0 time 0
        init_game
        game_loop
        if [[ $GAME_OVER -eq 2 ]]; then
          draw_win
        else
          draw_game_over
        fi
        ;;
      q)
        running=0
        ;;
    esac
  done
}

# main: Main entry point
main() {
  parse_arguments "$@"
  setup_terminal
  init_game
  game_loop
  post_game
}

# Run main with all arguments
main "$@"
