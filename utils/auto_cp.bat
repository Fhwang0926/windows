@echo off
setlocal

echo starting copy...

net use Y: "\\host.lan\download" /persistent:no
robocopy "Y:" "%USERPROFILE%\Downloads" /E /MOV
net use Y: /delete

sc stop nfs

echo copy complete.

endlocal