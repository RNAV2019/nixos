.pragma library

// What a reading of a player's position says about where the song really is. No QML imports:
// tools/lyrics-test.mjs evaluates this file under node.

// The furthest out a player's run-on position is believed to be: past this the player says it
// has jumped itself, and a reading that far off is one taken across such a jump.
var MOST = 2.5;

// One reading as it is written, "WALL x MICROSECONDS": the wall clock in seconds as it was
// taken, and the position the player gave (busctl's way of writing it). Null for anything else.
function parse(row) {
  var m = /^\s*(\d+)[.,](\d+)\s+[a-z]\s+(-?\d+)\s*$/.exec(String(row));
  return m ? {
    wall: Number(m[1] + "." + m[2]),
    position: Number(m[3]) / 1000000
  } : null;
}

// A reading against the one before it. `toldNow` is the position the shell is running on at
// wall time `wallNow`, and `rate` how fast the player plays, so where the shell had the song as
// the reading was taken follows.
//   moved    the position changed between the two
//   live     it changed by just the time between them: the player works its position out as it
//            is asked, and the reading is exact
//   stride   how far it changed, in seconds of the song
//   ahead    how far the player is ahead of the shell's run-on position, in seconds; null when
//            the reading says nothing of it
// A position that did not change is stale by nobody knows how much. One that changed by more or
// less than the time between the readings is renewed in steps: it was exact as it stepped,
// somewhere in the gap between the two readings, and is taken as the middle of that gap.
function step(before, reading, toldNow, wallNow, rate) {
  var gap = rate * (reading.wall - before.wall);
  var stride = reading.position - before.position;
  var moved = stride !== 0;
  var live = moved && Math.abs(stride - gap) < 0.03;
  var ahead = null;
  if (moved) {
    ahead = reading.position - (toldNow - rate * (wallNow - reading.wall)) + (live ? 0 : gap / 2);
    if (Math.abs(ahead) > MOST)
      ahead = null;
  }
  return {
    moved: moved,
    live: live,
    stride: stride,
    ahead: ahead
  };
}
