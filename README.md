# ArmchyOS packages

Pacman repo for ArmchyOS: Arch Linux ARM with KDE Plasma on the 14" MacBook Pro M5 Pro (J714s).
It sits on top of the aurora-silicon kernel, m1n1 and Mesa.

```ini
[armchy]
Server = https://github.com/ItsPhysip/ArmchyOS-pkgs/releases/download/aarch64
```

Trust the signing key first:

```sh
curl -LO https://github.com/ItsPhysip/ArmchyOS-pkgs/raw/main/armchy.asc
sudo pacman-key --add armchy.asc
sudo pacman-key --lsign-key 4CC41104BE25A5D8D3BEACB05736AE5DCF41C9ED
```

Each folder is one package. `build.sh` builds and signs them all; `publish.sh` uploads the result.

Firmware isn't here. It's Apple's, so it's extracted from macOS on the machine itself.
