Pod::Spec.new do |s|

  s.name = 'QuickPhotoViewer'
  s.version = '1.0.2'
  s.license = 'MIT'
  s.summary = 'A simple PhotoViewer'

  s.homepage = 'https://github.com/JayZhao/QuickPhotoViewer'
  s.author = { 'StormXX' => 'liaozhaoxing@gmail.com' }

  s.source = {
    :git => 'https://github.com/JayZhao/QuickPhotoViewer.git',
    :tag => '1.0.2'
  }
  s.source_files = ["QuickPhotoViewer/*.swift", "QuickPhotoViewer/QuickPhotoViewer.h"]

  s.platform = :ios, '10.0'
  s.requires_arc = true

  s.frameworks = 'UIKit' 

  s.dependency 'Kingfisher', '~> 4.0'
end