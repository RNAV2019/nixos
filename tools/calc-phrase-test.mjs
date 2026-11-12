#!/usr/bin/env node
// calc-phrase-test.mjs — the launcher calculator's phrasings, run through
// home/quickshell/Commons/CalcPhrase.js and then qalc, as Services/Calculator.qml does.
//
//   node tools/calc-phrase-test.mjs        every case; exits 1 if one fails
//   node tools/calc-phrase-test.mjs -v     also prints what each query was rewritten to
//   node tools/calc-phrase-test.mjs FILE   a CalcPhrase.js other than this checkout's
//
// `nix flake check` runs it as checks.calc-phrases.
//
// A case is [query, answer]: the answer is what qalc must print after its "=" or "≈". A
// RegExp answer is for results that move (exchange rates); null means the query must be left
// exactly as typed.
import {execFileSync} from "node:child_process";
import {mkdirSync, mkdtempSync, readFileSync, writeFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {dirname, join} from "node:path";
import {fileURLToPath} from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const library = process.argv.slice(2).find(a => !a.startsWith("-")) || join(here, "../home/quickshell/Commons/CalcPhrase.js");
const source = readFileSync(library, "utf8").replace(/^\.pragma library\s*$/m, "");
const phrase = new Function(source + "\nreturn {rewrite, hasNumber, strip, qalcConfig};")();

const home = mkdtempSync(join(tmpdir(), "calc-phrase-"));
mkdirSync(join(home, "qalculate"));
writeFileSync(join(home, "qalculate/qalc.cfg"), phrase.qalcConfig);

function qalc(expr) {
  let out;
  try {
    out = execFileSync("qalc", ["-m", "1000", expr], {
      env: {...process.env, XDG_CONFIG_HOME: home, XDG_DATA_HOME: join(home, "data")},
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (e) {
    return {error: String(e.message).split("\n")[0]};
  }
  const lines = out.split("\n").filter(l => l.trim().length > 0);
  const error = lines.find(l => /^error:/.test(l));
  if (error) return {error};
  const last = lines.filter(l => !/^warning:/.test(l)).pop() || "";
  const cut = Math.max(last.lastIndexOf(" = "), last.lastIndexOf(" ≈ "));
  return {read: cut >= 0 ? last.slice(0, cut) : "", value: cut >= 0 ? last.slice(cut + 3) : last};
}

const money = /^[£$€¥]?[\d.]+$|^[A-Z]{3} [\d.]+$|^[\d.]+ [A-Z]{3}$/;

const cases = [
  // Plain maths is left alone.
  ["12 + 8 * 90", "732"],
  ["12*(3+4)", "84"],
  ["2^10", "1024"],
  ["sqrt(144)", "12"],
  ["5 km to miles", /^3\.10685/],
  ["2 in + 3 in", "5 in"],
  ["3 in", null],
  ["1.5 hours + 45 min", "135 min"],
  ["mean(3, 5, 10)", "6"],
  ["10 mod 3", "1"],
  ["rand()", null],

  // Conversions said with "in", "as" and "into".
  ["5 km in miles", /^3\.10685/],
  ["5 km as miles", /^3\.10685/],
  ["5 km into miles", /^3\.10685/],
  ["5 in in cm", "12.7 cm"],
  ["12 stone in kg", /^76\.2035/],
  ["7 feet 2 inches in cm", "218.44 cm"],
  ["3 hours 20 minutes in seconds", "12000 s"],
  ["30 mph in km/h", "48.28032 km/h"],
  ["10c to f", "50 °F"],
  ["72 f in c", /^22\.2222/],
  ["72 degrees fahrenheit in celsius", /^22\.2222/],

  // Money.
  ["100 usd in gbp", money],
  ["100 dollars in pounds", money],
  ["50 quid in euros", money],
  ["20 bucks in yen", money],
  ["100 usd in rand", money],
  ["500 rand in dollars", money],
  ["100 pounds in kg", /^45\.3592/],

  // Asking, and saying the operators.
  ["what is 12 times 12", "144"],
  ["what's 12 x 12?", "144"],
  ["calculate 10 divided by 4", "2.5"],
  ["10 over 4", "2.5"],
  ["12 plus 8 times 90", "732"],
  ["100 minus 1", "99"],
  ["minus 5 plus 2", "−3"],
  ["3 squared", "9"],
  ["2 cubed plus 1", "9"],
  ["2 to the power of 10", "1024"],
  ["2 raised to 10", "1024"],
  ["2 to the 10th power", "1024"],
  ["1,234 + 1", "1235"],
  ["12 + 3 =", "15"],

  // Numbers in words.
  ["two hundred plus fifty", "250"],
  ["five plus three times two", "11"],
  ["twenty-one times two", "42"],
  ["a hundred and five minus five", "100"],
  ["one million two hundred thousand over 1000", "1200"],
  ["ten km in miles", /^6\.2137/],

  // Percentages and shares.
  ["what is 15% of 80", "12"],
  ["15 percent of 80", "12"],
  ["20% off 150", "120"],
  ["150 plus 20%", "180"],
  ["150 + 20%", "180"],
  ["150 less 20%", "120"],
  ["tip 18% on 64.50", "11.61"],
  ["18% tip on 64.50", "11.61"],
  ["what percent of 80 is 20", "25%"],
  ["20 as a percentage of 80", "25%"],
  ["20 is what percent of 80", "25%"],
  ["half of 340", "170"],
  ["a third of 90", "30"],
  ["two thirds of 90", "60"],
  ["a quarter of 3 km", "750 m"],
  ["double 45", "90"],
  ["split 120 between 5", "24"],
  ["split 120 between 5 people", "24"],

  // Functions by name.
  ["square root of 144", "12"],
  ["sqrt 144", "12"],
  ["2 plus square root of 16", "6"],
  ["cube root of 27", "3"],
  ["log base 2 of 1024", "10"],
  ["natural log of 1", "0"],
  ["5 factorial", "120"],
  ["factorial of 5", "120"],
  ["average of 3, 5 and 10", "6"],
  ["mean of 3 5 10", "6"],
  ["median of 1, 2 and 30", "2"],
  ["sum of 1 to 100", "5050"],
  ["sum of 3, 5 and 10", "18"],

  // Questions about quantities.
  ["how many seconds in a day", "86400 s"],
  ["how many inches in 2 metres", /^78\.7401/],
  ["how many miles is 5 km", /^3\.10685/],
  ["how many days are there in a year", /^365\.2/],
];

// Whether a wordy query counts as carrying a number, which is what lets it reach qalc from
// the unscoped launcher.
const numbered = [
  ["two hundred plus fifty", true],
  ["half of ten", true],
  ["half life", false],
  ["firefox", false],
  ["onenote", false],
  ["what is", false],
];

const verbose = process.argv.includes("-v");
let failed = 0;

for (const [query, want] of cases) {
  const expr = phrase.rewrite(query);
  let ok, got;
  if (want === null) {
    ok = expr === query;
    got = expr;
  } else {
    const r = qalc(expr);
    got = r.error || r.value;
    ok = !r.error && (want instanceof RegExp ? want.test(r.value) : r.value === want);
  }
  if (!ok) failed++;
  if (!ok || verbose) console.log(`${ok ? "ok  " : "FAIL"}  ${query}  →  ${expr}  →  ${got}${ok ? "" : `   (wanted ${want})`}`);
}

for (const [query, want] of numbered) {
  const got = phrase.hasNumber(query);
  if (got !== want) {
    failed++;
    console.log(`FAIL  hasNumber(${JSON.stringify(query)}) is ${got}`);
  }
}

console.log(failed === 0 ? `${cases.length + numbered.length} cases pass` : `${failed} of ${cases.length + numbered.length} cases failed`);
process.exit(failed === 0 ? 0 : 1);
