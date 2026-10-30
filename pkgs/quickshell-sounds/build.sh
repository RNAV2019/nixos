#!/usr/bin/env bash
# Synthesises the interface sounds into the directory given. Mono, 48 kHz, 16 bit, all under
# 400 ms except the timer's. Each is built at full scale in $work, then levelled to one RMS
# (and held under a peak ceiling, which only the noisy shutter reaches) on the way out.
# -R keeps sox's noise generator and dither from reseeding, so a rebuild is byte-identical.
set -euo pipefail

out=$1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

rate=48000
target_rms=0.045 # about -27 dBFS: present on speakers, never startling on headphones
ceiling=0.35     # about -9 dBFS peak

s() { sox -R -q -D -n -r $rate -b 32 -c 1 "$@"; }

# note FILE FREQ DURATION [WEIGHT]: a soft bell, the fundamental under a quiet octave with a
# log fade-out so it dies away rather than stopping. The 4 ms fade-in keeps the onset click-free.
note() {
  local file=$1 freq=$2 dur=$3 weight=${4:-0.22}
  s "$work/a.wav" synth "$dur" sine "$freq"
  s "$work/b.wav" synth "$dur" sine "$(awk -v f="$freq" 'BEGIN { print f * 2 }')"
  sox -R -q -m -v 1 "$work/a.wav" -v "$weight" "$work/b.wav" "$work/m.wav"
  sox -R -q "$work/m.wav" "$file" fade l 0.004 "$dur" "$(awk -v d="$dur" 'BEGIN { print d * 0.9 }')"
}

# then FILE...: the notes in order, each starting `delay` seconds after the last began, so
# a later one rings over the tail of an earlier. The first argument is the output.
sequence() {
  local file=$1 delay=$2
  shift 2
  local at=0 i=0 parts=()
  for n in "$@"; do
    local padded="$work/seq$i.wav"
    sox -R -q "$n" "$padded" pad "$at"
    parts+=("$padded")
    at=$(awk -v a="$at" -v d="$delay" 'BEGIN { print a + d }')
    i=$((i + 1))
  done
  sox -R -q -m "${parts[@]}" "$file"
}

# level FILE NAME: scale to target_rms, then under the peak ceiling, and write 16 bit without
# dither, so the build is byte-for-byte reproducible.
level() {
  local in=$1 name=$2
  local rms peak gain
  rms=$(sox -R "$in" -n stat 2>&1 | awk '/RMS +amplitude/ { print $3 }')
  gain=$(awk -v r="$rms" -v t="$target_rms" 'BEGIN { print t / r }')
  peak=$(sox -R "$in" -n stat 2>&1 | awk '/Maximum amplitude/ { a = $3 } /Minimum amplitude/ { b = -$3 } END { print (a > b ? a : b) }')
  gain=$(awk -v g="$gain" -v p="$peak" -v c="$ceiling" 'BEGIN { print (g * p > c) ? c / p : g }')
  sox -R -q -D "$in" -b 16 "$out/$name.wav" vol "$gain" amplitude
}

# --- the sounds ---

# volume: a short soft tick, a pure blip.
note "$work/tick.wav" 1568 0.045 0.1
level "$work/tick.wav" tick

# screenshot: a two-part shutter of band-limited noise, the second part lower and longer.
s "$work/n1.wav" synth 0.028 whitenoise
sox -R -q "$work/n1.wav" "$work/n1f.wav" sinc 1800-7000 fade h 0.004 0.028 0.016
s "$work/n2.wav" synth 0.06 whitenoise
sox -R -q "$work/n2.wav" "$work/n2f.wav" sinc 900-4200 fade h 0.006 0.06 0.045
sox -R -q "$work/n2f.wav" "$work/n2p.wav" pad 0.045
sox -R -q -m "$work/n1f.wav" "$work/n2p.wav" "$work/shutter.wav"
level "$work/shutter.wav" shutter

# plugged in: a gentle rising pair, E5 then A5.
note "$work/p1.wav" 659.26 0.2
note "$work/p2.wav" 880 0.26
sequence "$work/plugged.wav" 0.11 "$work/p1.wav" "$work/p2.wav"
level "$work/plugged.wav" plugged

# timer done and Pomodoro phase: a slow three-note bell, rising; the one sound allowed to be long.
note "$work/t1.wav" 783.99 0.5
note "$work/t2.wav" 987.77 0.5
note "$work/t3.wav" 1318.51 0.8
sequence "$work/timer.wav" 0.22 "$work/t1.wav" "$work/t2.wav" "$work/t3.wav"
level "$work/timer.wav" timer

# notification: one bell; the urgent one is a lower pair, the second note repeating the first.
note "$work/c1.wav" 1046.5 0.3
level "$work/c1.wav" chime
note "$work/u1.wav" 783.99 0.18
note "$work/u2.wav" 1046.5 0.28
sequence "$work/urgent.wav" 0.09 "$work/u1.wav" "$work/u2.wav" "$work/u1.wav"
level "$work/urgent.wav" chime-urgent

# attention (Claude wants you, a sign-in is waiting): two equal taps of one note.
note "$work/a1.wav" 698.46 0.16
sequence "$work/attention.wav" 0.17 "$work/a1.wav" "$work/a1.wav"
level "$work/attention.wav" attention

# success: a quick rising arpeggio, C major.
note "$work/s1.wav" 523.25 0.14
note "$work/s2.wav" 659.26 0.14
note "$work/s3.wav" 783.99 0.2
sequence "$work/success.wav" 0.06 "$work/s1.wav" "$work/s2.wav" "$work/s3.wav"
level "$work/success.wav" success

# failure: a falling pair that settles on a minor third.
note "$work/f1.wav" 466.16 0.18
note "$work/f2.wav" 369.99 0.24
sequence "$work/failure.wav" 0.12 "$work/f1.wav" "$work/f2.wav"
level "$work/failure.wav" failure

# file received: a rising glide with a bell on its end, like something dropping into place.
s "$work/g.wav" synth 0.11 sine 520-880
sox -R -q "$work/g.wav" "$work/gf.wav" fade h 0.008 0.11 0.05
note "$work/r2.wav" 1174.66 0.22
sequence "$work/received.wav" 0.08 "$work/gf.wav" "$work/r2.wav"
level "$work/received.wav" received

# lock and unlock: a falling fourth and the same rising, so the pair reads as one gesture.
note "$work/l1.wav" 784 0.15
note "$work/l2.wav" 523.25 0.24
sequence "$work/lock.wav" 0.1 "$work/l1.wav" "$work/l2.wav"
level "$work/lock.wav" lock
sequence "$work/unlock.wav" 0.1 "$work/l2.wav" "$work/l1.wav"
level "$work/unlock.wav" unlock
