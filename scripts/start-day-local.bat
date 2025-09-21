@echo off
REM RSOC — Start Day Local (Windows)

echo == Git pull ==
git pull

echo == Quickstart Local ==
call scripts\quickstart-local.bat

REM אחרי שהשרת רץ, פותחים חלון שני להריץ curl
REM (או תריץ ידנית בחלון נפרד)
