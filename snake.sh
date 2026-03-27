#!/bin/bash
#
# Snake Game - A terminal-based snake game
# Play with WASD or arrow keys, eat food, grow longer, avoid walls and yourself!
#

set -euo pipefail

# ============================================================================
# Global Variables
# ============================================================================
declare -a SNAKE_X=()
declare -a SNAKE_Y=()
declare -i DIRECTION=0  # 0=right, 1=down, 2=left, 3=up
declare -i FOOD_X=0
declare -i FOOD_Y=0
declare -i SCORE=0
declare -i WIDTH=40
declare -i HEIGHT=20
declare -i SPEED=100  # milliseconds
declare -i GAME_RUNNING=1
declare -i INITIAL_LENGTH=3

# Terminal settings backup
declare -st OLD_STTY

# ============================================================================
# Cleanup and Restore Terminal
# ============================================================================
cleanup() {
    tput cnorm  # Show cursor
    tput sgr0   # Reset all attributes
    stty "$OLD_STTY" 2>/dev/null || true
    clear
}

trap cleanup EXIT INT TERM

# ============================================================================
# Usage and Help
# ============================================================================
usage() {
    cat <<EOF
Snake Game - Terminal Edition

Usage: $(basename "$0") [OPTIONS]

Options:
  --speed SPEED     Set game speed: fast (50ms), normal (100ms), slow (200ms)
                    Default: normal
  --size WxH        Set game board size (e.g., --size 60x25)
                    Default: 40x20
  --help            Show this help message

Controls:
  W or ↑           Move up
  S or ↓           Move down
  A or ←           Move left
  D or →           Move right
  
  R                Restart game (after Game Over)
  Q                Quit game

Examples:
  $(basename "$0")                    # Start with defaults
  $(basename "$0") --speed fast       # Fast-paced game
  $(basename "$0") --size 60x25       # Larger board
  $(basename "$0") --speed slow --size 50x30

EOF
    exit 0
}

# ============================================================================
# Parse Command Line Arguments
# ============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --speed)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --speed requires an argument (fast/normal/slow)" >&2
                    exit 1
                fi
                case "$2" in
                    fast)   SPEED=50 ;;
                    normal) SPEED=100 ;;
                    slow)   SPEED=200 ;;
                    *)
                        echo "Error: Invalid speed '$2'. Use: fast, normal, slow" >&2
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --size)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --size requires an argument (WxH)" >&2
                    exit 1
                fi
                if [[ ! "$2" =~ ^[0-9]+x[0-9]+$ ]]; then
                    echo "Error: Invalid size format '$2'. Use: WxH (e.g., 40x20)" >&2
                    exit 1
                fi
                WIDTH="${2%x*}"
                HEIGHT="${2#*x}"
                if (( WIDTH < 10 || HEIGHT < 10 )); then
                    echo "Error: Minimum size is 10x10" >&2
                    exit 1
                fi
                shift 2
                ;;
            --help)
                usage
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Initialize Game State
# ============================================================================
init_game() {
    SCORE=0
    DIRECTION=0  # Start moving right
    GAME_RUNNING=1
    
    # Initialize snake in the middle of the board
    local start_x=$((WIDTH / 2))
    local start_y=$((HEIGHT / 2))
    
    SNAKE_X=()
    SNAKE_Y=()
    
    for ((i = 0; i < INITIAL_LENGTH; i++)); do
        SNAKE_X+=($((start_x - i)))
        SNAKE_Y+=($start_y)
    done
    
    spawn_food
}

