#!/bin/sh
#Pac-Man - PacMan
#Ms. Pac-Man - PacMan m
#Pac-Man Plus - PacMan p
#Rally-X - RallyX
#New Rally-X - RallyX n
#Galaxian - Galaxian
#Galaga - Galaga
#Dig Dug - DigDug
#Xevious - Xevious
#Super Xevious - Xevious s
#Super Pac-Man - SuperPacMan
#Pac & Pal - SuperPacMan p
#Mappy - Mappy
#Dig Dug II - Mappy d
#Pac-Land - PacLand
#Rolling Thunder - NS86
#Hopping Mappy - NS86 h
#Pac-Mania - NS1
#Galaga '88 - NS1 g
#Dragon Spirit - NS1 d
#Super Pac-Man  - SuperPacMan
#Pac Man - PacMan
#Pac-Mania - NS1
#Pac-Land - PacLand
#Dig Dug - DigDug
#Galaga - Galaga
#Galaxian - Galaxian

export XDG_CONFIG_HOME=/data
export XDG_RUNTIME_DIR=/data

GAME_NAME=
GAME_SPEED=

case "$3" in
  0)
	GAME_SPEED=
    ;;
  1)
  	GAME_SPEED="-fast"
    ;;
  *)
	echo "Have not game resources"
    return
    ;;
esac

case "$1" in
  0)
    GAME_NAME=PacMan
    rm -f /data/Games/PacManFast.cfg
    cp -f /data/Games/PacMan.cfg /data/Games/PacManFast.cfg
    ;;
  1)
    GAME_NAME="SuperPacMan p"
    ;;
  2)
    GAME_NAME=SuperPacMan
    ;;
  3)
    GAME_NAME="PacMan p"
    rm -f /data/Games/PacManPlusFast.cfg
    cp -f /data/Games/PacManPlus.cfg /data/Games/PacManPlusFast.cfg
    ;;
  4)
    GAME_NAME=PacLand
    ;;
  5)
    GAME_NAME=NS1
    ;;
  6)
    GAME_NAME=Galaga
    ;;
  7)
    GAME_NAME=Galaxian
    #ln -s /data/Games/Galaga.cfg GalagaFastShot.cfg
    ;;
  8)
    GAME_NAME=Mappy
    ;;
  9)
    GAME_NAME=DigDug
    ;;
  10)
    GAME_NAME="Mappy d"
    ;;
  11)
    GAME_NAME="NS1 r"
    ;;
  *)
    echo "Have not game resources"
    return
    ;;
esac

export SDL_RENDER_SCALE_QUALITY="$2"

cd /data/Games/ && ./$GAME_NAME $GAME_SPEED
	
