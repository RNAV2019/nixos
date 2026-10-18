// Shared by the page script and the PDF viewer: how many leading letters of a word to bold.
globalThis.bionicFixation = (length) => (length <= 3 ? 1 : Math.ceil(length * 0.4));

// Scripts written without spaces between words, where a "word start" means nothing.
globalThis.bionicUnsegmented =
  /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}\p{Script=Thai}\p{Script=Lao}\p{Script=Khmer}\p{Script=Myanmar}]/u;
