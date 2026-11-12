.pragma library

// The calculator's reading of everyday phrasing: a query as someone would say it, rewritten
// into the expression qalc reads. qalc takes words as units and variables, so "5 km in miles"
// is kilometres times inches times miles to it, and "what is 12 times 12" is an error. Each
// rule here is one such phrasing; anything it does not know passes through untouched, and
// qalc's own echo of what it read is shown with the answer. tools/calc-phrase-test.mjs runs
// the list of phrasings through this file and qalc.

// qalc's private config (Services/Calculator.qml writes it): nothing saved, no mixed units
// ("3 mi + 188 yd"), and every question it would otherwise stop to ask answered. A comma
// separates arguments, a dot is the decimal point, and "150 + 20%" adds 20 % of 150.
var qalcConfig = "[General]\nsave_config=0\nsave_mode_on_exit=0\nsave_definitions_on_exit=0\nauto_update_exchange_rates=0\ncolorize=0\ndecimal_comma=0\ndot_as_separator=0\ncomma_as_separator=0\n[Mode]\nmixed_units_conversion=0\nsimplified_percentage=1\n";

var SMALL = {
  zero: 0,
  one: 1,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  nine: 9,
  ten: 10,
  eleven: 11,
  twelve: 12,
  thirteen: 13,
  fourteen: 14,
  fifteen: 15,
  sixteen: 16,
  seventeen: 17,
  eighteen: 18,
  nineteen: 19
};

var TENS = {
  twenty: 20,
  thirty: 30,
  forty: 40,
  fifty: 50,
  sixty: 60,
  seventy: 70,
  eighty: 80,
  ninety: 90
};

var SCALES = {
  thousand: 1e3,
  million: 1e6,
  billion: 1e9
};

var PARTS = {
  half: 2,
  halve: 2,
  third: 3,
  quarter: 4,
  fifth: 5,
  tenth: 10
};

var NUMBER = Object.keys(SMALL).concat(Object.keys(TENS), ["hundred"], Object.keys(SCALES)).join("|");

// A run of number words: "two hundred and fifty", "a thousand", "twenty-one".
var RUN = new RegExp("\\b(?:an?\\s+(?=(?:hundred|thousand|million|billion)\\b))?(?:" + NUMBER + ")(?:(?:\\s+and\\s+|\\s+|-)(?:" + NUMBER + "))*\\b", "gi");

// Something on the far side of a conversion that is money, so "pounds" is sterling there.
var MONEY = /[$€£¥₹]|\b(?:usd|eur|gbp|jpy|zar|aud|cad|chf|cny|inr|nzd|dollars?|euros?|yen|rupees?|francs?|sterling)\b/i;

// One run as digits. Words that cannot belong to the same number start another, so "five
// three" stays two numbers instead of adding up to eight.
function spell(run) {
  var words = run.toLowerCase().split(/[\s-]+/);
  var out = [];
  var total = 0, current = 0;
  var last = "";

  var flush = function () {
    if (last !== "")
      out.push(String(total + current));
    total = 0;
    current = 0;
    last = "";
  };

  for (var i = 0; i < words.length; i++) {
    var w = words[i];
    if (w === "a" || w === "an")
      continue;
    if (w === "and") {
      if (last !== "hundred" && last !== "scale") {
        flush();
        out.push("and");
      }
      continue;
    }
    if (w in SMALL) {
      var v = SMALL[w];
      var joins = last === "hundred" || last === "scale" || (last === "ten" && v > 0 && v < 10);
      if (last !== "" && !joins)
        flush();
      current += v;
      last = "unit";
    } else if (w in TENS) {
      if (last !== "" && last !== "hundred" && last !== "scale")
        flush();
      current += TENS[w];
      last = "ten";
    } else if (w === "hundred") {
      if (last === "hundred" || last === "scale")
        flush();
      current = (current || 1) * 100;
      last = "hundred";
    } else {
      total += (current || 1) * SCALES[w];
      current = 0;
      last = "scale";
    }
  }
  flush();
  return out.join(" ");
}

function numbers(s) {
  return s.replace(RUN, spell);
}

