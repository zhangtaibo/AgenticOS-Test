#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Snake Game - Terminal Snake Game
# A classic snake game implemented in pure bash
# =============================================================================

# --- Constants ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# Default game settings
DEFAULT_WIDTH=40
DEFAULT_HEIGHT=20
DEFAULT_SPEED="normal"

# Speed settings (delay in milliseconds)
declare -A SPEED_DELAY=(
  ["fast"]=50
  ["normal"]=100
  ["slow"]=200
)

# Direction constants
readonly DIR_UP="up"
readonly DIR_DOWN="down"
readonly DIR_LEFT="left"
readonly DIR_RIGHT="right"

# Game state variables
declare -a SNAKE_X=()
declare -a SNAKE_Y=()
declare -i FOOD_X=0
declare -i FOOD_Y=0
declare -i DIRECTION="$DIR_RIGHT"
declare -i NEXT_DIRECTION="$DIR_RIGHT"
declare -i SCORE=0
declare -i GAME_WIDTH=$DEFAULT_WIDTH
declare -i GAME_HEIGHT=$DEFAULT_HEIGHT
declare -i GAME_SPEED="${SPEED_DELAY[$DEFAULT_SPEED]}"
declare -i GAME_OVER=0
declare -i GAME_RUNNING=0

# Terminal state
declare -i TERM_WIDTH=0
declare -i TERM_HEIGHT=0

# =============================================================================
# Utility Functions
# =============================================================================

# Print usage information
usage() {
  cat >&2 <<EOF
$SCRIPT_NAME v$VERSION - Terminal Snake Game

Usage: $SCRIPT_NAME [OPTIONS]

A classic snake game played in the terminal. Control the snake to eat food
and grow longer without hitting walls or yourself.

Controls:
  W, ↑  - Move up
  S, ↓  - Move down
  A, ←  - Move left
  D, →  - Move right
  R     - Restart (after game over)
  Q     - Quit

Options:
  --speed <fast|normal|slow>  Set game speed (default: normal)
  --size <WxH>                Set game size, e.g., 40x20 (default: ${DEFAULT_WIDTH}x${DEFAULT_HEIGHT})
  -h, --help                  Show this help message

Examples:
  $SCRIPT_NAME                         # Start with default settings
  $SCRIPT_NAME --speed fast            # Fast-paced game
  $SCRIPT_NAME --size 60x30            # Larger game area
  $SCRIPT_NAME --speed slow --size 30x20

EOF
  exit "${1:-0}"
}

# Log error message
log_error() {
  printf "\033[0;31m[ERROR]\033[0m %s\n" "$*" >&2
}

# Log info message
log_info() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$*"
}

# =============================================================================
# Terminal Setup and Cleanup
# =============================================================================

# Save original terminal settings
declare ORIG_TTY_SETTINGS=""

# Initialize terminal for game
init_terminal() {
  # Save current terminal settings
  ORIG_TTY_SETTINGS="$(stty -g)"
  
  # Get terminal dimensions
  TERM_WIDTH="$(tput cols)"
  TERM_HEIGHT="$(tput lines)"
  
  # Check minimum terminal size
  local required_width=$((GAME_WIDTH + 4))
  local required_height=$((GAME_HEIGHT + 6))
  
  if [[ $TERM_WIDTH -lt $required_width ]] || [[ $TERM_HEIGHT -lt $required_height ]]; then
    log_error "Terminal too small! Required: ${required_width}x${required_height}, Current: ${TERM_WIDTH}x${TERM_HEIGHT}"
    log_error "Please resize your terminal and try again."
    cleanup
    exit 1
  fi
  
  # Set terminal to raw mode (no echo, no line buffering)
  stty -echo -icanon -isig
  
  # Hide cursor
  tput civis
  
  # Clear screen
  tput clear
}

