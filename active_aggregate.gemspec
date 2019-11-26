# -*- encoding: utf-8 -*-
# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "active_aggregate"
  s.version = "0.0.2"
  s.date = "2019-11-25"
  s.summary = "active_aggregate is a little helper support to queries by mongoDB aggregate more easily"
  s.description = "A toolkit for building queries like ActiveRelation. Rich support for more flexible merge conditions, states"
  s.homepage = "https://github.com/phantien133/active_aggregate"
  s.files = Dir["lib/**/*", "README.md"]

  s.required_ruby_version = '>= 2.2.3'
  s.authors = ['Phan Quang Tien']

  s.require_paths = ["lib"]

  s.add_dependency("mongoid", ">= 5.0.1")
end
