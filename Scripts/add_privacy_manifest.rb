#!/usr/bin/env ruby
# Adds PrivacyInfo.xcprivacy to the Xcode project's app target. Idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../PixelColoringGame.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

app_target = project.targets.find { |t| t.name == 'PixelColoringGame' }
abort 'PixelColoringGame target not found' unless app_target

app_group = project.main_group['PixelColoringGame']
abort 'App group not found' unless app_group

file_name = 'PrivacyInfo.xcprivacy'
existing = app_group.children.find { |c|
  c.is_a?(Xcodeproj::Project::Object::PBXFileReference) && c.display_name == file_name
}

if existing
  in_target = app_target.resources_build_phase.files.any? { |bf| bf.file_ref&.uuid == existing.uuid } ||
              app_target.source_build_phase.files.any? { |bf| bf.file_ref&.uuid == existing.uuid }
  if in_target
    puts "Skipped: #{file_name} already in target."
  else
    app_target.add_resources([existing])
    project.save
    puts "Added existing reference to target."
  end
else
  ref = app_group.new_reference(file_name)
  ref.source_tree = '<group>'
  ref.last_known_file_type = 'text.plist.xml'
  app_target.add_resources([ref])
  project.save
  puts "Added: #{file_name}"
end
