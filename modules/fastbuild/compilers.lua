local p = premake
local project = p.project
local config = p.config
vswhere = {}
local VSWherePath

local function findVSWhere()
	if os.isfile("vswhere.exe") then
		return "vswhere.exe"
	end

	local pf86 = os.getenv("ProgramFiles(x86)") or "C:/Program Files (x86)"
	if not pf86 then
		return nil
	end

	local exe = path.join(pf86, "Microsoft Visual Studio/Installer/vswhere.exe")
	if os.isfile(exe) then
		return exe
	end

	return nil
end

function vswhere.run(command)
	local vswhereExe = VSWherePath or findVSWhere()
	if not vswhereExe then
		error("Could not locate vswhere")
	end
	local cmd = string.format('"%s" -nologo -format json %s', vswhereExe, command)
	local output, exitcode, err = os.outputof(cmd)
	if not output then
		error("Failed to run vswhere.exe: "..err.. "cmd: "..cmd)
	end

	if exitcode ~= 0 then
		error("vswhere.exe retured non zero exit code: "..exitcode.." ".. output)
	end

	local vsinstances, err = json.decode(output)
	if not vsinstances then
		error("Failed to decode vshere output: "..err)
	end

	return vsinstances
end

function vswhere.getVSInstallations()
	if vswhere.vsInstallations then
		return vswhere.vsInstallations
	end

	local vsinstances = vswhere.run("-products * -prerelease -requires Microsoft.VisualStudio.Component.VC.*")
	vswhere.vsInstallations = vsinstances
	return vsinstances
end

--  Map Premake‑style IDs to installationVersion major numbers.
vswhere.mscVersions = {
	v80  = 8,   -- VS2005 (not in vswhere)
	v90  = 9,   -- VS2008 (not in vswhere)
	v100 = 10,  -- VS2010
	v110 = 11,  -- VS2012
	v120 = 12,  -- VS2013
	v140 = 14,  -- VS2015
	v141 = 15,  -- VS2017
	v142 = 16,  -- VS2019
	v143 = 17,  -- VS2022
}

local function getVCToolsVersion(installationPath)
	local root = path.join(installationPath, "VC/Tools/MSVC/")
	print(root)
	if not os.isdir(root) then
		return nil
	end
	for _, versionDir in ipairs(os.matchdirs(root.."/*")) do
		local hasCompiler = #os.matchfiles(path.join(versionDir, "**/cl.exe")) > 0
		if hasCompiler then
			return path.getname(versionDir), versionDir, false
		else
			local hasLLVM = #os.matchfiles(path.join(versionDir, "**/clang-cl.exe")) > 0
			if hasLLVM then
				return path.getname(versionDir), versionDir, true
			end
		end
	end
	return nil
end

local foundVCInstalls = {}

local function makePlatformTable(vsRoot, host, platform)
	local root = path.join(vsRoot, string.format("bin/Host%s/%s/", host, platform))
	local cc = path.join(root, "cl.exe")
	return {
		cc = cc,
		cxx = cc,
		ar = path.join(root, "lib.exe"),
		link = path.join(root, "link.exe"),
		libsDir = {path.join(vsRoot, "lib", platform)},
		includeDirs = {path.join(vsRoot, "include")},
		binDir = root,
	}
end

local VCInstallationInfo = {}

function vswhere.GetVCInstallationInfo(vsInstance)
	local instanceId = vsInstance.instanceId
	if VCInstallationInfo[instanceId] then
		return VCInstallationInfo[instanceId]
	end

	local toolsVersion, toolsetRoot, llvmOnly = getVCToolsVersion(vsInstance.installationPath)
	if toolsetRoot then
		print(toolsetRoot)
	end

	local majorVersion = tonumber(vsInstance.installationVersion:match("^(%d+)"))
	local info = {
		instanceId = vsInstance.instanceId,
		prerelease = vsInstance.isPrerelease == 1,
		majorVersion = majorVersion,
		VCToolsVersion = toolsVersion,
		VCToolsetRoot = toolsetRoot,
		fullinfo = vsInstance,
		displayName = vsInstance.displayName
	}

	if toolsetRoot and not llvmOnly then
		info.x64 = makePlatformTable(toolsetRoot, "x64", "x64")
		info.x86 = makePlatformTable(toolsetRoot, "x86", "x86")
		info.x86_64 = info.x64
		info.has_cl = true
	else
		info.has_cl = false
	end

	VCInstallationInfo[instanceId] = info
	return info
end

