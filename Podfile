def all_pods
	# Top level pods
	pod 'libSub', :path => "Frameworks/libSub/libSub.podspec"
	pod 'HockeySDK'
	pod 'JASidePanels', '~> 1.3.2', :inhibit_warnings => true
	pod 'MBProgressHUD', '~> 0.9.2'
	pod 'SnapKit', '~> 0.15.0'

	# Pods from libSub that have annoying warnings
	pod 'TBXML', :inhibit_warnings => true
	pod 'ZipKit', :inhibit_warnings => true
	pod 'MKStoreKit', :inhibit_warnings => true

	# Allow Swift code in pods
	use_frameworks!
end

target 'iSub Release' do
	all_pods
end

target 'iSub Lite Release' do
	all_pods
end

target 'iSub Beta' do
	all_pods
end

