_:

{
  # ThinkPad Z16 Specific Niri Optimizations (Home Manager)
  programs.niri.settings = {
    # Force Niri to use the Integrated GPU (680M) for the compositor.
    # On the Z16, this is typically /dev/dri/renderD128.
    # This keeps the Discrete GPU (6500M) powered down until explicitly requested.
    debug.render-drm-device = "/dev/dri/renderD128";
  };
}
