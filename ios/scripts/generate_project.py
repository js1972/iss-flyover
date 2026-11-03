#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib, json, plistlib
R=Path(__file__).resolve().parents[1]
P=R/'SkyTonight.xcodeproj'; P.mkdir(exist_ok=True)
TEAM='NF8828LV3U'
BUNDLE='com.js1972.skytonight'
def plist(path, data): path.write_bytes(plistlib.dumps(data))
base={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)'}
plist(R/'SkyTonight/Info.plist',base|{'CFBundleDisplayName':'Sky Tonight','CFBundlePackageType':'APPL','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'NSLocationWhenInUseUsageDescription':'Use your location to predict your sky and ISS passes. Apple resolves the place name; optional Apple Weather uses the observing coordinates.','UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UIBackgroundModes':['fetch'],'BGTaskSchedulerPermittedIdentifiers':[BUNDLE+'.refresh'],'CFBundleURLTypes':[{'CFBundleURLName':BUNDLE,'CFBundleURLSchemes':['skytonight']}],'NSUserActivityTypes':[BUNDLE+'.observing'],'ITSAppUsesNonExemptEncryption':False})
plist(R/'SkyWidgets/Info.plist',base|{'CFBundleDisplayName':'Sky Tonight Widgets','CFBundlePackageType':'XPC!','NSExtension':{'NSExtensionPointIdentifier':'com.apple.widgetkit-extension'}})
for folder in ['SkyTonight','SkyWidgets']:
    plist(R/f'{folder}/{folder}.entitlements',{'com.apple.security.application-groups':['group.'+BUNDLE],'com.apple.developer.weatherkit':True})
for folder in ['SkyWatch','SkyWatchWidgets']:
    (R/folder).mkdir(exist_ok=True)
    plist(R/f'{folder}/{folder}.entitlements',{'com.apple.security.application-groups':['group.'+BUNDLE+'.watch']})
plist(R/'SkyWatch/Info.plist',base|{'CFBundleDisplayName':'Sky Tonight','CFBundlePackageType':'APPL','WKApplication':True,'WKCompanionAppBundleIdentifier':BUNDLE,'WKWatchOnly':False,'WKRunsIndependentlyOfCompanionApp':False,'NSLocationWhenInUseUsageDescription':'Check that you are near the observing place before aligning directions with the compass.','CFBundleURLTypes':[{'CFBundleURLName':BUNDLE+'.watchkitapp','CFBundleURLSchemes':['skytonight']}],'ITSAppUsesNonExemptEncryption':False})
plist(R/'SkyWatchWidgets/Info.plist',base|{'CFBundleDisplayName':'Sky Tonight','CFBundlePackageType':'XPC!','NSExtension':{'NSExtensionPointIdentifier':'com.apple.widgetkit-extension'}})
plist(R/'Resources/PrivacyInfo.xcprivacy',{'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1','1C8F.1']}]})
assets=R/'Resources/Assets.xcassets'; (assets/'AppIcon.appiconset').mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
(assets/'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
# The native icon is curated separately from website icons; never overwrite it here.
objects=[]
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def obj(s,v): objects.append(f'\t\t{uid(s)} = {{ {v} }};');return uid(s)
refs={}
for path in sorted(R.rglob('*.swift')):
    if 'build' in path.parts: continue
    rel=str(path.relative_to(R)); refs[rel]=obj('file:'+rel,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = "<group>";')
resources={}
for name,kind in [('AppInformation.json','text.json'),('SkyEngine.js','sourcecode.javascript'),('Acknowledgements.txt','text'),('PrivacyInfo.xcprivacy','text.xml'),('Assets.xcassets','folder.assetcatalog'),('PlanetAssets.xcassets','folder.assetcatalog'),('WatchAssets.xcassets','folder.assetcatalog')]:
    resources[name]=obj('resource:'+name,f'isa = PBXFileReference; lastKnownFileType = {kind}; path = "Resources/{name}"; sourceTree = "<group>";')
products={}
kinds={'SkyTonight':'application','SkyWidgets':'app-extension','SkyTonightTests':'bundle.unit-test','SkyTonightUITests':'bundle.ui-testing','SkyWatch':'application','SkyWatchWidgets':'app-extension','SkyWatchUITests':'bundle.ui-testing'}
for name,kind in kinds.items():
    ext='app' if kind=='application' else 'appex' if kind=='app-extension' else 'xctest'
    products[name]=obj('product:'+name,f'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;')
pg=obj('products',f'isa = PBXGroup; children = ({",".join(products.values())}); name = Products; sourceTree = "<group>";')
root=obj('root',f'isa = PBXGroup; children = ({",".join([*refs.values(),*resources.values(),pg])}); sourceTree = "<group>";')
def config_list(name,settings):
    configs=[]
    for config in ['Debug','Release']:
        extra='SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if config=='Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O";'
        configs.append(obj('config:'+name+config,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} {extra} }}; name = {config};'))
    return obj('configs:'+name,f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_config=config_list('project','CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 18.0; SDKROOT = iphoneos; TARGETED_DEVICE_FAMILY = "1,2";')
for name,kind in kinds.items():
    portable={'SkyCore/Models.swift','SkyCore/WidgetPlanetArtwork.swift','SkyCore/WeatherCreditView.swift'}
    sources=[r for path,r in refs.items() if path.startswith(name+'/')
        or (name in ['SkyTonight','SkyWidgets'] and path.startswith('SkyCore/'))
        or (name=='SkyTonight' and path=='WatchShared/WatchTransfer.swift')
        or (name in ['SkyWatch','SkyWatchWidgets'] and (path.startswith('WatchShared/') or path in portable))]
    builds=[obj(f'build:{name}:{r}',f'isa = PBXBuildFile; fileRef = {r};') for r in sources]
    phases=[obj('sources:'+name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')]
    res=[]
    if name in ['SkyTonight','SkyWidgets','SkyWatch','SkyWatchWidgets']:
        allowed = set(resources) - {'WatchAssets.xcassets'} if name in ['SkyTonight','SkyWidgets'] else {'WatchAssets.xcassets','PlanetAssets.xcassets','PrivacyInfo.xcprivacy','Acknowledgements.txt'}
        if name=='SkyWidgets': allowed.discard('Assets.xcassets')
        if name=='SkyWatchWidgets': allowed.discard('WatchAssets.xcassets')
        res=[obj(f'resourcebuild:{name}:{key}',f'isa = PBXBuildFile; fileRef = {ref};') for key,ref in resources.items() if key in allowed]
    phases.append(obj('resources:'+name,f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(res)}); runOnlyForDeploymentPostprocessing = 0;'))
    phases.append(obj('frameworks:'+name,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;'))
    deps=[]
    dependencies={'SkyTonight':['SkyWidgets','SkyWatch'],'SkyWatch':['SkyWatchWidgets'],'SkyTonightTests':['SkyTonight'],'SkyTonightUITests':['SkyTonight'],'SkyWatchUITests':['SkyWatch']}.get(name,[])
    for dependency in dependencies:
        proxy=obj('proxy:'+name+dependency,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:"+dependency)}; remoteInfo = {dependency};')
        deps.append(obj('dependency:'+name+dependency,f'isa = PBXTargetDependency; target = {uid("target:"+dependency)}; targetProxy = {proxy};'))
        if name in ['SkyTonight','SkyWatch']:
            embed=obj('embedbuild:'+name+dependency,f'isa = PBXBuildFile; fileRef = {products[dependency]}; settings = {{ ATTRIBUTES = (RemoveHeadersOnCopy); }};')
            dest='16' if dependency=='SkyWatch' else '13'
            path='$(CONTENTS_FOLDER_PATH)/Watch' if dependency=='SkyWatch' else ''
            phases.append(obj('embed:'+name+dependency,f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = "{path}"; dstSubfolderSpec = {dest}; files = ({embed}); name = "Embed {dependency}"; runOnlyForDeploymentPostprocessing = 0;'))
    suffix={'SkyTonight':'','SkyWidgets':'.widgets','SkyWatch':'.watchkitapp','SkyWatchWidgets':'.watchkitapp.widgets'}.get(name,'.'+name.lower())
    settings=f'CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = {TEAM}; PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE+suffix}; PRODUCT_NAME = "$(TARGET_NAME)"; CURRENT_PROJECT_VERSION = 14; MARKETING_VERSION = 1.0; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks";'
    if name.startswith('SkyWatch'):
        settings+=' SDKROOT = watchos; WATCHOS_DEPLOYMENT_TARGET = 11.0; TARGETED_DEVICE_FAMILY = 4; SUPPORTED_PLATFORMS = "watchos watchsimulator";'
    if name in ['SkyTonight','SkyWidgets','SkyWatch','SkyWatchWidgets']:
        settings+=f' GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = {name}/Info.plist; CODE_SIGN_ENTITLEMENTS = {name}/{name}.entitlements;'
        if name in ['SkyTonight','SkyWatch']:
            settings+=' ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'
            if name=='SkyWatch': settings+=' SKIP_INSTALL = YES;'
        else:settings+=' APPLICATION_EXTENSION_API_ONLY = YES; SKIP_INSTALL = YES;'
    else:
        settings+=' GENERATE_INFOPLIST_FILE = YES;'
        if name=='SkyTonightTests':settings+=' TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SkyTonight.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SkyTonight"; BUNDLE_LOADER = "$(TEST_HOST)";'
        else:settings+=f' TEST_TARGET_NAME = {"SkyWatch" if name=="SkyWatchUITests" else "SkyTonight"};'
    configs=config_list(name,settings)
    obj('target:'+name,f'isa = PBXNativeTarget; buildConfigurationList = {configs}; buildPhases = ({",".join(phases)}); buildRules = (); dependencies = ({",".join(deps)}); name = {name}; productName = {name}; productReference = {products[name]}; productType = "com.apple.product-type.{kind}";')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; }}; buildConfigurationList = {project_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {root}; productRefGroup = {pg}; projectDirPath = ""; projectRoot = ""; targets = ({",".join(uid("target:"+n) for n in kinds)});')
(P/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid("project")}; }}\n')
schemes=P/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(name,ext):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:SkyTonight.xcodeproj"/>'
app=ref('SkyTonight','app')
tests=''.join(f'<TestableReference skipped="NO" parallelizable="NO">{ref(n,"xctest")}</TestableReference>' for n in ['SkyTonightTests','SkyTonightUITests'])
(schemes/'SkyTonight.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables>{tests}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
watch_scheme=(schemes/'SkyTonight.xcscheme').read_text().replace(app,ref('SkyWatch','app')).replace(tests,f'<TestableReference skipped="NO" parallelizable="NO">{ref("SkyWatchUITests","xctest")}</TestableReference>')
(schemes/'SkyWatch.xcscheme').write_text(watch_scheme)
print('Generated SkyTonight project with permanent app, widget and App Group identifiers')
