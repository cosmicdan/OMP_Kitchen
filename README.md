# CosmicDan's MIUI Kitchen



## Required binaries/packages:

* brotli
* simg2img

E.g:

`sudo apt install brotli android-tools-fsutils`



## Building

Run `./build.sh` to see options for building ROM's in one swoop, or the other .sh scripts for individual tasks.

### Notes about building ROM's

- Be sure you have placed an appropriate base_device and base_port ROM in those folders first (see their readme's)
- For the release stage (generating a flashable ZIP), it is assumed that the original base_device ROM was using brotli compression (e.g. system.new.dat.br) as that is what the target output will be. Pretty sure all Xiaomi ROM's are brotli these days.



## Credits and Thanks

- https://github.com/wuxianlin/sefcontext_decompile
  file_contexts.bin decompiler
- https://github.com/jamflux/make_ext4fs
  make_ext4fs