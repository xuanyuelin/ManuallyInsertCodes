#!/usr/bin/ruby
require 'xcodeproj'

#工程路径
# $project_path = '/Users/hb/Desktop/xSimple备份/2017-03-22-Ruby/ios_3.0/baseApp/CORProject/KndCRMv2.xcodeproj'
# path = '/Users/hb/Desktop/xSimple备份/2017-03-22-Ruby/ios_3.0/baseApp/CORModules/ModuleThirdPay';
# 外部传入的工程路径
 $project_path       = ARGV[0]
#path = "CorMobiApp.xcodeproj"
# if path.empty? then puts "没有找到iOS项目，请检查目录文件" end
#$project_path = Dir::pwd + "/" + path
puts "项目路径       = #{$project_path}"
$plugin_folder        = ARGV[1]
puts "插件文件夹名称  = #{$plugin_folder}"
# 外部传入的原生插件文件夹名称
$folderName          = ARGV[2]
puts "插件文件夹名称  = #{$folderName}"

#获取项目
$project = Xcodeproj::Project.open($project_path);
#获取target
$target = $project.targets.first
# 获取插件目录的group，如果不存在则创建
$group_One = $project[$plugin_folder] || $project.main_group.find_subpath(File.join($plugin_folder), true);

puts "项目主目录      = #{$group_One.real_path.to_s}"

# 在目标目录新建group目录
$group = $group_One.find_subpath($folderName, true)

$SDK_PATH = $group_One.real_path.to_s + "/" + $plugin_folder + "/" + $folderName

puts "插入的SDK路径      = #{$SDK_PATH}"

if !FileTest::exists?($SDK_PATH)
    puts "SDK file not found in #{$SDK_PATH}"
    exit 1
end

$group.set_path($SDK_PATH)

# 获取全部的文件引用
$file_ref_list = $target.source_build_phase.files_references

#获取所有静态库文件引用
$framework_ref_list = $target.frameworks_build_phases.files_references

# 获取所有资源文件引用
$bundle_ref_list = $target.resources_build_phase.files_references

#当前项目中所有动态库
$embed_framework = nil;

$target.copy_files_build_phases.each do |copy_build_phases|
    # puts "copy build phase : #{copy_build_phases.name}"
   if copy_build_phases.name == "Embed Frameworks"
        $embed_framework = copy_build_phases;
   # elsif !copy_build_phases.nil? && copy_build_phases.name.nil?
   #      # puts "entried !!!"
   #      $embed_framework = copy_build_phases;
   end
end

if $embed_framework.nil?
    # Add new "Embed Frameworks" build phase to target
    puts "reCreate embed frameworks!!!"
    $embed_frameworks_build_phase = $project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    $embed_frameworks_build_phase.name = 'Embed Frameworks'
    $embed_frameworks_build_phase.symbol_dst_subfolder_spec = :frameworks
    $target.build_phases << $embed_frameworks_build_phase

    $embed_framework = $embed_frameworks_build_phase
end

# puts "dong tai ku == #{$embed_framework_list}"

# 设置文件引用是否存在标识
$file_ref_mark = false
#当前添加库是否为动态库
$isEmbed = false;

# 检测需要添加的文件节点是否存在
def detectionFileExists (fileName)

    if fileName.to_s.end_with?(".framework" ,".a")
        for file_ref_temp in $framework_ref_list
            if file_ref_temp.path.to_s.end_with?(fileName) then
                # $file_ref_mark = true;
                return true;
                break;
            end
        end

    elsif fileName.to_s.end_with?(".plist" ,".bundle",".xml",".png",".xib",".strings")
        for file_ref_temp in $bundle_ref_list
            if file_ref_temp.path.to_s.end_with?(fileName) then
                # $file_ref_mark = true;
                return true;

            end
        end
    elsif fileName.to_s.include?("__MACOSX")
 
            return true;
    else
        for file_ref_temp in $file_ref_list
            if file_ref_temp.path.to_s.end_with?(fileName) then
                # $file_ref_mark = true;
                return true;
            end
            end
    end



end

