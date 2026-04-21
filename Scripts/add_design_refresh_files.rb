#!/usr/bin/env ruby
# Adds new Swift source files created during the design refresh to the Xcode project.
# Idempotent: skips files already referenced.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../PixelColoringGame.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == 'PixelColoringGame' }
abort 'PixelColoringGame target not found' unless target

# Group: Features
features_group = project.main_group['PixelColoringGame']['Features']
utilities_group = project.main_group['PixelColoringGame']['Utilities']
abort 'Utilities group not found' unless utilities_group
abort 'Features group not found' unless features_group

def find_or_create_group(parent, name)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name }
  return existing if existing
  parent.new_group(name, name)
end

components_group = find_or_create_group(features_group, 'Components')
title_group = find_or_create_group(features_group, 'Title')
root_group = find_or_create_group(features_group, 'Root')
daily_group = find_or_create_group(features_group, 'Daily')
journey_group = features_group['Journey'] || abort('Journey group missing')
sections_group = find_or_create_group(journey_group, 'Sections')

# files_to_add: [absolute_path, group, name]
files_to_add = [
  # Utilities
  ['PixelColoringGame/Utilities/IconAsset.swift', utilities_group],
  ['PixelColoringGame/Utilities/DesignSystem.swift', utilities_group],
  # Components
  ['PixelColoringGame/Features/Components/CozyCard.swift', components_group],
  ['PixelColoringGame/Features/Components/PrimaryActionButton.swift', components_group],
  ['PixelColoringGame/Features/Components/HomeBadgeLabel.swift', components_group],
  # Journey/Sections
  ['PixelColoringGame/Features/Journey/Sections/JourneyTopBar.swift', sections_group],
  ['PixelColoringGame/Features/Journey/Sections/LifeStatusView.swift', sections_group],
  # Daily
  ['PixelColoringGame/Features/Daily/DailyChallengeHeroCard.swift', daily_group],
  ['PixelColoringGame/Features/Daily/StreakAndBadgeCard.swift', daily_group],
  ['PixelColoringGame/Features/Daily/DailyHubView.swift', daily_group],
  # Title
  ['PixelColoringGame/Features/Title/TitleScreenView.swift', title_group],
  # Root
  ['PixelColoringGame/Features/Root/RootTabView.swift', root_group],
  ['PixelColoringGame/Features/Root/TabTopStrip.swift', root_group],
]

added = []
skipped = []

files_to_add.each do |relative_path, group|
  file_name = File.basename(relative_path)
  already = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) && c.display_name == file_name }
  if already
    skipped << file_name
    next
  end

  # path relative to the parent group
  parent_dir = File.dirname(relative_path).split('/').last
  # We just set path as the file name and rely on the group's own path segment.
  ref = group.new_reference(file_name)
  ref.source_tree = '<group>'
  ref.last_known_file_type = 'sourcecode.swift'

  target.add_file_references([ref])
  added << file_name
end

project.save
puts "Added: #{added.join(', ')}" unless added.empty?
puts "Skipped (already present): #{skipped.join(', ')}" unless skipped.empty?