# Restore terminal to original state
cleanup() {
  local exit_code=$?
  
  # Restore terminal settings
  if [[ -n "$ORIG_TTY_SETTINGS" ]]; then
    stty "$ORIG_TTY_SETTINGS" 2>/dev/null || true
  fi
  
  # Show cursor
  tput cnorm 2>/dev/null || true
  
  # Reset colors
  tput sgr0 2>/dev/null || true
  
  if [[ $exit_code -ne 0 ]]; then
    echo "" >&2
    log_error "$SCRIPT_NAME exited with code $exit_code"
  fi
  
  exit "$exit_code"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# =============================================================================
# Game Logic Functions
# =============================================================================

# Initialize game state
init_game() {
  # Reset snake to center of the board
  SNAKE_X=()
  SNAKE_Y=()
  
  local start_x=$((GAME_WIDTH / 2))
  local start_y=$((GAME_HEIGHT / 2))
  
  # Initial snake length of 3
  for i in 0 1 2; do
    SNAKE_X+=($((start_x - i)))
    SNAKE_Y+=($start_y)
  done
  
  # Reset game state
  DIRECTION="$DIR_RIGHT"
  NEXT_DIRECTION="$DIR_RIGHT"
  SCORE=0
  GAME_OVER=0
  GAME_RUNNING=1
  
  # Spawn initial food
  spawn_food
}

# Draw the game board
draw_board() {
  # Move cursor to top-left
  tput cup 0 0
  
  # Draw top border and score
  printf "\033[0;36m┌"
  for ((i = 0; i < GAME_WIDTH; i++)); do
    printf "─"
  done
  printf "─┐\033[0m\n"
  
  # Score panel
  printf "\033[0;36m│\033[0m  Score: \033[0;33m%-6d\033[0m  |  Length: \033[0;33m%-4d\033[0m  |  Speed: \033[0;33m%-6s\033[0m  \033[0;36m│\033[0m\n" \
    "$SCORE" "${#SNAKE_X[@]}" "$DEFAULT_SPEED"
  
  printf "\033[0;36m├"
  for ((i = 0; i < GAME_WIDTH; i++)); do
    printf "─"
  done
  printf "─┤\033[0m\n"
  
  # Draw game area
  for ((y = 0; y < GAME_HEIGHT; y++)); do
    printf "\033[0;36m│\033[0m"
    
    for ((x = 0; x < GAME_WIDTH; x++)); do
      local cell=" "
      local color=""
      
      # Check if this is the snake head
      if [[ ${SNAKE_X[0]} -eq $x ]] && [[ ${SNAKE_Y[0]} -eq $y ]]; then
        cell="@"
        color="\033[0;32m"  # Green for head
      # Check if this is snake body
      elif is_snake_body "$x" "$y"; then
        cell="o"
        color="\033[0;32m"  # Green for body
      # Check if this is food
      elif [[ $FOOD_X -eq $x ]] && [[ $FOOD_Y -eq $y ]]; then
        cell="*"
        color="\033[0;31m"  # Red for food
      fi
      
      if [[ -n "$color" ]]; then
        printf "${color}%s\033[0m" "$cell"
      else
        printf "%s" "$cell"
      fi
    done
    
    printf "\033[0;36m│\033[0m\n"
  done
  
  # Draw bottom border
  printf "\033[0;36m└"
  for ((i = 0; i < GAME_WIDTH; i++)); do
    printf "─"
  done
  printf "─┘\033[0m\n"
  
  # Controls hint
  printf "\033[0;37mControls: WASD/Arrows to move | Q to quit\033[0m\n"
  
  # Flush output
  tput flush
}

# Check if position is snake body (not head)
is_snake_body() {
  local check_x=$1
  local check_y=$2
  
  for ((i = 1; i < ${#SNAKE_X[@]}; i++)); do
    if [[ ${SNAKE_X[$i]} -eq $check_x ]] && [[ ${SNAKE_Y[$i]} -eq $check_y ]]; then
      return 0
    fi
  done
  return 1
}

# Check if position is any part of snake
is_snake() {
  local check_x=$1
  local check_y=$2
  
  for ((i = 0; i < ${#SNAKE_X[@]}; i++)); do
    if [[ ${SNAKE_X[$i]} -eq $check_x ]] && [[ ${SNAKE_Y[$i]} -eq $check_y ]]; then
      return 0
    fi
  done
  return 1
}

# Spawn food at random position (not on snake)
spawn_food() {
  local attempts=0
  local max_attempts=$((GAME_WIDTH * GAME_HEIGHT))
  
  while [[ $attempts -lt $max_attempts ]]; do
    FOOD_X=$((RANDOM % GAME_WIDTH))
    FOOD_Y=$((RANDOM % GAME_HEIGHT))
    
    # Check if food spawned on snake
    if ! is_snake "$FOOD_X" "$FOOD_Y"; then
      return 0
    fi
    
    ((attempts++))
  done
  
  # Fallback: find first empty cell
  for ((y = 0; y < GAME_HEIGHT; y++)); do
    for ((x = 0; x < GAME_WIDTH; x++)); do
      if ! is_snake "$x" "$y"; then
        FOOD_X=$x
        FOOD_Y=$y
        return 0
      fi
    done
  done
}

# Handle keyboard input
handle_input() {
  local key=""
  
  # Read key with timeout (non-blocking)
  if read -rsn1 -t 0.01 key 2>/dev/null; then
    # Handle escape sequences (arrow keys)
    if [[ "$key" == $'\x1b' ]]; then
      read -rsn2 -t 0.01 key 2>/dev/null || true
      case "$key" in
        "[A") key="w" ;;  # Up arrow
        "[B") key="s" ;;  # Down arrow
        "[C") key="d" ;;  # Right arrow
        "[D") key="a" ;;  # Left arrow
        *) key="" ;;
      esac
    fi
    
    # Convert to lowercase
    key="${key,,}"
    
    # Process input
    case "$key" in
      w|a|s|d)
        # Prevent 180-degree turns
        case "$key" in
          w) [[ "$DIRECTION" != "$DIR_DOWN" ]] && NEXT_DIRECTION="$DIR_UP" ;;
          s) [[ "$DIRECTION" != "$DIR_UP" ]] && NEXT_DIRECTION="$DIR_DOWN" ;;
          a) [[ "$DIRECTION" != "$DIR_RIGHT" ]] && NEXT_DIRECTION="$DIR_LEFT" ;;
          d) [[ "$DIRECTION" != "$DIR_LEFT" ]] && NEXT_DIRECTION="$DIR_RIGHT" ;;
        esac
        ;;
      q)
        GAME_RUNNING=0
        GAME_OVER=2  # Quit flag
        ;;
      r)
        if [[ $GAME_OVER -ne 0 ]]; then
          init_game
        fi
        ;;
    esac
  fi
}

