# vhs tape for reverse-skill PRIMARY path demo
# Requires: https://github.com/charmbracelet/vhs
#   vhs docs/demo/primary-path.tape
Output docs/assets/primary-path-demo.gif
Set FontSize 15
Set Width 960
Set Height 540
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Set Framerate 20
Set PlaybackSpeed 1.0

Hide
Type "cd reverse-skill"
Enter
Sleep 300ms
Show

Type "# reverse-skill: one sentence → PRIMARY skill + ready case"
Enter
Sleep 400ms
Type "bash skills/scripts/demo-primary-path.sh"
Enter
Sleep 6s
Type "sed -n '1,40p' examples/primary-path-demo/RESULT-CARD.md"
Enter
Sleep 3s
Type "cat examples/primary-path-demo/summary.json"
Enter
Sleep 2s
Type "# done — open examples/primary-path-demo/result-card.html"
Enter
Sleep 2s
