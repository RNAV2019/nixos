# Lectern lecture-notes reader (~/Projects/lectern). Notes live in ~/Documents/gen-notes.
{repoDir, ...}: {
  programs.lectern = {
    enable = true;
    palettePath = "${repoDir}/home/quickshell/Commons/palettes.json";
  };
}
