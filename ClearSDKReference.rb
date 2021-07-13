require 'xcodeproj'


# 外部传入的工程路径
$project_path       = ARGV[0]

$SDK_Folder="ThirdPartySDK"

#获取项目
$project = Xcodeproj::Project.open($project_path);
#获取target
$target = $project.targets.first
# 获取SDK group
$group_One = $project[$SDK_Folder]

if $group_One.nil?
  # puts "don't find group : #{$SDK_Folder}"
  exit 0
end

$isEmbed = false
$target.copy_files_build_phases.each do |copy_build_phases|
    if copy_build_phases.name == "Embed Frameworks"
        $embed_framework = copy_build_phases
    end
end

def removeBuildPhaseFilesRecursively(aTarget, aGroup)
  aGroup.files.each do |file|
      if file.real_path.to_s.end_with?(".m", ".mm", ".cpp") then
          aTarget.source_build_phase.remove_file_reference(file)
      elsif file.real_path.to_s.end_with?(".bundle",".plist" ,".xml",".png",".xib",".js",".html",".css",".strings") then
          aTarget.resources_build_phase.remove_file_reference(file)
      elsif file.real_path.to_s.end_with?(".framework" ,".a")
          aTarget.frameworks_build_phase.remove_file_reference(file)
          # remove embed ref
          if $isEmbed && !$embed_framework.nil?
            $embed_framework.remove_file_reference(file)
          end
      end

      # extra r+emove file ref
      file.remove_from_project
  end
  
  aGroup.groups.each do |group|
      # puts "group path : #{group.path}"
      if group.path == "embed"
          $isEmbed = true
      end
      removeBuildPhaseFilesRecursively(aTarget, group)
      $isEmbed = false
  end
end

if !$group_One.empty? then
    removeBuildPhaseFilesRecursively($target, $group_One)
    $group_One.clear()
    $group_One.remove_from_project
end

# remove framework search path
$Original_FrameWorks_SearchArray = $target.build_settings('Debug')['FRAMEWORK_SEARCH_PATHS']
if !$Original_FrameWorks_SearchArray.nil?
    if $Original_FrameWorks_SearchArray.is_a?(Array)
        $NewFrameworkSearchArray = Array.new()
        $Original_FrameWorks_SearchArray.each do |path|
            if !(path.include? $SDK_Folder)
                $NewFrameworkSearchArray.push(path)
            end
        end
    else
        $NewFrameworkSearchArray = $Original_FrameWorks_SearchArray
    end
end

# remove header search path
$Original_Header_SearchArray = $target.build_settings('Debug')['HEADER_SEARCH_PATHS']
if !$Original_Header_SearchArray.nil?
    if $Original_Header_SearchArray.is_a?(Array)
        $NewHeaderSearchArray = Array.new()
        $Original_Header_SearchArray.each do |path|
            if !(path.include? $SDK_Folder)
                $NewHeaderSearchArray.push(path)
            end
        end
    else
        $NewHeaderSearchArray = $Original_Header_SearchArray
    end
end

['Debug', 'Release', 'Ad-Hoc-Release', 'Enterprise', 'Preview'].each do |config|
  if !$target.build_settings(config).nil?
    $target.build_settings(config)['FRAMEWORK_SEARCH_PATHS'] = $NewFrameworkSearchArray
    $target.build_settings(config)['HEADER_SEARCH_PATHS'] = $NewHeaderSearchArray
    $target.build_settings(config)['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = "NO"
    $target.build_settings(config)['VALIDATE_WORKSPACE'] = "NO"
  end
end


puts 'pbxproj clear done!'
$project.save;
