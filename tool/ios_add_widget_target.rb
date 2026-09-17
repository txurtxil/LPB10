# tool/ios_add_widget_target.rb - Cablea la extension LmBatteryWidget en el
# proyecto Xcode (v161). Se ejecuta UNA vez por clone desde la raiz del repo:
#
#   ruby tool/ios_add_widget_target.rb
#
# Es idempotente: si el target ya existe, solo repara ajustes y entitlements.
# Requiere la gema xcodeproj (la instala CocoaPods; si falta:
#   gem install xcodeproj --user-install
# ).
#
# Lo que hace:
#   1. Runner: CODE_SIGN_ENTITLEMENTS -> Runner/Runner.entitlements (App Group)
#   2. Crea el target LmBatteryWidget (app extension, iOS 14) con su Swift
#   3. Dependencia Runner -> widget + fase "Embed App Extensions"
#   4. Ajustes de build del widget (bundle id, entitlements, Info.plist)
#
# No toca signing: CODE_SIGN_STYLE=Automatic y hereda DEVELOPMENT_TEAM de
# Runner si lo tuviera. Si la cuenta de Apple es gratuita y Xcode no permite
# App Groups, el widget no compilara para dispositivo: hace falta cuenta de
# desarrollador de pago para el entitlement com.apple.security.application-groups.

require 'xcodeproj'

WIDGET = 'LmBatteryWidget'
APP_GROUP = 'group.com.txurtxil.lpb10'
BUNDLE_ID = "com.txurtxil.lpb10.#{WIDGET}"

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'ERROR: no existe el target Runner'

# 1. Entitlements de Runner (App Group compartido con la extension)
runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

widget = project.targets.find { |t| t.name == WIDGET }
if widget.nil?
  widget = project.new_target(:app_extension, WIDGET, :ios, '14.0')

  group = project.main_group.new_group(WIDGET, WIDGET)
  swift = group.new_file("#{WIDGET}.swift")
  widget.add_file_references([swift])

  # Dependencia + fase "Embed App Extensions" para que el .appex viaje
  # dentro de Runner.app/PlugIns
  runner.add_dependency(widget)
  embed = runner.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
  if embed.nil?
    embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed.name = 'Embed App Extensions'
    embed.symbol_dst_subfolder_spec = :plug_ins
    # ANTES de "Thin Binary" (script de Flutter), nunca al final: la fase de
    # copia escribe en Runner.app y Thin Binary tambien; si el embed queda
    # detras, Xcode detecta un ciclo y el build falla ("Cycle inside Runner",
    # error real del workflow build-ios.yml el 17/09/2026).
    idx = runner.build_phases.index { |ph| ph.respond_to?(:name) && ph.name == 'Thin Binary' }
    if idx
      runner.build_phases.insert(idx, embed)
    else
      runner.build_phases << embed
    end
  end
  bf = embed.add_file_reference(widget.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
end

team = runner.build_configurations
             .map { |c| c.build_settings['DEVELOPMENT_TEAM'] }
             .find { |t| t && !t.empty? }

widget.build_configurations.each do |c|
  s = c.build_settings
  s['INFOPLIST_FILE'] = "#{WIDGET}/Info.plist"
  s['CODE_SIGN_ENTITLEMENTS'] = "#{WIDGET}/#{WIDGET}.entitlements"
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['PRODUCT_NAME'] = WIDGET
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = team if team
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST'] = 'NO'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks',
  ]
end

project.save
puts "OK: target #{WIDGET} listo (App Group #{APP_GROUP})"