# Move the snake
move_snake() {
  # Update direction
  DIRECTION="$NEXT_DIRECTION"
  
  # Calculate new head position
  local new_head_x=${SNAKE_X[0]}
  local new_head_y=${SNAKE_Y[0]}
  
  case "$DIRECTION" in
    "$DIR_UP")    ((new_head_y--)) ;;
    "$DIR_DOWN")  ((new_head_y++)) ;;
    "$DIR_LEFT")  ((new_head_x--)) ;;
    "$DIR_RIGHT") ((new_head_x++)) ;;
  esac
  
  # Check for food collision before moving
  local ate_food=0
  if [[ $new_head_x -eq $FOOD_X ]] && [[ $new_head_y -eq $FOOD_Y ]]; then
    ate_food=1
    ((SCORE += 10))
  fi
  
  # Move snake body (shift positions)
  local snake_length=${#SNAKE_X[@]}
  
  if [[ $ate_food -eq 1 ]]; then
    # Grow: add new head, keep tail
    SNAKE_X=("$new_head_x" "${SNAKE_X[@]}")
    SNAKE_Y=("$new_head_y" "${SNAKE_Y[@]}")
    spawn_food
  else
    # Move: add new head, remove tail
    # Shift array elements
    for ((i = snake_length - 1; i > 0; i--)); do
      SNAKE_X[$i]=${SNAKE_X[$((i-1))]}
      SNAKE_Y[$i]=${SNAKE_Y[$((i-1))]}
    done
    SNAKE_X[0]=$new_head_x
    SNAKE_Y[0]=$new_head_y
  fi
}

