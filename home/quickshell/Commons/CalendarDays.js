.pragma library

// One month's events grouped by the day each starts on, so the grid asks a map for a day
// instead of scanning every event for each of its 42 cells. An event belongs to its start day
// alone, in the local calendar, however long it runs. tools/qs-verify/js/calendar.test.mjs
// holds this to the scan it replaced.

function keyOf(day) {
  return day.getFullYear() + "-" + day.getMonth() + "-" + day.getDate();
}

// All-day events first, then by start; events that tie keep the order they arrived in.
function order(a, b) {
  if (a.allDay !== b.allDay)
    return a.allDay ? -1 : 1;
  return a.start - b.start;
}

function build(events) {
  var days = {};
  for (var i = 0; i < events.length; i++) {
    var key = keyOf(events[i].start);
    if (days[key] === undefined)
      days[key] = [];
    days[key].push(events[i]);
  }
  for (var k in days)
    days[k].sort(order);
  return days;
}

// A copy each time: the agenda resets its scroll whenever its array is a new one.
function on(days, day) {
  var found = days[keyOf(day)];
  return found === undefined ? [] : found.slice();
}
