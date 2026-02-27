# gh-notify demo recording — produces assets/demo.gif
# Requires: vhs (charmbracelet/vhs), gh-notify installed (just sync)
# Usage: vhs demo.tape

Output assets/demo.gif
Set Width 720
Set Height 440
Set FontSize 14
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Setup: deploy scripts and start the event scenario (hidden from recording)
Hide
Type "just sync >/dev/null 2>&1; bash scripts/demo-scenario.sh >/dev/null 2>&1 & disown"
Enter
Sleep 2s
Type "clear"
Enter
Sleep 0.5s
Show

# Launch the bar — this is where the recording begins
Type "gh-notify"
Enter

# Events arrive gradually (scenario writes them with ~1.5s delays)
Sleep 16s

# Demo: toggle sound off
Type "s"
Sleep 2.5s

# Demo: toggle sound back on
Type "s"
Sleep 2.5s

# Quit
Type "q"
Sleep 1s