// What is being asked, without the asking: "what is", "calculate", a closing "?" or "=".
function strip(q) {
  var s = q.trim().replace(/\s+/g, " ").replace(/[\s?=]+$/, "");
  s = s.replace(/^(?:(?:what(?:'s|’s| is| are)|whats|how much (?:is|are)|calculate|calc|compute|convert|work out|evaluate)\s+)+/i, "");
  return s.replace(/\s+equals?$/i, "");
}

// Whether the query carries a number of its own, in digits or in words.
function hasNumber(q) {
  return /\d/.test(numbers(strip(q)));
}

// An operand that keeps to itself inside a larger expression.
function group(x) {
  x = x.trim();
  return /^[\w.,%$€£]+$/.test(x) ? x : "(" + x + ")";
}

// "3, 5 and 10" as function arguments.
function list(x) {
  var parts = x.trim().split(/\s*,\s*(?:and\s+)?|\s+and\s+/i);
  if (parts.length === 1 && /^[\d.\s-]+$/.test(x))
    parts = x.trim().split(/\s+/);
  return parts.filter(function (p) {
    return p.length > 0;
  });
}

function amount(x) {
  x = x.replace(/^(?:an?|one)\s+/i, "");
  return /^[-\d.(]/.test(x) ? x : "1 " + x;
}

function rewrite(q) {
  var s = numbers(strip(q));
  var m;

  // "1,234" is one number, unless the commas are a list being averaged or summed.
  if (s.indexOf("(") < 0 && !/^(?:the )?(?:average|mean|median|sum) of /i.test(s))
    s = s.replace(/\b\d{1,3}(?:,\d{3})+\b/g, function (n) {
      return n.replace(/,/g, "");
    });

  // "how many seconds in a day", "how many miles is 5 km".
  m = s.match(/^how many (.+?) (?:(?:are|is) )?(?:there )?in (.+)$/i) || s.match(/^how many (.+?) (?:is|are|makes?) (.+)$/i);
  if (m)
    s = amount(m[2]) + " to " + m[1];

  // Percentages. "20% off 150" and "150 less 20%" take it away; "20% of 150" is a product.
  s = s.replace(/(\d)\s*(?:percent|per cent|pct)\b/gi, "$1%");
  m = s.match(/^what (?:%|percent(?:age)?) of (.+?) is (.+)$/i);
  if (m)
    s = group(m[2]) + " / " + group(m[1]) + " to %";
  m = s.match(/^(.+?) (?:is what|as an?) (?:%|percent(?:age)?) of (.+)$/i);
  if (m)
    s = group(m[1]) + " / " + group(m[2]) + " to %";
  m = s.match(/^([\d.]+%) off (.+)$/i);
  if (m)
    s = m[2] + " - " + m[1];
  m = s.match(/^(?:tip (?:of )?([\d.]+%)|([\d.]+%) tip) (?:on|for|of) (.+)$/i);
  if (m)
    s = (m[1] || m[2]) + " * " + group(m[3]);
  s = s.replace(/\s+less\s+(?=[\d.]+%)/gi, " - ");
  s = s.replace(/(\d)\s*%\s+of\s+/gi, "$1% * ");

  // Shares of something: "half of 340", "two thirds of 90", "double 45".
  m = s.match(/^(?:(?:an?|1)[ -])?(half|third|quarter|fifth|tenth)(?: of (.+)| ([-\d.(].*))$/i);
  if (m)
    s = group(m[2] || m[3]) + " / " + PARTS[m[1].toLowerCase()];
  m = s.match(/^(\d+)[ -](halve|third|quarter|fifth|tenth)s of (.+)$/i);
  if (m)
    s = m[1] + " / " + PARTS[m[2].toLowerCase()] + " * " + group(m[3]);
  m = s.match(/^(double|twice|triple|thrice) (.+)$/i);
  if (m)
    s = (/^t[rh]/i.test(m[1]) ? "3" : "2") + " * " + group(m[2]);
  m = s.match(/^split (.+?) (?:between|among|amongst|by|over|into) (\d+)(?: (?:people|persons|ways|parts|of us))?$/i);
  if (m)
    s = group(m[1]) + " / " + m[2];

  // Functions by name. Leading the query they take all that follows; inside it, one number.
  s = s.replace(/^(?:the )?cube root of (.+)$/i, "cbrt($1)").replace(/\bcube root of ([\d.]+)/gi, "cbrt($1)");
  s = s.replace(/^(?:the )?(?:square root|sqrt) of (.+)$/i, "sqrt($1)").replace(/\b(?:square root|sqrt) of ([\d.]+)/gi, "sqrt($1)");
  s = s.replace(/\blog(?:arithm)? (?:to )?base (\S+) of (\S+)/gi, "log($2, $1)");
  s = s.replace(/\b(?:natural log(?:arithm)?|ln) of (\S+)/gi, "ln($1)");
  s = s.replace(/\bfactorial of ([\d.]+)/gi, "$1!").replace(/([\d.]+|\))\s+factorial\b/gi, "$1!");
  m = s.match(/^(?:the )?sum of (\d+) (?:to|through) (\d+)$/i);
  if (m)
    s = "sum(x, " + m[1] + ", " + m[2] + ")";
  m = s.match(/^(?:the )?sum of (.+)$/i);
  if (m)
    s = list(m[1]).join(" + ");
  m = s.match(/^(?:the )?(average|mean|median) of (.+)$/i);
  if (m)
    s = (m[1].toLowerCase() === "median" ? "median" : "mean") + "(" + list(m[2]).join(", ") + ")";

  // Operators in words.
  s = s.replace(/\s+(?:to the power(?: of)?|raised to(?: the)?(?: power(?: of)?)?)\s+/gi, "^");
  s = s.replace(/\s+to the (\d+)(?:st|nd|rd|th)(?: power)?\b/gi, "^$1");
  s = s.replace(/\s+squared\b/gi, "^2").replace(/\s+cubed\b/gi, "^3");
  s = s.replace(/^(?:minus|negative) (?=[\d.(])/i, "-");
  s = s.replace(/\s+plus\s+/gi, " + ").replace(/\s+minus\s+/gi, " - ");
  s = s.replace(/\s+(?:times|multiplied by)\s+/gi, " * ").replace(/\s+divided by\s+/gi, " / ");
  s = s.replace(/(\d)\s+x\s+(?=[\d.(])/gi, "$1 * ").replace(/(\d)\s+over\s+(?=[\d.(])/gi, "$1 / ");

  // Money by its street names. "rand" beside a number is the currency, alone it is qalc's
  // random number; "pounds" is sterling only when the other side is money too.
  s = s.replace(/\bquid\b/gi, "GBP").replace(/\bbucks?\b/gi, "USD");
  s = s.replace(/(\d\s*)rands?\b/gi, "$1ZAR").replace(/\b(to|in|into|as)\s+rands?$/i, "$1 ZAR");
  if (MONEY.test(s))
    s = s.replace(/\bpounds?(?: sterling)?\b/gi, "GBP");

  // Temperatures. "10c to f" is coulombs to farads to qalc.
  s = s.replace(/\bdegrees?\s+(?=(?:fahrenheit|celsius|centigrade|kelvin|[cfk])\b)/gi, "").replace(/\bcentigrade\b/gi, "celsius");

  // Conversions. "in" and "as" convert when a quantity is on their left and only a unit on
  // their right; otherwise "in" is the inch it is to qalc ("2 in + 3 in").
  s = s.replace(/\s+into\s+/gi, " to ");
  m = s.match(/^(.*\d.*)\s+(?:in|as)\s+(.+)$/i);
  if (m && !/(?:^|[\s(])[\d.]/.test(m[2]))
    s = m[1] + " to " + m[2];

  s = s.replace(/^(-?[\d.]+)\s*°?([cfk])\s+to\s+°?([cfk])$/i, function (_, n, a, b) {
    var unit = function (u) {
      u = u.toLowerCase();
      return u === "k" ? "K" : "°" + u.toUpperCase();
    };
    return n + " " + unit(a) + " to " + unit(b);
  });

  return s;
}
