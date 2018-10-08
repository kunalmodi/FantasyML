# FantasyML

This is a toy project to learn Swift & CreateML. It scrapes historical football player data and uses CreateML to train a model to predict fantasy football scores. See https://www.kunalmodi.me/activity/predicting-fantasy-football-scores-using-swift--createml for more. 

To use:
```
$ swift package generate-xcodeproj --xcconfig-overrides settings.xcconfig
$ swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.14"
$ for i in {1..4}; do ./.build/x86_64-apple-macosx10.10/debug/FantasyML fetch 2018 $i; done
$ ./.build/x86_64-apple-macosx10.10/debug/FantasyML prepare
$ ./.build/x86_64-apple-macosx10.10/debug/FantasyML train WR 2018 4
$ cat output/results_2018_004_WR.csv | column -t -s, | less -S
```