function vswhere.getMSCInstance(version)
	local existing = foundVCInstalls[version]
	if existing then
		return existing
	elseif existing == false then
		return nil
	end

	local toolset, toolset_version = p.tools.canonical(version)
	local vsVersion
	if toolset_version then
		vsVersion = vswhere.mscVersions[toolset_version]
		if not vsVersion then
			error("Unknown VS version "..toolset_version)
		end
	end

	local vsinstances = vswhere.getVSInstallations()

	local matches = {}
	local maxVersion = 0
	for i, vs in ipairs(vsinstances) do
		local major = vsVersion and tonumber(vs.installationVersion:match("^(%d+)"))
		if not vsVersion or major == vsVersion  then
			local info = vswhere.GetVCInstallationInfo(vs)
			print("has_cl", info.has_cl, vs.displayName)
			if info.has_cl then
				maxVersion = math.min(maxVersion, info.majorVersion)
				table.insert(matches, info)
			end
		end
	end
	print("found", #matches)

	if #matches == 0 then
		print("Found no Visual Studio installations for", version, "with c++ installed")
		foundVCInstalls[version] = false
		return nil
	end

	local prerelease, release
	for i, info in ipairs(matches) do
		if not prerelease or (info.majorVersion > prerelease.majorVersion) then
			prerelease = info
		end
		if not release or (info.majorVersion > release.majorVersion) then
			release = info
		end
	end

	local bestMatch = release or prerelease
	-- Favor prerelease if the toolset is a versionless msc and prerelease's major version is higher than normal release
	if not vsVersion and prerelease and release and prerelease.majorVersion >= release.majorVersion  then
		bestMatch = prerelease
	end

	foundVCInstalls[version] = bestMatch
	return bestMatch
end

p.tools.clang.tools.rc = p.tools.clang.tools.rc or "windres"

local msc = p.tools.msc
msc.toolnames = {cc = "cl", cxx = "cl", ar = "lib", rc = "rc"}
msc.clang_toolnames = {cc = "clang-cl", cxx = "clang-cl", ar = "lld-link", rc = "rc"}

msc.gettoolname = function(cfg, name, platform)
	if name == "ccx" then
		name = "cc"
	end
	if cfg.toolset then
		local vcinfo = vswhere.getMSCInstance(cfg.toolset)
		if platform == "x86_x64" or true then
			platform = "x64"
		end
		local platformTools = vcinfo and vcinfo[platform]
		if platformTools then
			return platformTools[name]
		end
	end
	return msc.toolnames[name]
end

function msc.getLibraryDirectories(cfg)
	local arch = cfg.architecture or "x64"

	local mscLibsDir
	if cfg.toolset then
		local vcinfo = vswhere.getMSCInstance(cfg.toolset)
		if vcinfo and vcinfo[arch] then
			mscLibsDir = vcinfo[arch].libsDir
		end
	end

	local winSDK = msc.getWindowsSDK()
	local sdkLibsDirs
	if winSDK then
		sdkLibsDirs = winSDK.libs[arch]
	end

	local flags = {}
	local dirs = table.join(mscLibsDir, cfg.libdirs, cfg.syslibdirs, sdkLibsDirs)
	for i, dir in ipairs(dirs) do
		dir = p.tools.getrelative(cfg.project, dir)
		table.insert(flags, '/LIBPATH:"' .. dir .. '"')
	end
	return flags
end

local getincludedirs = msc.getincludedirs
function msc.getincludedirs(cfg, dirs, extdirs, frameworkdirs, includedirsafter)
	local arch = cfg.architecture or "x64"

	if cfg.toolset then
		local vcinfo = vswhere.getMSCInstance(cfg.toolset)
		assert(vcinfo, cfg.toolset)
		assert(vcinfo and vcinfo[arch], arch)
		if vcinfo and vcinfo[arch] then
			extdirs = table.join(extdirs, vcinfo[arch].includeDirs)
		end
	end

	local winSDK = msc.getWindowsSDK()
	if winSDK then
		extdirs = table.join(extdirs, winSDK.includes)
	end

	return getincludedirs(cfg, dirs, extdirs, frameworkdirs, includedirsafter)
end

local win10SDKVersion
local win10SDKRoots
function msc.getWindowsSDKPath()
	if win10SDKRoots then
		return win10SDKRoots, win10SDKVersion
	end

	local reg_arch = iif(os.is64bit(), "\\Wow6432Node\\", "\\")
	local sdk_version = os.getWindowsRegistry( "HKLM:SOFTWARE" .. reg_arch .."Microsoft\\Microsoft SDKs\\Windows\\v10.0\\ProductVersion" )
	if sdk_version == nil then
		return nil
	end
	win10SDKVersion = sdk_version

	win10SDKRoots = os.getWindowsRegistry( "HKLM:SOFTWARE" .. reg_arch .."Microsoft\\Microsoft SDKs\\Windows\\v10.0\\InstallationFolder" )
	print("Founds windows 10 SDK", win10SDKVersion, "at", win10SDKRoots)
	if not os.isdir(path.join(win10SDKRoots, "Include", win10SDKVersion)) then
		win10SDKVersion = win10SDKVersion ..".0"
	end
	assert(os.isdir(path.join(win10SDKRoots, "Include", win10SDKVersion)))
	return win10SDKRoots
end

local WindowsSDKS = {}

function msc.getWindowsSDK(version)
	if WindowsSDKS[version]  then
		return WindowsSDKS[version]
	end

	local root =  msc.getWindowsSDKPath()
	if not root then
		return nil
	end

	version = version or win10SDKVersion
	local includeRoot = path.join(win10SDKRoots, "Include", version)
	local libRoot = path.join(win10SDKRoots, "Lib", version)

	local sdk = {
		includes =  {
			path.join(includeRoot, "ucrt"),
			path.join(includeRoot, "um"),
			path.join(includeRoot, "shared"),
			path.join(includeRoot, "winrt"),
		},
		libs = {
			x86_64 = {
				path.join(libRoot, "ucrt", "x64"),
				path.join(libRoot, "um", "x64"),
			},
			x86 = {
				path.join(libRoot, "ucrt", "x86"),
				path.join(libRoot, "um", "x86"),
			}
		}
	}
	WindowsSDKS[version] = sdk
	return sdk
end
