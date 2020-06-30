project "lua-lib"
	language    "C"
	kind        "SharedLib"
	targetdir 	"%{wks.location}/bin/%{cfg.buildcfg}"
	warnings    "off"

	includedirs { "src" }

	files
	{
		"**.h",
		"**.c"
	}

	excludes
	{
		"src/lua.c",
		"src/luac.c",
		"src/print.c",
		"**.lua",
		"etc/*.c"
	}

	filter "system:windows"
		defines     { "LUA_BUILD_AS_DLL" }

	filter "system:linux or bsd or hurd or aix or solaris or haiku"
		defines     { "LUA_USE_POSIX", "LUA_USE_DLOPEN" }

	filter "system:macosx"
		defines     { "LUA_USE_MACOSX" }