# ============================================================================
# Spawn Food at Random Location
# ============================================================================
spawn_food() {
    local valid=0
    local fx fy
    
    while (( valid == 0 )); do
        fx=$(( (RANDOM % (WIDTH - 2)) + 1 ))
        fy=$(( (RANDOM % (HEIGHT - 2)) + 1 ))
        
        # Check if food spawns on snake body
        valid=1
        for ((i = 0; i < ${#SNAKE_X[@]}; i++)); do
            if (( SNAKE_X[i] == fx && SNAKE_Y[i] == fy )); then
                valid=0
                break
            fi
        done
    done
    
    FOOD_X=$fx
    FOOD_Y=$fy
}

# ============================================================================
# Draw Game Board
# ============================================================================
draw_board() {
    # Move cursor to home position
    tput cup 0 0
    
    # Draw top border
    tput setaf 7  # White
    printf "┌"
    for ((x = 1; x <= WIDTH; x++)); do
        printf "──"
    done
    printf "┐\n"
    
    # Draw game area
    for ((y = 1; y <= HEIGHT; y++)); do
        printf "│"
        for ((x = 1; x <= WIDTH; x++)); do
            local drawn=0
            
            # Check if this is the snake head
            if (( SNAKE_X[0] == x && SNAKE_Y[0] == y )); then
                tput setaf 2  # Green
                printf "██"
                drawn=1
            fi
            
            # Check if this is snake body
            if (( drawn == 0 )); then
                for ((i = 1; i < ${#SNAKE_X[@]}; i++)); do
                    if (( SNAKE_X[i] == x && SNAKE_Y[i] == y )); then
                        tput setaf 3  # Yellow
                        printf "▓▓"
                        drawn=1
                        break
                    fi
                done
            fi
            
            # Check if this is food
            if (( drawn == 0 && FOOD_X == x && FOOD_Y == y )); then
                tput setaf 1  # Red
                printf "●●"
                drawn=1
            fi
            
            # Empty space
            if (( drawn == 0 )); then
                tput setaf 8  # Dark gray
                printf "  "
            fi
        done
        tput setaf 7
        printf "│\n"
    done
    
    # Draw bottom border
    printf "└"
    for ((x = 1; x <= WIDTH; x++)); do
        printf "──"
    done
    printf "┘\n"
    
    # Draw score panel
    tput setaf 6  # Cyan
    printf "Score: %-5d  Length: %-5d  Speed: %dms\n" "$SCORE" "${#SNAKE_X[@]}" "$SPEED"
    tput setaf 7
    printf "Controls: W/A/S/D or Arrow Keys | Q to Quit\n"
}

# ============================================================================
# Handle User Input
# ============================================================================
handle_input() {
    local key=""
    
    # Read a single character with timeout
    if read -rsn1 -t 0.01 key 2>/dev/null; then
        # Handle escape sequences for arrow keys
        if [[ "$key" == $'\x1b' ]]; then
            if read -rsn2 -t 0.01 key 2>/dev/null; then
                key="$key"
            fi
        fi
        
        case "$key" in
            w|W|$'\x1b[A')  # Up
                if (( DIRECTION != 3 )); then
                    DIRECTION=0
                fi
                ;;
            d|D|$'\x1b[C')  # Right
                if (( DIRECTION != 0 )); then
                    DIRECTION=1
                fi
                ;;
            s|S|$'\x1b[B')  # Down
                if (( DIRECTION != 0 )); then
                    DIRECTION=2
                fi
                ;;
            a|A|$'\x1b[D')  # Left
                if (( DIRECTION != 1 )); then
                    DIRECTION=3
                fi
                ;;
            q|Q)
                GAME_RUNNING=0
                echo "Game quit by user!"
                exit 0
                ;;
        esac
    fi
}

# ============================================================================
# Move Snake
# ============================================================================
move_snake() {
    local head_x=${SNAKE_X[0]}
    local head_y=${SNAKE_Y[0]}
    local new_x=$head_x
    local new_y=$head_y
    
    # Calculate new head position based on direction
    case $DIRECTION in
        0) ((new_x++)) ;;  # Right
        1) ((new_y++)) ;;  # Down
        2) ((new_x--)) ;;  # Left
        3) ((new_y--)) ;;  # Up
    esac
    
    # Insert new head
    SNAKE_X=("$new_x" "${SNAKE_X[@]}")
    SNAKE_Y=("$new_y" "${SNAKE_Y[@]}")
    
    # Check if food was eaten
    if (( new_x == FOOD_X && new_y == FOOD_Y )); then
        ((SCORE += 10))
        spawn_food
    else
        # Remove tail if no food eaten
        unset 'SNAKE_X[-1]'
        unset 'SNAKE_Y[-1]'
    fi
}

# ============================================================================
# Check Collision with Walls or Self
# ============================================================================
check_collision() {
    local head_x=${SNAKE_X[0]}
    local head_y=${SNAKE_Y[0]}
    
    # Check wall collision
    if (( head_x < 1 || head_x > WIDTH || head_y < 1 || head_y > HEIGHT )); then
        GAME_RUNNING=0
        return 1
    fi
    
    # Check self collision (skip head)
    for ((i = 1; i < ${#SNAKE_X[@]}; i++)); do
        if (( SNAKE_X[i] == head_x && SNAKE_Y[i] == head_y )); then
            GAME_RUNNING=0
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# Game Over Screen
# ============================================================================
game_over() {
    clear
    tput cup $((HEIGHT / 2 - 2)) $(( (WIDTH * 2 + 4) / 2 - 10 ))
    tput setaf 1  # Red
    tput bold
    echo "════════════════════════"
    echo "       GAME OVER!       "
    echo "════════════════════════"
    tput sgr0
    
    tput cup $((HEIGHT / 2 + 1)) $(( (WIDTH * 2 + 4) / 2 - 8 ))
    tput setaf 6  # Cyan
    echo "Final Score: $SCORE"
    echo "Snake Length: ${#SNAKE_X[@]}"
    
    tput cup $((HEIGHT / 2 + 4)) $(( (WIDTH * 2 + 4) / 2 - 12 ))
    tput setaf 7
    echo "Press [R] to restart or [Q] to quit"
    
    while true; do
        read -rsn1 key
        case "$key" in
            r|R)
                return 0  # Restart
                ;;
            q|Q)
                echo "Thanks for playing!"
                exit 0
                ;;
        esac
    done
}

# ============================================================================
# Main Game Loop
# ============================================================================
main() {
    parse_args "$@"
    
    # Save terminal settings and configure for game
    OLD_STTY=$(stty -g)
    stty -echo -icanon min 0 time 0
    tput civis  # Hide cursor
    clear
    
    echo "🐍 Snake Game Starting..."
    echo "Board: ${WIDTH}x${HEIGHT} | Speed: ${SPEED}ms"
    sleep 1
    
    init_game
    
    # Main game loop
    while (( GAME_RUNNING )); do
        draw_board
        handle_input
        
        if (( GAME_RUNNING )); then
            move_snake
            if ! check_collision; then
                if ! game_over; then
                    init_game
                fi
            fi
        fi
        
        # Control game speed
        sleep "0.0${SPEED}"
    done
}

# ============================================================================
# Entry Point
# ============================================================================
main "$@"
