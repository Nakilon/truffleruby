# -*- encoding: utf-8 -*-
# stub: digest 3.1.1 ruby lib
# stub: ext/digest/bubblebabble/extconf.rb ext/digest/extconf.rb ext/digest/md5/extconf.rb ext/digest/rmd160/extconf.rb ext/digest/sha1/extconf.rb ext/digest/sha2/extconf.rb

Gem::Specification.new do |s|
  s.name = "digest".freeze
  s.version = "3.1.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "msys2_mingw_dependencies" => "openssl" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Akinori MUSHA".freeze]
  s.bindir = "exe".freeze
  s.date = "2025-01-15"
  s.description = "Provides a framework for message digest libraries.".freeze
  s.email = ["knu@idaemons.org".freeze]
  s.extensions = ["ext/digest/bubblebabble/extconf.rb".freeze, "ext/digest/extconf.rb".freeze, "ext/digest/md5/extconf.rb".freeze, "ext/digest/rmd160/extconf.rb".freeze, "ext/digest/sha1/extconf.rb".freeze, "ext/digest/sha2/extconf.rb".freeze]
  s.files = ["digest.#{Truffle::Platform::DLEXT}".freeze, "digest.rb".freeze, "digest/loader.rb".freeze, "digest/version.rb".freeze, "ext/digest/bubblebabble/extconf.rb".freeze, "ext/digest/extconf.rb".freeze, "ext/digest/md5/extconf.rb".freeze, "ext/digest/rmd160/extconf.rb".freeze, "ext/digest/sha1/extconf.rb".freeze, "ext/digest/sha2/extconf.rb".freeze]
  s.homepage = "https://github.com/ruby/digest".freeze
  s.licenses = ["Ruby".freeze, "BSD-2-Clause".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.5.22".freeze
  s.summary = "Provides a framework for message digest libraries.".freeze
end
