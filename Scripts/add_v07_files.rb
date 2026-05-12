#!/usr/bin/env ruby
# Adds v0.7 Feel Good Update files (Celebration system + AnimationProfile + DebugMenu) to the Xcode project.
# Idempotent: skips files already referenced.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../PixelColoringGame.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

app_target = project.targets.find { |t| t.name == 'PixelColoringGame' }
tests_target = project.targets.find { |t| t.name == 'PixelColoringGameTests' }
abort 'PixelColoringGame target not found' unless app_target
abort 'PixelColoringGameTests target not found' unless tests_target

def find_or_create_group(parent, name)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name }
  return existing if existing
  parent.new_group(name, name)
end

# Source groups
features_group = project.main_group['PixelColoringGame']['Features']
utilities_group = project.main_group['PixelColoringGame']['Utilities']
tests_root_group = project.main_group['PixelColoringGameTests']

abort 'Features group missing' unless features_group
abort 'Utilities group missing' unless utilities_group
abort 'Tests root group missing' unless tests_root_group

celebration_group = find_or_create_group(features_group, 'Celebration')
debug_group = find_or_create_group(features_group, 'Debug')
tests_celebration_group = find_or_create_group(tests_root_group, 'Celebration')

# files_to_add: [absolute_path_from_repo_root, group, target]
files_to_add = [
  # Utilities
  ['PixelColoringGame/Utilities/AnimationProfile.swift', utilities_group, app_target],
  # Celebration
  ['PixelColoringGame/Features/Celebration/CelebrationEvent.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/CelebrationDetector.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/CelebrationCoordinator.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/CelebrationFlowState.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/ParticleEmitterView.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/ChapterClearView.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/JourneyCompleteView.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/MonthlyCompleteView.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/MilestoneToastView.swift', celebration_group, app_target],
  ['PixelColoringGame/Features/Celebration/MilestoneToastHost.swift', celebration_group, app_target],
  # Debug
  ['PixelColoringGame/Features/Debug/DebugMenuView.swift', debug_group, app_target],
  # Tests
  ['PixelColoringGameTests/Celebration/AnimationProfileTests.swift', tests_celebration_group, tests_target],
  ['PixelColoringGameTests/Celebration/CelebrationDetectorTests.swift', tests_celebration_group, tests_target],
  ['PixelColoringGameTests/Celebration/CelebrationCoordinatorTests.swift', tests_celebration_group, tests_target],
  ['PixelColoringGameTests/Celebration/CelebrationsSeenStorageTests.swift', tests_celebration_group, tests_target],
]

added = []
skipped = []
missing_files = []

files_to_add.each do |relative_path, group, target|
  file_name = File.basename(relative_path)
  full_path = File.join(File.dirname(PROJECT_PATH), relative_path)
  unless File.exist?(full_path)
    missing_files << relative_path
    next
  end

  already = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) && c.display_name == file_name }
  if already
    # Ensure target membership
    in_target = target.source_build_phase.files.any? { |bf| bf.file_ref&.uuid == already.uuid }
    unless in_target
      target.add_file_references([already])
      added << "#{file_name} (target only)"
    else
      skipped << file_name
    end
    next
  end

  ref = group.new_reference(file_name)
  ref.source_tree = '<group>'
  ref.last_known_file_type = 'sourcecode.swift'

  target.add_file_references([ref])
  added << file_name
end

project.save
puts "Added: #{added.join(', ')}" unless added.empty?
puts "Skipped (already present in target): #{skipped.join(', ')}" unless skipped.empty?
puts "Missing on disk (skipped): #{missing_files.join(', ')}" unless missing_files.empty?
