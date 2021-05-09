# Development notes

## Building an optimized HTML5 export template

This decreases the file size and makes it faster to load. Most modules are
disabled, except `regex` as it may be useful for testing on the go.

Follow the instructions in the
[Compiling for the Web](https://docs.godotengine.org/en/stable/development/compiling/compiling_for_web.html)
documentation, and use the SCons flags below during the compilation step.

[Builds deployed on gdscript-online.github.io](https://github.com/gdscript-online/gdscript-online.github.io)
use the following SCons flags:

```text
scons \
    platform=javascript \
    tools=no \
    target=release \
    disable_3d=yes \
    progress=no \
    debug_symbols=no \
    module_bmp_enabled=no \
    module_bullet_enabled=no \
    module_csg_enabled=no \
    module_dds_enabled=no \
    module_enet_enabled=no \
    module_etc_enabled=no \
    module_gdnative_enabled=no \
    module_gridmap_enabled=no \
    module_hdr_enabled=no \
    module_mbedtls_enabled=no \
    module_mobile_vr_enabled=no \
    module_opus_enabled=no \
    module_pvr_enabled=no \
    module_recast_enabled=no \
    module_squish_enabled=no \
    module_tga_enabled=no \
    module_thekla_unwrap_enabled=no \
    module_theora_enabled=no \
    module_tinyexr_enabled=no \
    module_vorbis_enabled=no \
    module_webm_enabled=no \
    module_websocket_enabled=no \
    -j$(nproc)
```
