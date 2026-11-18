// Firefox defaults from the dotfiles. install.sh copies this file into
// /etc/firefox-esr/ (or /etc/firefox/), where Firefox reads every .js file as
// default prefs; about:config can still change them per profile.

// Fullscreen video fills the Firefox window instead of asking bspwm for
// fullscreen. In monocle (Super+Tab / Super+Return) the window already fills
// the screen, so it looks the same, but switching to another window (Super+T)
// leaves the video fullscreen instead of exiting it.
pref("full-screen-api.ignore-widgets", true);
