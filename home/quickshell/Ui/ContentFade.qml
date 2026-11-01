import QtQuick
import qs.Commons

// The quick cross-fade between two contents that hold the same place: a shut pill and its open
// card, one panel view and the next. Short enough that nothing is seen half-drawn; reduce-motion
// shortens it further through Theme.morphContent.
Morph {
  duration: Theme.morphContent
}
