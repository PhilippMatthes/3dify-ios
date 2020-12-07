platform :ios, "14.0"


target "3Dify" do
  use_frameworks!

  pod "SwiftRater"

  # Development dependencies
  pod "SwiftLint"
end


# Some pods may use a deployment target which is no
# longer supported by the current XCode version, so
# we must simply raise the deployment target
post_install do |pi|
  pi.pods_project.targets.each do |t|
      t.build_configurations.each do |bc|
        deployment_target = bc.build_settings["IPHONEOS_DEPLOYMENT_TARGET"]
        if deployment_target == "8.0"
          puts "Warning: the build target #{t} uses iOS 8.0 as its " +
               "deployment target. XCode does not support this " +
               "target anymore. We will raise the deployment target " +
               "manually to avoid compiler warnings.\n" +
               "Consider updating this target."
          bc.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "9.0"
        else
          puts "Target #{t} uses the deployment target " +
               "iOS #{deployment_target}. "
        end
      end
  end
end