# 添加文件xcode工程
def addFilesToGroup(aproject,aTarget,aGroup)
    
    # puts "group_path : #{aGroup}"
    puts "Group-path : #{aGroup.real_path.to_s}"
    
    
    Dir.foreach (aGroup.real_path) do |entry|
        filePath = File.join(aGroup.real_path,entry);

        # 判断文件是否是以.或者.DS_Store结尾，如果是则执行下一个循环
        if entry.to_s.end_with?(".") or entry.to_s.end_with?(".DS_Store") or entry.to_s == "info.xml" or entry.to_s == "IDE" or entry.to_s == ".svn" or entry.to_s == "__MACOSX"
            next;
        end
        
        # 判断文件节点是否存在
        $file_ref_mark = detectionFileExists(entry);
        # 如果当前文件节点存在则执行下一个
        if $file_ref_mark == true
            next
        end

        # puts " aGroup 路径 = #{aGroup}"
        
        # 判断文件是否为framework或者.a静态库
        if filePath.to_s.end_with?(".framework" ,".a")
            fileReference = aGroup.new_reference(filePath);
            build_phase = aTarget.frameworks_build_phase;
            build_phase.add_file_reference(fileReference);
            if $isEmbed == true
                #添加动态库
                $embed_framework.add_file_reference(fileReference)
                #勾上code sign on copy选项（默认是没勾上的）
                $embed_framework.files.each do |file|
                    # puts "entry filePath : #{filePath} fileRef path : #{file.file_ref.path}"
                    if filePath.end_with?(file.file_ref.path) then
                        if file.settings.nil? then
                            # puts "setting is nil"
                            file.settings = Hash.new
                        end
                        file.settings["ATTRIBUTES"] = ["CodeSignOnCopy", "RemoveHeadersOnCopy"]
                    end
                end
            end

        # 如果文件问bundle文件
        elsif filePath.to_s.end_with?(".bundle",".plist" ,".xml",".png",".xib",".js",".html",".css",".strings")
            fileReference = aGroup.new_reference(filePath);
            aTarget.resources_build_phase.add_file_reference(fileReference, true)
        # 如果路径不为文件夹
        elsif filePath.to_s.end_with?("pbobjc.m", "pbobjc.mm") then
            fileReference = aGroup.new_reference(filePath);
            aTarget.add_file_references([fileReference], '-fno-objc-arc')
        # .h文件需额外引用
        elsif filePath.to_s.end_with?(".h") then
            fileReference = aGroup.new_reference(filePath);
            # aTarget.source_build_phase.add_file_reference(fileReference, true)

        elsif filePath.to_s.end_with?(".m", ".mm", ".cpp") then
            fileReference = aGroup.new_reference(filePath);
            aTarget.source_build_phase.add_file_reference(fileReference, true)

        elsif File.directory?(filePath)
            subGroup = aGroup.new_group(entry);
            subGroup.set_source_tree(aGroup.source_tree)
            group_Path = aGroup.real_path.to_s + "/" + entry;
            subGroup.set_path(group_Path )
            if entry == "embed"
                # puts "dong tai ku"
                $isEmbed = true;
            end
            addFilesToGroup(aproject, aTarget, subGroup)
            $isEmbed = false;
        end
    end
end

puts "正在添加SDK : #{$folderName}"
addFilesToGroup($project ,$target ,$group);
puts "库引用添加完成"

# Add CustomSDK path to target Dir::pwd
$LINK_FRAMEWORK_PATH = "${PROJECT_DIR}" + "/#{$plugin_folder}/#{$folderName}"
$EMBED_FRAMEWORK_PATH = "${PROJECT_DIR}" + "/#{$plugin_folder}/#{$folderName}/embed"

# Add frameWork searchPath
$Original_FrameWorks_SearchArray = $target.build_settings('Debug')['FRAMEWORK_SEARCH_PATHS']
if $Original_FrameWorks_SearchArray.nil? 
    $Original_FrameWorks_SearchArray = Array.new()
elsif $Original_FrameWorks_SearchArray.is_a?(String)
    $tmpStr = $Original_FrameWorks_SearchArray
    $Original_FrameWorks_SearchArray = Array.new()
    $Original_FrameWorks_SearchArray.push($tmpStr)
end

if !($Original_FrameWorks_SearchArray.include? $LINK_FRAMEWORK_PATH)
    $Original_FrameWorks_SearchArray.push($LINK_FRAMEWORK_PATH)
end
if !($Original_FrameWorks_SearchArray.include? $EMBED_FRAMEWORK_PATH)
    $Original_FrameWorks_SearchArray.push($EMBED_FRAMEWORK_PATH)
end

# Add header searchPath
$Original_Header_SearchArray = $target.build_settings('Debug')['HEADER_SEARCH_PATHS']
if $Original_Header_SearchArray.nil? 
    $Original_Header_SearchArray = Array.new()
elsif $Original_Header_SearchArray.is_a?(String)
    $tmpString = $Original_Header_SearchArray
    $Original_Header_SearchArray = Array.new()
    $Original_Header_SearchArray.push($tmpString)
end

if !($Original_Header_SearchArray.include? $LINK_FRAMEWORK_PATH)
    $Original_Header_SearchArray.push($LINK_FRAMEWORK_PATH)
end
if !($Original_Header_SearchArray.include? $EMBED_FRAMEWORK_PATH)
    $Original_Header_SearchArray.push($EMBED_FRAMEWORK_PATH)
end

#如果添加的插件是深圳湾导航SDK，则设置ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES为YES
$Should_Embbed_Swift_Lib = "NO"
if $folderName == "Navigator"
    $Should_Embbed_Swift_Lib = "YES"
end

#如果添加了有赞商城，则设置Validate_Workspace为YES
$Should_Validate_Workspace = "NO"
if $folderName == "youzan"
    $Should_Validate_Workspace = "YES"
end

['Debug', 'Release', 'Ad-Hoc-Release', 'Enterprise', 'Preview'].each do |config|
  if !$target.build_settings(config).nil?
      # 追加framework search path
      $target.build_settings(config)['FRAMEWORK_SEARCH_PATHS'] = $Original_FrameWorks_SearchArray
      # 追加header_search_path
      $target.build_settings(config)['HEADER_SEARCH_PATHS'] = $Original_Header_SearchArray
      # 追加runpath_search_path 不然找不到动态库
      $target.build_settings(config)['LD_RUNPATH_SEARCH_PATHS'] = "$(inherited) @executable_path/Frameworks"

      if $target.build_settings(config)['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] == "NO" && $Should_Embbed_Swift_Lib == "YES"
        puts "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES --- > YES"
        $target.build_settings(config)['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = "YES"
      end
      if ($target.build_settings(config)['VALIDATE_WORKSPACE'] == "NO" || $target.build_settings(config)['VALIDATE_WORKSPACE'].nil?) && $Should_Validate_Workspace == "YES"
        puts "Validate_Workspace --- > YES"
        $target.build_settings(config)['VALIDATE_WORKSPACE'] = "YES"
      end
  end
end

$project.save;
puts 'pbxproj文件保存成功'
