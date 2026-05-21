_:

{
  # EasyEffects dconf settings: Logic for hardware tracking
  # Configures EasyEffects to dynamically track the default system source and
  # process only the default playback/capture streams. This prevents stale
  # PCI device lookups and reduces overhead.
  dconf.settings = {
    "com/github/wwmm/easyeffects" = {
      use-default-input-device = true;
      use-default-output-device = true;
      process-all-inputs = true;
      process-all-outputs = false;
      last-used-input-preset = "Z16-Conference-Mic";
      last-used-output-device = "";
      last-used-input-device = "";
      output-blocklist = [ ];
      input-blocklist = [ ];
    };
  };
}
