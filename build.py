import os

version = "1.3.1"
windows_path = f"%localappdata%/Roblox/Plugins/ResizeAlign {version}.rbxmx"
posix_path = f"~/Documents/Roblox/Plugins/ResizeAlign {version}.rbxmx"

if os.name == "nt":
	os.system(f"rojo build . -o \"{windows_path}\"")
else:
	os.system(f"rojo build . -o \"{posix_path}\"")