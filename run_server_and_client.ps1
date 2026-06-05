$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Start-Process godot -WorkingDirectory $ProjectPath -ArgumentList @(
	"--path", ".",
	"--scene", "res://scripts/server/server_scene.tscn"
)

Start-Sleep -Milliseconds 500

Start-Process godot -WorkingDirectory $ProjectPath -ArgumentList @(
	"--path", ".",
	"--scene", "res://scripts/client/client_scene.tscn"
)