# Check for collisions (wall or self)
check_collision() {
  local head_x=${SNAKE_X[0]}
  local head_y=${SNAKE_Y[0]}
  
  # Wall collision
  if [[ $head_x -lt 0 ]] || [[ $head_x -ge $GAME_WIDTH ]]; then
    GAME_OVER=1
    return
  fi
  
  if [[ $head_y -lt 0 ]] || [[ $head_y -ge $GAME_HEIGHT ]]; then
    GAME_OVER=1
    return
  fi
  
  # Self collision (check if head hits any body part)
  for ((i = 1; i < ${#SNAKE_X[@]}; i++)); do
    if [[ ${SNAKE_X[$i]} -eq $head_x ]] && [[ ${SNAKE_Y[$i]} -eq $head_y ]]; then
      GAME_OVER=1
      return
    fi
  done
}

# Display game over screen
game_over() {
  tput cup $((GAME_HEIGHT + 4)) 0
  tput el
  
  if [[ $GAME_OVER -eq 2 ]]; then
    printf "\033[0;33m╔════════════════════════════════════════╗\033[0m\n"
    printf "\033[0;33m║\033[0m          Game Quit                    \033[0;33m║\033[0m\n"
    printf "\033[0;33m╚════════════════════════════════════════╝\033[0m\n"
  else
    printf "\033[0;31m╔════════════════════════════════════════╗\033[0m\n"
    printf "\033[0;31m║\033[0m          GAME OVER!                   \033[0;31m║\033[0m\n"
    printf "\033[0;31m╚════════════════════════════════════════╝\033[0m\n"
  fi
  
  printf "\n"
  printf "  \033[0;33mFinal Score:\033[0m  %d\n" "$SCORE"
  printf "  \033[0;33mSnake Length:\033[0m %d\n" "${#SNAKE_X[@]}"
  printf "\n"
  
  if [[ $GAME_OVER -ne 2 ]]; then
    printf "  Press \033[0;32mR\033[0m to restart or \033[0;31mQ\033[0m to quit: "
  else
    printf "  Thanks for playing!\n"
  fi
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_arguments() {
  local speed_set=0
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --speed)
        if [[ -z "${2:-}" ]]; then
          log_error "--speed requires a value (fast|normal|slow)"
          usage 1
        fi
        local speed_val="${2,,}"
        if [[ ! "$speed_val" =~ ^(fast|normal|slow)$ ]]; then
          log_error "Invalid speed: $2. Must be fast, normal, or slow."
          usage 1
        fi
        DEFAULT_SPEED="$speed_val"
        GAME_SPEED="${SPEED_DELAY[$DEFAULT_SPEED]}"
        shift 2
        speed_set=1
        ;;
      --size)
        if [[ -z "${2:-}" ]]; then
          log_error "--size requires a value (WxH)"
          usage 1
        fi
        local size_val="$2"
        if [[ ! "$size_val" =~ ^[0-9]+x[0-9]+$ ]]; then
          log_error "Invalid size format: $size_val. Use WxH (e.g., 40x20)"
          usage 1
        fi
        GAME_WIDTH="${size_val%x*}"
        GAME_HEIGHT="${size_val#*x}"
        
        # Validate dimensions
        if [[ $GAME_WIDTH -lt 10 ]] || [[ $GAME_WIDTH -gt 100 ]]; then
          log_error "Width must be between 10 and 100"
          exit 1
        fi
        if [[ $GAME_HEIGHT -lt 10 ]] || [[ $GAME_HEIGHT -gt 50 ]]; then
          log_error "Height must be between 10 and 50"
          exit 1
        fi
        shift 2
        ;;
      -h|--help)
        usage 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage 1
        ;;
      *)
        log_error "Unexpected argument: $1"
        usage 1
        ;;
    esac
  done
}

# =============================================================================
# Main Game Loop
# =============================================================================

main() {
  # Parse command line arguments
  parse_arguments "$@"
  
  # Initialize terminal
  init_terminal
  
  # Initialize game state
  init_game
  
  # Main game loop
  while [[ $GAME_RUNNING -eq 1 ]]; do
    # Draw the game board
    draw_board
    
    # Handle input
    handle_input
    
    # Check if game should continue
    if [[ $GAME_RUNNING -eq 0 ]]; then
      break
    fi
    
    # Move snake
    move_snake
    
    # Check collisions
    check_collision
    
    # Check if game over
    if [[ $GAME_OVER -ne 0 ]]; then
      draw_board
      game_over
      
      # Wait for restart or quit
      while true; do
        local key=""
        if read -rsn1 -t 0.1 key 2>/dev/null; then
          key="${key,,}"
          
          # Handle escape sequences
          if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.01 key 2>/dev/null || true
          fi
          
          case "$key" in
            r)
              if [[ $GAME_OVER -ne 2 ]]; then
                init_game
                break
              fi
              ;;
            q)
              GAME_RUNNING=0
              break
              ;;
          esac
        fi
      done
    fi
    
    # Delay for game speed
    local sleep_time
    sleep_time=$(awk "BEGIN {printf \"%.3f\", $GAME_SPEED/1000}")
    sleep "$sleep_time" 2>/dev/null || true
  done
  
  # Final cleanup handled by trap
}

# Run main function with all arguments
main "$@"
