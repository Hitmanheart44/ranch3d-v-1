Drop intro videos here (Theora .ogv):
  promo_e.ogv ... promo_a.ogv   promotion match intro per rank
  cup_<id>.ogv                  one cup's own intro (ids: dustbin, cinder, iron, storm, abyss, summoner)
  match.ogv                     generic pre-match intro
Convert: ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 out.ogv
