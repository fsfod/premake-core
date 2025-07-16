--
-- fastbuild.lua
-- (c) 2016-2017 Jess Perkins, Blizzard Entertainment and the Premake project
--

	local p       = premake
	local project = p.project
	local workspace = p.workspace
	local fileconfig = p.fileconfig

	p.modules.fastbuild = {}
	p.modules.fastbuild._VERSION = p._VERSION
	local fastbuild = p.modules.fastbuild

	include("compilers.lua")

	function fastbuild.generate_workspace(wks)
		p.eol("\n")
		p.indent("  ")

		fastbuild.header(wks)
		local platformsPresent = {}
		local numPlatforms = 0

		for cfg in workspace.eachconfig(wks) do
			local platform = cfg.platform
			print("platform", cfg.name, platform, cfg.architecture)
			if platform and not platformsPresent[platform] then
				numPlatforms = numPlatforms + 1
				platformsPresent[platform] = true
			end
		end

		local toolsetsWritten = {}
		for cfg in workspace.eachconfig(wks) do
			for prj in p.workspace.eachproject(wks) do
				local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjcfg then
					local architecture = prjcfg.architecture or cfg.architecture

					local name = fastbuild.getCompilerNameForConfig(prjcfg)
					if (prjcfg.language == p.C or prjcfg.language == p.CPP) and not toolsetsWritten[name] then
						print("Compiler:", prjcfg.toolset, architecture)
						fastbuild.writeCompiler(prjcfg, name)
						toolsetsWritten[name] = name
					end

				end
			end
		end

		wks.fastbuild = {
			compilers = {},
			projectOutputTargets = {}
		}

		--fastbuild.configmap(wks)
		fastbuild.projects(wks)

		--fastbuild.workspacePhonyRule(wks)
		--fastbuild.groupRules(wks)

		--fastbuild.projectrules(wks)
		--fastbuild.cleanrules(wks)

	end

	function fastbuild.writeCompiler(cfg, name)
		local toolset, toolset_version = p.tools.canonical(cfg.toolset)
		local architecture = cfg.architecture or "X64"
		print(cfg.toolset, cfg.architecture)
		if not toolset then
			p.error("Unknown toolset " .. cfg.toolset)
		end

		local cc = toolset.gettoolname(cfg, "cc", architecture)
		local cxx = toolset.gettoolname(cfg, "cxx", architecture)
		local ar = toolset.gettoolname(cfg, "ar", architecture)
		local linker = cxx
		if toolset == p.tools.msc then
			linker = toolset.gettoolname(cfg, "link", architecture)
		end

		p.push(".%s = [", name)
		p.w(".Compiler = '%s'", cxx)
		p.w(".Librarian = '%s'", ar)
		p.w(".Linker = '%s'", linker)

		if true then
			p.w(".RuntimeLibPaths = '%s'", linker)
		end
		p.pop("]\n")
		return name
	end

	function fastbuild.getCompilerNameForConfig(cfg)
		local name = "Compiler_"..cfg.toolset:gsub("-", "_")
		if cfg.architecture then
			name = name..cfg.architecture
		end
		return name
	end

	function fastbuild.projects(wks)
		local sorted, visiting, visited = {}, {}, {}

		local function visit(prj)
			if visited[prj] then
				return
			end
			if visiting[prj] then
				error("Cyclic dependency detected involving " .. prj.name)
			end
			visiting[prj] = true
			for _, dep in ipairs(p.project.getdependencies(prj)) do
				visit(dep)
			end
			visiting[prj] = nil
			visited[prj]  = true
			table.insert(sorted, prj)   -- leaves first, roots last
		end

		-- Sort projects in topological order since its an error to reference a target as input in FastBuild before its declared
		for prj in  p.workspace.eachproject(wks) do
			visit(prj)
		end

		for _, prj in ipairs(sorted) do
			if project.isc(prj) or project.iscpp(prj) then
				fastbuild.generate_project(prj)
			end
		end
	end

	function fastbuild.generate_project(prj)
		for cfg in project.eachconfig(prj) do
			local files = {}
			local copyFiles = {}
			table.foreachi(prj._.files, function(f)
				local fcfg = fileconfig.getconfig(f, cfg)
				if path.iscppfile(f.relpath) and (not fcfg or not fcfg.flags.ExcludeFromBuild or fcfg.buildaction ~= "None") then
					table.insert(files, f.abspath)
				elseif fcfg and  fcfg.buildaction == "Copy" then
					table.insert(copyFiles, f.abspath)
				end
			end)

			if #copyFiles > 0 then
				fastbuild.copyFilesToTargetDir(prj, cfg, copyFiles)
			end

			local targetName
			-- Executable section can't list source files so they have to be declared in a separate ObjectList
			if #files > 0 and (cfg.kind == p.CONSOLEAPP or cfg.kind == p.WINDOWEDAPP) then
				local objTargetName = fastbuild.writeObjectList(prj, cfg, files)
				targetName = fastbuild.writeTarget(prj, cfg, {objTargetName})
			elseif #files > 0 then
				targetName = fastbuild.writeTarget(prj, cfg, nil, nil, files)
			else
				assert(false, "TODO: make file and utilty projects")
			end
		end
	end

	function fastbuild.writeObjectList(prj, cfg, files, name)
		name = name or fastbuild.getTargetName(prj, cfg, "objs")
		p.push("ObjectList('%s') {", name)
		p.w("Using(.%s)", fastbuild.getCompilerNameForConfig(cfg))
		fastbuild.writeCompileOptions(prj, cfg, cfg)
		fastbuild.writeCompilerInputFiles(prj, files)
		p.pop("}\n")
		return name
	end

	function fastbuild.writeCompileOptions(prj, cfg, filecfg)
		local toolset, toolset_version = p.tools.canonical(cfg.toolset)
		if not toolset then
			p.error("Unknown toolset " .. cfg.toolset)
		end

		local compileOptions = fastbuild.getcxxflags(toolset, cfg, filecfg)
		local ccOpts
		if toolset == p.tools.msc then
			ccOpts = iif(cfg.language == "C", "/Tc", "/Tp")..'"%1" /Fo"%2" /nologo'
		else
			assert(false, "TODO: clang and GCC")
		end

		p.w(".CompilerOptions = '%s /c %s'", ccOpts, compileOptions)
		p.w(".CompilerOutputPath = '%s'",  p.workspace.getrelative(prj.workspace, cfg.objdir))
	end

	function fastbuild.writeCompilerInputFiles(prj, files)
		p.push(".CompilerInputFiles = {")
		for _, f in ipairs(files) do
			p.w("'%s',", workspace.getrelative(prj.workspace, f))
		end
		p.pop('}')
	end

	function fastbuild.writeTarget(prj, cfg, inputs, name, sourceFiles)
		local toolset, toolset_version = p.tools.canonical(cfg.toolset)
		local action
		if cfg.kind == p.STATICLIB then
			action = "Library"
		elseif cfg.kind == p.SHAREDLIB then
			action = "DLL"
		elseif cfg.kind == p.CONSOLEAPP or cfg.kind == p.WINDOWEDAPP then
			action = "Executable"
		end

		if not name then
			name = fastbuild.getTargetName(prj, cfg)
		end

		p.push("%s('%s') {", action, name)
		p.w("Using(.%s)", fastbuild.getCompilerNameForConfig(cfg))
		fastbuild.writeLinkerOptions(prj, toolset, cfg)

		if sourceFiles and #sourceFiles > 0 then
			fastbuild.writeCompileOptions(prj, cfg, cfg)
			fastbuild.writeCompilerInputFiles(prj, sourceFiles)
		end

		-- Collect dependent projects to Libraries
		local projects = p.config.getlinks(cfg, "siblings", "object")
		if #projects > 0 then
			inputs = table.join(inputs or {}, table.translate(projects, function(cfg)
				return fastbuild.getTargetName(cfg.project, cfg)
			end))
		end

		if inputs and #inputs > 0 then
			p.w(".Libraries = { %s }", "'"..table.concat(inputs, "' '").."'")
		end
		p.pop("}")
	end

	function fastbuild.copyFilesToTargetDir(prj, cfg, copyFiles)
		assert(type(copyFiles) == "table" and #copyFiles > 0)
		local name = fastbuild.getTargetName(cfg.project, cfg, "copyToOutput")
		assert(false, "TODO: copyToOutput")
		return name
	end

	function fastbuild.writeLinkerOptions(prj, toolset, cfg)
		local fbLinker
		-- Fastbuild Autogenerated input objects and output name
		if toolset == p.tools.msc then
			fbLinker = '/OUT:"%2" "%1"'
		end

		local linkerFlags = fastbuild.getlinkerflags(toolset, cfg)
		local output = workspace.getrelative(prj.workspace, cfg.buildtarget.abspath)
		if cfg.kind == p.STATICLIB then
			p.w(".LibrarianOptions = '%s %s'", fbLinker, linkerFlags)
			p.w(".LibrarianOutput = '%s'", output)
		else
			p.w(".LinkerOptions = '%s %s'", fbLinker, linkerFlags)
			p.w(".LinkerOutput = '%s'", output)
		end
	end

	function fastbuild.getcxxflags(toolset, cfg, filecfg)
		local getrelative = p.tools.getrelative
		p.tools.getrelative = function(cfg, value)
			return p.workspace.getrelative(cfg.workspace, value)
		end
		--p.escaper(fastbuild.shesc)
		local buildopt = fastbuild.list(filecfg.buildoptions)
		local cppflags = fastbuild.list(toolset.getcppflags(filecfg))
		local cxxflags = fastbuild.list(toolset.getcxxflags(filecfg))
		local defines = fastbuild.list(table.join(toolset.getdefines(filecfg.defines, filecfg), toolset.getundefines(filecfg.undefines)))
		local includes = fastbuild.list(toolset.getincludedirs(cfg, filecfg.includedirs, filecfg.externalincludedirs, filecfg.frameworkdirs, filecfg.includedirsafter))
		local forceincludes = fastbuild.list(toolset.getforceincludes(cfg))
		--p.escaper(nil)
		p.tools.getrelative = getrelative

		return buildopt .. cppflags .. cxxflags .. defines .. includes .. forceincludes
	end

	function fastbuild.getlinkerflags(toolset, cfg)
		local ldflags = fastbuild.list(table.join(
			toolset.getlinks(cfg, true),
			toolset.getLibraryDirectories(cfg),
			toolset.getrunpathdirs(cfg, table.join(cfg.runpathdirs, p.config.getsiblingtargetdirs(cfg))),
			toolset.getldflags(cfg),
			cfg.linkoptions
		))

		return ldflags
	end

	function fastbuild.getTargetName(prj, cfg, kind)
		local name = prj.name .. "_" .. cfg.buildcfg
		if cfg.platform then
			name = name .. "_".. cfg.platform
		end
		if kind then
			return string.format("%s_%s", name, kind)
		else
			return name
		end
	end

	function fastbuild.can_generate(prj)
		return p.action.supports(prj.kind) and prj.kind ~= p.NONE
	end
--
-- Write out the default configuration rule for a workspace or project.
--
-- @param target
--    The workspace or project object for which a makefile is being generated.
--

	function fastbuild.defaultconfig(target)
		-- find the right configuration iterator function for this object
		local eachconfig = iif(target.project, project.eachconfig, p.workspace.eachconfig)
		local defaultconfig = nil

		-- find the right default configuration platform, grab first configuration that matches
		if target.defaultplatform then
			for cfg in eachconfig(target) do
				if cfg.platform == target.defaultplatform then
					defaultconfig = cfg
					break
				end
			end
		end

		-- grab the first configuration and write the block
		if not defaultconfig then
			local iter = eachconfig(target)
			defaultconfig = iter()
		end

		if defaultconfig then
			--defaultconfig.shortname
		end
	end

	function fastbuild.list(value)
		if value and #value > 0 then
			return " " .. table.concat(value, " ")
		else
			return ""
		end
	end

	function fastbuild.quotedList(value)
		if value and #value > 0 then
			return "'" .. table.concat(value, "' '") .. "'"
		else
			return ""
		end
	end

---
-- Escape a string so it can be written to a makefile.
---

	function fastbuild.esc(value)
		result = value:gsub("\\", "\\\\")
		result = result:gsub("\"", "\\\"")
		result = result:gsub(" ", "\\ ")
		result = result:gsub("%(", "\\(")
		result = result:gsub("%)", "\\)")

		-- leave $(...) shell replacement sequences alone
		result = result:gsub("$\\%((.-)\\%)", "$(%1)")
		return result
	end


--
-- Get the makefile file name for a workspace or a project. If this object is the
-- only one writing to a location then I can use "Makefile". If more than one object
-- writes to the same location I use name + ".make" to keep it unique.
--

	function fastbuild.getBFFfilename(this, searchprjs)
		local count = 0
		for wks in p.global.eachWorkspace() do
			if wks.location == this.location then
				count = count + 1
			end

			if searchprjs then
				for _, prj in ipairs(wks.projects) do
					if prj.location == this.location then
						count = count + 1
					end
				end
			end
		end

		if count == 1 then
			return "fbuild.bff"
		else
			return ".bff"
		end
	end


--
-- Output a makefile header.
--
-- @param target
--    The workspace or project object for which the makefile is being generated.
--

	function fastbuild.header(target)
		local kind = iif(target.project, "project", "workspace")
		p.w('//  %s %s FASTBuild script generated by Premake', p.action.current().shortname, kind)
		p.w('')

		fastbuild.defaultconfig(target)
	end


--
-- Rules for file ops based on the shell type. Can't use defines and $@ because
-- it screws up the escaping of spaces and parenthesis (anyone know a fix?)
--


	function fastbuild.copyfile_cmds(source, dest)
		local cmd = '$(SILENT) {COPYFILE} ' .. source .. ' ' .. dest
		return { 'ifeq (posix,$(SHELLTYPE))',
			'\t' .. os.translateCommands(cmd, 'posix'),
			'else',
			'\t' .. os.translateCommands(cmd, 'windows'),
			'endif' }
	end

--
-- Format a list of values to be safely written as part of a variable assignment.
--

	function fastbuild.list(value, quoted)
		quoted = false
		if #value > 0 then
			if quoted then
				local result = ""
				for _, v in ipairs (value) do
					if #result then
						result = result .. " "
					end
					result = result .. p.quoted(v)
				end
				return result
			else
				return " " .. table.concat(value, " ")
			end
		else
			return ""
		end
	end


--
-- Convert an arbitrary string (project name) to a make variable name.
--

	function fastbuild.tovar(value)
		value = value:gsub("[ -]", "_")
		value = value:gsub("[()]", "")
		return value
	end

	function fastbuild.getToolSet(cfg)
		local default = iif(cfg.system == p.MACOSX, "clang", "gcc")
		local toolset, version = p.tools.canonical(cfg.toolset or default)
		if not toolset then
			error("Invalid toolset '" .. cfg.toolset .. "'")
		end
		return toolset
	end


	function fastbuild.outputSection(prj, callback)
		local root = {}

		for cfg in project.eachconfig(prj) do
			-- identify the toolset used by this configurations (would be nicer if
			-- this were computed and stored with the configuration up front)

			local toolset = fastbuild.getToolSet(cfg)

			local settings = {}
			local funcs = callback(cfg)
			for i = 1, #funcs do
				local c = p.capture(function ()
					funcs[i](cfg, toolset)
				end)
				if #c > 0 then
					table.insert(settings, c)
				end
			end

			if not root.settings then
				root.settings = table.arraycopy(settings)
			else
				root.settings = table.intersect(root.settings, settings)
			end

			root[cfg] = settings
		end

		if #root.settings > 0 then
			for _, v in ipairs(root.settings) do
				p.outln(v)
			end
			p.outln('')
		end

		local first = true
		for cfg in project.eachconfig(prj) do
			local settings = table.difference(root[cfg], root.settings)
			if #settings > 0 then
				if first then
					_x('ifeq ($(config),%s)', cfg.shortname)
					first = false
				else
					_x('else ifeq ($(config),%s)', cfg.shortname)
				end

				for k, v in ipairs(settings) do
					p.outln(v)
				end

				_p('')
			end
		end

		if not first then
			p.outln('endif')
			p.outln('')
		end
	end


	-- convert a rule property into a string

---------------------------------------------------------------------------
--
-- Handlers for the individual makefile elements that can be shared
-- between the different language projects.
--
---------------------------------------------------------------------------


	function fastbuild.settings(cfg, toolset)
		if #cfg.makesettings > 0 then
			for _, value in ipairs(cfg.makesettings) do
				p.outln(value)
			end
		end

		local value = toolset.getmakesettings(cfg)
		if value then
			p.outln(value)
		end
	end

--[[
Exec( alias )  ; (optional) Alias
{
  .ExecExecutable         ; Executable to run
  .ExecInput              ; (optional) Input file(s) to pass to executable
  .ExecInputPath          ; (optional) Path(s) to find files in
  .ExecInputPattern       ; (optional) Pattern(s) to use when finding files (default *.*)
  .ExecInputPathRecurse   ; (optional) Recurse into dirs when finding files (default true)
  .ExecInputExcludePath   ; (optional) Path(s) to exclude
  .ExecInputExcludedFiles ; (optional) File(s) to exclude from compilation (partial, root-relative of full path)
  .ExecInputExcludePattern; (optional) Pattern(s) to exclude
  .ExecOutput             ; Output file generated by executable
  .ExecArguments          ; (optional) Arguments to pass to executable
  .ExecWorkingDir         ; (optional) Working dir to set for executable
  .ExecReturnCode         ; (optional) Expected return code from executable (default 0)
  .ExecUseStdOutAsOutput  ; (optional) Write the standard output from the executable to output file (default false)
  .ExecAlways             ; (optional) Run the executable even if inputs have not changed (default false)
  .ExecAlwaysShowOutput   ; (optional) Show the process output even if the step succeeds (default false)

  ; Additional options
  .PreBuildDependencies   ; (optional) Force targets to be built before this Exec (Rarely needed,
                          ; but useful when Exec relies on externally generated files).
  .ConcurrencyGroupName   ; (optional) Concurrency Group for this task
  .Environment            ; (optional) Environment variables used when running the executable
                          ; If not set, uses .Environment from your Settings node
}
]]
	function fastbuild.CreateExecBlock(prj, cmd, name, inputs, output, extra)
		p.push("Exec('%s') {", name)
		p.w(".ExecExecutable = '%s'", cmd)
		if output then
			p.w(".ExecOutput = '%s'", output)
		end
		if inputs and #inputs > 0 then
			p.w(".ExecInput  = { %s }", fastbuild.quotedList(inputs))
		end

		if extra then
			if extra.arguments then
				p.w(".ExecArguments = '%s'", extra.arguments)
			end
			if extra.workingDir then
				p.w(".ExecWorkingDir = '%s'", extra.workingDir)
			end
			if extra.alwaysRun then
				p.w(".ExecAlways = true")
			end
			if extra.inputSearchPaths then
				p.w(".ExecInputPath = '%s'", fastbuild.quotedList(extra.inputSearchPaths))
			end
			if extra.preBuildDependencies and #extra.preBuildDependencies > 0 then
				p.w(".PreBuildDependencies = { %s }", fastbuild.quotedList(extra.preBuildDependencies))
			end
		end
		p.pop("}")
	end

	function fastbuild.buildCmds(cfg, event)
		_p('define %sCMDS', event:upper())
		local steps = cfg[event .. "commands"]
		local msg = cfg[event .. "message"]
		if #steps > 0 then
			steps = os.translateCommandsAndPaths(steps, cfg.project.basedir, cfg.project.location)
			msg = msg or string.format("Running %s commands", event)
			_p('\t@echo %s', msg)
			_p('\t%s', table.implode(steps, "", "", "\n\t"))
		end
		_p('endef')
	end


	function fastbuild.preBuildCmds(cfg, toolset)
		fastbuild.buildCmds(cfg, "prebuild")
	end


	function fastbuild.preLinkCmds(cfg, toolset)
		fastbuild.buildCmds(cfg, "prelink")
	end


	function fastbuild.postBuildCmds(cfg, toolset)
		fastbuild.buildCmds(cfg, "postbuild")
	end


	function fastbuild.preBuildRules(cfg, toolset)
		_p('prebuild: | $(OBJDIR)')
		_p('\t$(PREBUILDCMDS)')
		_p('')
	end

	return fastbuild
