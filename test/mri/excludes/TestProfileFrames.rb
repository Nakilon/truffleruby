exclude :test_ifunc_frame, "| <internal:core> core/kernel.rb:269:in `require': cannot load such file -- c/debug (LoadError)"
exclude :test_matches_backtrace_locations_main_thread, "undefined symbol: rb_profile_frames"
exclude :test_profile_frames, "undefined symbol: rb_profile_frames"
exclude :test_profile_thread_frames, "dyld: missing symbol called"
