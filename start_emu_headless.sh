#!/bin/bash

BL='\033[0;34m'
G='\033[0;32m'
RED='\033[0;31m'
YE='\033[1;33m'
NC='\033[0m' # No Color

emulator_name=${EMULATOR_NAME}

function launch_emulator () {
  adb devices | grep emulator | cut -f1 | while read line; do adb -s "$line" emu kill; done
  if [ "$OSTYPE" == "macOS" ];
  then
  emulator -avd "${emulator_name}" -no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim &
  elif [ "$OSTYPE" == "Linux" ]
  then
  nohup emulator -avd "${emulator_name}" -verbose -no-boot-anim -no-window -gpu off -no-accel -no-snapshot-load &
  elif [ "$OSTYPE" == "linux-gnu" ]
  then
  nohup emulator -avd "${emulator_name}" -verbose -no-boot-anim -no-window -gpu off -no-snapshot-load &
  fi
};

function check_emulator_status () {

printf "${G}==> ${BL}Checking device booting up status 🧐.. ${G}<==${NC}""\n"
while [[ "$(adb shell getprop sys.boot_completed 2>&1)" != 1 ]];
  do
  sleep 2
  if [ "$(adb shell getprop sys.boot_completed 2>&1)" == 1 ];
  then
     printf "${G}☞ ${BL}Device is fully booted and running!! 😀 : '$(adb shell getprop sys.boot_completed 2>&1)' ${G}☜${NC}""\n"
     adb devices -l
     adb shell input keyevent 82
     break
  else
     if [ "$(adb shell getprop sys.boot_completed 2>&1)" == "" ];
     then
     printf "${G}==> ${YE}Device is partially Booted! 😕 ${G}<==${NC}""\n"
     else
     printf  "${G}==> ${RED}$(adb shell getprop sys.boot_completed 2>&1) 😱 ${G}<==${NC}""\n"
     fi
  fi
done

};

function disable_animation() {
  adb shell "settings put global window_animation_scale 0.0"
  adb shell "settings put global transition_animation_scale 0.0"
  adb shell "settings put global animator_duration_scale 0.0"
};

function hidden_policy() {
  adb shell "settings put global hidden_api_policy_pre_p_apps 1;settings put global hidden_api_policy_p_apps 1;settings put global hidden_api_policy 1"
};

launch_emulator
sleep 4
check_emulator_status
sleep 1
disable_animation
sleep 1
hidden_policy
sleep 1