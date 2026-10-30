.pragma library

// The video-call link in an event: Google Meet, Microsoft Teams, Zoom or Webex. An event
// carries it in its own URL, its location or its description, in that order; the first link
// in the first place that has one wins.

var LINKS = [
  {
    service: "Meet",
    pattern: /https?:\/\/meet\.google\.com\/[a-z0-9_?=&.\-\/]+/i
  },
  {
    service: "Teams",
    pattern: /https?:\/\/(?:teams\.microsoft\.com\/(?:l\/meetup-join|meet)|teams\.live\.com\/meet)\/[^\s<>"')]+/i
  },
  {
    service: "Zoom",
    pattern: /https?:\/\/(?:[a-z0-9\-]+\.)?zoom\.(?:us|com)\/(?:j|my|wc\/join)\/[^\s<>"')]+/i
  },
  {
    service: "Webex",
    pattern: /https?:\/\/(?:[a-z0-9\-]+\.)?webex\.com\/(?:meet|join|[a-z0-9\-]+\/j\.php)[^\s<>"')]*/i
  }
];

// { service, url } for the first place that holds a link, or null.
function find(url, location, description) {
  var places = [url, location, description];
  for (var p = 0; p < places.length; p++) {
    var text = String(places[p] || "");
    if (text === "")
      continue;
    for (var i = 0; i < LINKS.length; i++) {
      var hit = LINKS[i].pattern.exec(text);
      if (hit)
        return {
          service: LINKS[i].service,
          url: hit[0].replace(/[.,;:]+$/, "")
        };
    }
  }
  return null;
}
