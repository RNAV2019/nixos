.pragma library

// The picture for a sung word, where there is an obvious one: "fire" has one, "the" does not.
// No QML imports: tools/lyrics-test.mjs evaluates this file under node.
//
// One line per picture, then every word that shows it. Words are matched whole and in lower
// case, after their endings are tried off (see `lookup`), so "burning" finds "burn". Only things
// are listed: a sign for "up", "never" or "two" reads as noise beside a sung line.
var TABLE = [
  "❤️ love heart lover loving beloved",
  "💔 heartbreak heartbroken broken break hurt hurts ache",
  "🔥 fire burn flame flames blaze hot heat lit",
  "🌙 moon night midnight moonlight tonight",
  "☀️ sun sunshine sunlight sunny daylight",
  "🌅 sunrise sunset dawn dusk morning",
  "⭐ star stars starlight",
  "🌌 sky skies galaxy universe space cosmos heaven heavens",
  "☁️ cloud clouds cloudy",
  "🌧️ rain raining rainy storm pour",
  "⚡ lightning thunder electric shock power",
  "❄️ snow cold ice frozen freeze winter",
  "🌊 ocean sea wave waves tide water river",
  "🌈 rainbow colour colours color colors",
  "🌹 rose roses flower flowers bloom",
  "🍃 leaf leaves wind breeze",
  "🌲 tree trees forest woods",
  "⛰️ mountain mountains hill hills",
  "🏝️ island beach shore",
  "🌍 world earth planet",
  "🏙️ city cities town downtown skyline",
  "🏠 home house",
  "🚪 door doors",
  "🪟 window windows",
  "🛣️ road highway street streets",
  "🚗 car cars drive driving ride",
  "🚆 train trains",
  "✈️ plane fly flying flight",
  "🚀 rocket",
  "⛵ boat ship sail sailing",
  "⏰ time clock hour hours minute",
  "⏳ wait waiting forever",
  "📅 day days today tomorrow yesterday",
  "👀 eyes eye look looking see watch watching stare",
  "👄 lips kiss kissing mouth",
  "🫀 heartbeat pulse",
  "🧠 mind brain think thinking thought thoughts",
  "🤝 together hand hands",
  "🫂 hug embrace arms",
  "🩸 blood bleed bleeding",
  "💀 dead death die dying kill",
  "👻 ghost ghosts haunt haunted",
  "😈 devil demon demons hell",
  "😇 angel angels",
  "🙏 pray prayer praying god lord faith",
  "👑 king queen crown royal",
  "💎 diamond diamonds",
  "💰 money cash rich dollar dollars gold",
  "💍 ring marry wedding",
  "🎁 gift present",
  "🥂 champagne toast cheers",
  "🍷 wine",
  "🥃 whiskey drink drinking drunk",
  "☕ coffee",
  "🚬 smoke smoking cigarette",
  "💊 pill pills",
  "🍬 sugar sweet candy",
  "🍯 honey",
  "🍒 cherry",
  "🍑 peach",
  "🎵 song songs music melody tune sing singing",
  "🎸 guitar",
  "🥁 drum drums beat",
  "🎹 piano",
  "📻 radio",
  "📞 phone call calling",
  "💌 letter",
  "📷 picture photo photograph",
  "🎬 movie film scene",
  "💃 dance dancing dancer",
  "🎉 party celebrate",
  "🎭 play pretend mask",
  "🃏 game games",
  "🏆 win winning winner",
  "🏃 run running runaway",
  "🚶 walk walking",
  "🧗 climb climbing",
  "🪂 fall falling fell",
  "🛌 sleep sleeping bed",
  "💤 dream dreams dreaming",
  "😢 cry crying tears tear",
  "😊 smile smiling happy",
  "😂 laugh laughing",
  "😡 angry anger mad rage",
  "😱 scared afraid fear scream",
  "🥶 freezing",
  "🤫 secret secrets quiet silence hush",
  "👂 hear listen listening",
  "🤥 lie lies liar lying",
  "🤞 hope promise wish",
  "💭 remember memory memories",
  "🕊️ free freedom peace",
  "⛓️ chain chains",
  "🔒 lock locked",
  "🔑 key keys",
  "🔫 gun guns shoot shot",
  "🔪 knife cut",
  "💣 bomb explode",
  "🩹 heal healing",
  "🧨 dynamite",
  "🪞 mirror reflection",
  "🕯️ candle light lights",
  "💡 idea",
  "🌑 dark darkness shadow shadows black",
  "🤍 white",
  "💙 blue",
  "💚 green",
  "💛 yellow",
  "🧡 orange",
  "💜 purple",
  "🩷 pink",
  "🦋 butterfly butterflies",
  "🐦 bird birds",
  "🐺 wolf wolves",
  "🦁 lion",
  "🐍 snake",
  "🐱 cat",
  "🐶 dog",
  "🐎 horse horses",
  "🪶 feather",
  "👶 baby babe",
  "👧 girl",
  "👦 boy",
  "👫 friend friends",
  "👤 stranger alone lonely nobody",
  "🪩 disco club",
  "🧊 cool",
  "🎯 aim",
  "🧭 lost",
  "🗺️ map",
  "🏁 end ending",
  "🌱 grow growing",
  "🪐 saturn",
  "🧲 pull",
  "🫧 bubble bubbles",
  "🌪️ hurricane tornado",
  "🪽 wings wing",
  "🥀 wilt",
  "🧵 thread",
  "🪙 coin",
  "🧶 tangle tangled"
];

var MAP = null;

function build() {
  var map = {};
  TABLE.forEach(function (row) {
    var parts = row.split(" ");
    for (var i = 1; i < parts.length; i++)
      map[parts[i]] = parts[0];
  });
  return map;
}

// The picture for `word`, or "". Endings are tried off in turn: "burnin'", "burning", "burns",
// "burned" all find "burn"; "shining" finds "shine".
function lookup(word) {
  if (MAP === null)
    MAP = build();
  var w = String(word).toLowerCase().replace(/^[^a-z]+|[^a-z']+$/g, "");
  if (w.length < 3)
    return "";
  var tries = [w, w.replace(/'s$/, ""), w.replace(/in'$/, "ing")];
  var base = tries[2];
  tries.push(base.replace(/s$/, ""), base.replace(/es$/, ""), base.replace(/ed$/, ""), base.replace(/d$/, ""));
  tries.push(base.replace(/ing$/, ""), base.replace(/ing$/, "e"), base.replace(/(.)\1ing$/, "$1"));
  for (var i = 0; i < tries.length; i++)
    if (MAP[tries[i]] !== undefined)
      return MAP[tries[i]];
  return "";
}

// Marks every word of a model (Parse.js) that has a picture with it, as `emoji`. A line shows
// a picture once: "let the fire burn slow" has one flame, on "fire".
function annotate(model) {
  model.lines.forEach(function (line) {
    var shown = {};
    line.words.forEach(function (w) {
      var picture = lookup(w.text);
      w.emoji = shown[picture] === true ? "" : picture;
      if (picture !== "")
        shown[picture] = true;
    });
  });
  return model;
}
