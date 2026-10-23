.pragma library

// The launcher's symbol table: characters worth reaching for that are not emoji, or that
// the emoji list names too awkwardly to find. Each entry is [char, name, keywords];
// `GROUPS` keeps them in the order the picker lists them.

var GROUPS = [
  {
    name: "Arrows",
    items: [
      ["→", "right arrow", "to, then, implies, next"],
      ["←", "left arrow", "from, back, previous"],
      ["↑", "up arrow", "increase, raise"],
      ["↓", "down arrow", "decrease, lower"],
      ["↔", "left right arrow", "both ways, bidirectional, swap"],
      ["↕", "up down arrow", "vertical, both ways"],
      ["⇒", "rightwards double arrow", "implies, therefore, then"],
      ["⇐", "leftwards double arrow", "implied by"],
      ["⇔", "left right double arrow", "iff, if and only if, equivalent"],
      ["↗", "north east arrow", "up right, trending up"],
      ["↘", "south east arrow", "down right, trending down"],
      ["↩", "return arrow", "back, undo, reply"],
      ["↻", "clockwise arrow", "refresh, reload, redo"],
      ["⟶", "long right arrow", "maps to"]
    ]
  },
  {
    name: "Maths",
    items: [
      ["±", "plus minus", "plus or minus, tolerance"],
      ["∓", "minus plus", "minus or plus"],
      ["×", "multiplication", "times, multiply, cross"],
      ["÷", "division", "divide, obelus"],
      ["≈", "almost equal", "approximately, approx, about"],
      ["≠", "not equal", "unequal, ne"],
      ["≡", "identical to", "equivalent, congruent"],
      ["≤", "less than or equal", "le, at most"],
      ["≥", "greater than or equal", "ge, at least"],
      ["∞", "infinity", "infinite, forever"],
      ["√", "square root", "sqrt, radical"],
      ["∑", "summation", "sum, sigma"],
      ["∏", "product", "pi product"],
      ["∫", "integral", "integrate, calculus"],
      ["∂", "partial", "derivative, partial differential"],
      ["∆", "increment", "delta, change, difference"],
      ["∇", "nabla", "del, gradient"],
      ["π", "pi", "greek, circle, 3.14"],
      ["°", "degree", "degrees, temperature, angle"],
      ["‰", "per mille", "per thousand"],
      ["∈", "element of", "in, member, set"],
      ["∉", "not element of", "not in, set"],
      ["⊂", "subset", "set, contained"],
      ["∪", "union", "set, or"],
      ["∩", "intersection", "set, and"],
      ["∅", "empty set", "null, nothing"],
      ["∀", "for all", "every, universal"],
      ["∃", "there exists", "exists, existential"],
      ["¬", "not", "negation, logic"],
      ["∧", "logical and", "conjunction, wedge"],
      ["∨", "logical or", "disjunction, vee"],
      ["½", "one half", "fraction, half"],
      ["¼", "one quarter", "fraction, quarter"],
      ["¾", "three quarters", "fraction"],
      ["²", "superscript two", "squared, power"],
      ["³", "superscript three", "cubed, power"],
      ["µ", "micro", "micro sign, mu"]
    ]
  },
  {
    name: "Keyboard",
    items: [
      ["⌘", "command", "cmd, super, mac, place of interest"],
      ["⌥", "option", "alt, opt, mac"],
      ["⇧", "shift", "keyboard"],
      ["⌃", "control", "ctrl, keyboard"],
      ["⎋", "escape", "esc, keyboard"],
      ["⏎", "return", "enter, keyboard"],
      ["⌫", "backspace", "delete left, erase, keyboard"],
      ["⌦", "delete", "delete right, forward delete, keyboard"],
      ["⇥", "tab", "keyboard, indent"],
      ["⇪", "caps lock", "keyboard"],
      ["␣", "space", "blank, keyboard"]
    ]
  },
  {
    name: "Currency",
    items: [
      ["£", "pound", "gbp, sterling, money"],
      ["€", "euro", "eur, money"],
      ["$", "dollar", "usd, money"],
      ["¥", "yen", "jpy, yuan, money"],
      ["¢", "cent", "money"],
      ["₹", "rupee", "inr, money"],
      ["₿", "bitcoin", "btc, crypto"]
    ]
  },
  {
    name: "Typography",
    items: [
      ["—", "em dash", "dash, long dash, mdash"],
      ["–", "en dash", "dash, range, ndash"],
      ["…", "ellipsis", "dots, three dots, etc"],
      ["•", "bullet", "dot, list"],
      ["·", "middle dot", "interpunct, centre dot"],
      ["©", "copyright", "c"],
      ["®", "registered", "trademark, r"],
      ["™", "trade mark", "tm, trademark"],
      ["§", "section", "paragraph, law"],
      ["¶", "pilcrow", "paragraph"],
      ["†", "dagger", "footnote, obelisk"],
      ["‘", "left single quote", "quotation, apostrophe, open"],
      ["’", "right single quote", "quotation, apostrophe, close"],
      ["“", "left double quote", "quotation, open"],
      ["”", "right double quote", "quotation, close"],
      ["«", "left guillemet", "quotation, french"],
      ["»", "right guillemet", "quotation, french"],
      ["′", "prime", "feet, minutes"],
      ["″", "double prime", "inches, seconds"],
      ["№", "numero", "number, no"]
    ]
  },
  {
    name: "Marks",
    items: [
      ["✓", "check mark", "tick, yes, done, ok"],
      ["✗", "cross mark", "x, no, wrong, ballot"],
      ["★", "black star", "star, favourite, rating"],
      ["☆", "white star", "star, outline, rating"],
      ["♪", "music note", "eighth note, song"]
    ]
  },
  {
    name: "Greek",
    items: [
      ["α", "alpha", "greek"],
      ["β", "beta", "greek"],
      ["γ", "gamma", "greek"],
      ["δ", "delta", "greek"],
      ["ε", "epsilon", "greek"],
      ["ζ", "zeta", "greek"],
      ["η", "eta", "greek"],
      ["θ", "theta", "greek, angle"],
      ["ι", "iota", "greek"],
      ["κ", "kappa", "greek"],
      ["λ", "lambda", "greek, wavelength, function"],
      ["μ", "mu", "greek, micro"],
      ["ν", "nu", "greek"],
      ["ξ", "xi", "greek"],
      ["ο", "omicron", "greek"],
      ["ρ", "rho", "greek, density"],
      ["σ", "sigma", "greek, standard deviation"],
      ["τ", "tau", "greek, torque"],
      ["υ", "upsilon", "greek"],
      ["φ", "phi", "greek, golden ratio"],
      ["χ", "chi", "greek"],
      ["ψ", "psi", "greek"],
      ["ω", "omega", "greek, angular frequency"],
      ["Γ", "capital gamma", "greek"],
      ["Δ", "capital delta", "greek, change"],
      ["Θ", "capital theta", "greek"],
      ["Λ", "capital lambda", "greek"],
      ["Ξ", "capital xi", "greek"],
      ["Π", "capital pi", "greek, product"],
      ["Σ", "capital sigma", "greek, sum"],
      ["Φ", "capital phi", "greek"],
      ["Ψ", "capital psi", "greek"],
      ["Ω", "capital omega", "greek, ohm, resistance"]
    ]
  }
];
