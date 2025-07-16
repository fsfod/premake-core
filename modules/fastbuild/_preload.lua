--
-- Name:        gmake/_preload.lua
-- Purpose:     Define the gmake action.
-- Author:      Blizzard Entertainment (Tom van Dijck)
-- Modified by: Aleksi Juvani
--              Vlad Ivanov
-- Created:     2016/01/01
-- Copyright:   (c) 2016-2025 Jess Perkins, Blizzard Entertainment and the Premake project
--

	local p = premake
	local project = p.project
	local fastbuild

	function defaultToolset()
		local target = os.target()
		if target == p.MACOSX then
			return "clang"
		elseif target == p.WINDOWS then
			return "msc"
		else
			return "gcc"
		end
	end

	newaction {
		trigger         = "fastbuild",
		shortname       = "FastBuild",
		description     = "Generate FASTBuild .bff files",
		toolset         = defaultToolset(),

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib", "Utility", "Makefile", "None" },

		valid_languages = { "C", "C++" },

		valid_tools     = {
			cc     = { "clang", "gcc", "msc" },
		},


		onInitialize = function()
			require("fastbuild")
			fastbuild = p.modules.fastbuild
			--p.modules.fastbuild.cpp.initialize()
		end,

		onWorkspace = function(wks)
			p.escaper(fastbuild.esc)
			wks.projects = table.filter(wks.projects,  fastbuild.can_generate)
			p.generate(wks, fastbuild.getBFFfilename(wks, false), fastbuild.generate_workspace)
		end,

		onProject = function(prj)
		end,

		onCleanWorkspace = function(wks)
			p.clean.file(wks, p.modules.fastbuild.getmakefilename(wks, false))
		end,

		onCleanProject = function(prj)
			--p.clean.file(prj, p.modules.fastbuild.getmakefilename(prj, true))
		end
	}

--
-- Decide when the full module should be loaded.
--

	return function(cfg)
		return (_ACTION == "fastbuild")
	end
