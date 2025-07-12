| Option | Summary |
| --- | --- |
| [-cache\[read|write]](#cache) | Use the build cache. |
| [-cachecompressionlevel \[level]](#cachecompressionlevel) | Control compression level of cache entries. (Default -1) |
| [-cacheinfo](#cacheinfo) | Emit summary of objects in the cache. |
| [-cachetrim \[sizeMiB]](#cachetrim) | Reduce the size of the cache. |
| [-cacheverbose](#cacheverbose) | Provide additional information about cache interactions. |
| [-clean](#clean) | Force a clean build. |
| [-compdb](#compdb) | Generate JSON compilation database for the specified targets. |
| [-config <path>](#config) | Explicitly specify the config file to use. |
| [-continueafterdbmove](#continueafterdbmove) | Allow build to continue after a DB move. |
| [-dbfile <path>](#dbfile) | Explicitly specify the dependency database file to use. |
| [-debug](#debug_fbuild) | \[Windows Only] Allow attaching a debugger immediately on startup. |
| [-dist](#dist) | Enable distributed compilation. |
| [-distcompressionlevel \[level]](#distcompressionlevel) | Control compression level of jobs sent out for distribution. (Default -1) |
| [-distverbose](#distverbose) | Enable detailed logging for distributed compilation. |
| [-dot\[full]](#dot) | Generate an fbuild.gv DOT file for known dependencies. |
| [-fixuperrorpaths](#fixuperrorpaths) | Reformat GCC/SNC/Clang error messages in Visual Studio format. |
| [-forceremote](#forceremote) | Force distributable jobs to only be built remotely. |
| [-help](#help) | Show usage help. |
| [-ide](#ide) | Enable multiple options for IDE integration. |
| [-j\[x]](#jx) | Explicitly set local worker thread count. |
| [-monitor](#monitor) | Output a machine readable file for use by 3rd party tools. |
| [-nofastcancel](#nofastcancel) | Disable aborting other tasks as soon any task fails. |
| [-nolocalrace](#nolocalrace) | Disable local race of remotely started jobs. |
| [-noprogress](#noprogress) | Don't show the progress bar while building. |
| [-nostoponerror](#nostoponerror) | Don't stop building on first error. |
| [-nosummaryonerror](#nosummaryonerror) | Don't print the -summary output if there is an error. |
| [-nounity](#nounity) | Individually build all files normally built in Unity. |
| [-profile](#profile) | Output a Chrome tracing format fbuild\_profile.json describing the build. |
| [-progress](#progress) | Show the build progress bar even if it would otherwise be disabled. |
| [-quiet](#quiet) | Don't show build output. |
| [-report=\[html|json]](#report) | Output a report at build termination. (Default html) |
| [-showcmdoutput](#showcmdoutput) | Show output of external processes. |
| [-showcmds](#showcmds) | Show command lines used to launch external processes. |
| [-showdeps](#showdeps) | Show known dependency tree for specified targets. |
| [-showtargets](#showtargets) | Show primary build targets, excluding those marked "Hidden". |
| [-showalltargets](#showalltargets) | Show primary build targets, including those marked "Hidden". |
| [-summary](#summary) | Show a summary at the end of the build. |
| [-verbose](#verbose) | Show detailed diagnostic information for debugging. |
| [-version](#version) | Print version and exit. |
| [-vs](#version) | \[Deprecated] Same as -ide. |
| [-wait](#wait) | Wait for a previous build to complete before starting. |
| [-why](#why) | For each item that builds, show the trigger reason. |
| [-wrapper](#wrapper) | Wrapper mode for Visual Studio. (Windows only) |
| [-wsl \[wslPath] \[args...]](#wsl) | Invoke a command inside the Windows Subsystem for Linux. |

| Option | Summary |
| --- | --- |
| [-console](#console) | Disable UI. (Windows Only) |
| [-cpus=\[n|-n|n%]](#cpus) | Control worker CPUs allocation. |
| [-debug](#debug_fbuildworker) | \[Windows Only] Allow attaching a debugger immediately on startup. |
| [-minfreememory=\[MiB]](#minfreememory) | \[Windows Only] Override the default minimum memory limit (in MiB). |
| [-mode=\[disabled|idle|dedicated|proportional]](#mode) | Control worker availability. |
| [-nosubprocess](#nosubprocess) | Don't spawn as a sub-process. |
| [-periodicrestart](#periodicrestart) | Restart worker every 4 hours. |

Enable usage of the build cache. The cache options need to be configured in the build configuration file.

The cache can be enabled as read only or write only with '-cacheread' or '-cachewrite'. This can be useful for automated build systems, where you might like one machine to populate the cache for read-only use by other users.

Use of '-cache' is equivalent to '-cachread' and '-cachewrite' together.

Emit summary of objects in the cache. This can be used to understand the total size of the cache and how quickly it is growing. (See the related [-cachetrim](#cachetrim))

Control compression level of items stored in the cache. (Default 1)

This can be used to increase the level of compression, trading increased CPU time when storing to the cache in order to reduce network transfer and storage. This can be useful in network bandwidth limited environments. Since decompression speed remains fairly constant, an increase in compression time may also be a worthwhile trade-off for environments that populate a cache once for many users to consume (an automated build environment for example).

This can also be used to reduce the level of compression, with the reverse considerations. This can be useful in CPU limited environments with high network bandwidth availability.

| Level | Description |
| --- | --- |
| \-128 to -1 | LZ4 compression. Lower values are faster but compress less. Default is -1. |
| 0 | Compression is disabled. |
| 1 to 12 | Zstd compression. Higher values compress more, but are slower. |

Timings will vary depending on hardware and objects being cached, but example timings compressing a ~4.3MiB object file is as follows:

File : Tools/FBuild/FBuildTest/Data/TestCompressor/TestObjFile.o Size : 4328135 Compression Decompression Level | Time (ms) MB/s Ratio | Time (ms) MB/s ------------------------------------------------ LZ4: 0 | 0.469 8792.0 1.00 | 0.383 10767.3 -256 | 1.237 3337.8 1.24 | 0.526 7845.0 -128 | 1.515 2724.1 1.42 | 0.605 6827.9 -64 | 2.103 1963.1 1.70 | 0.757 5453.7 -32 | 2.550 1618.5 2.06 | 0.838 4924.7 -16 | 2.740 1506.2 2.36 | 0.921 4480.6 -8 | 3.330 1239.6 2.80 | 1.047 3942.8 -4 | 3.540 1166.1 3.09 | 0.973 4240.5 -2 | 3.609 1143.7 3.23 | 1.008 4094.3 -1 | 3.597 1147.5 3.29 | 1.053 3918.5 **1 | 5.295 779.5 5.41 | 3.478 1186.8 <--- Default** 3 | 7.465 552.9 5.58 | 3.554 1161.3 6 | 22.845 180.7 5.93 | 3.549 1163.1 9 | 34.610 119.3 6.17 | 3.546 1164.1 12 | 89.984 45.9 6.20 | 3.423 1205.8

Reduce the size of the cache to the specified size in MiB. This will delete items in the cache (oldest first) until under the requested size. (See the related [-cacheinfo](#cacheinfo))

Provide additional information about cache interactions, including cache keys, explicit hit/miss/store information and performance metrics. This can be used to assist troubleshooting.

Force a clean build. The build configuration file is re-parsed and all existing dependency information is discarded. A build is performed as if building for the first time with no built files present.

Instead of building specified targets generate a [JSON compilation database](https://clang.llvm.org/docs/JSONCompilationDatabase.html) for them. Resulting compilation database will include entries for all source files from ObjectList and Library nodes that are dependencies of the specified targets.

Explicitly specify the config file to use. By default, FASTBuild looks for "fbuild.bff" in the current directory. This options allows a file to be explicitly specified instead.

Allow build to continue after a DB move.

FASTBuild's database is tied to the directory in which it was created and cannot be moved. If a move is detected, an error will be emitted. -continueafterdbmove allows the build to continue after this error has been emitted, ignoring and replacing the DB file.

Explicitly specify the dependency database file to use. By default, FASTBuild will load and save its dependency database in the same directory as the config file (with a ".platform.fdb" suffix). This option allows the file to be explicitly specified instead.

\[Windows Only] Display a message box on startup to allow a debugger to be attached. Can be useful if triaging problems with FASTBuild that can't be reproduced in the debugger.

Enable distributed compilation. Requires some build configuration.

Control compression level of jobs sent out for distribution. (Default -1)

This can be used to increase the level of compression for jobs sent out for distribution, trading increased CPU time in order to reduce network transfer. This can be useful in network bandwidth limited environments. Note that this value does not affect the compression level of the responses sent back from workers.

| Level | Description |
| --- | --- |
| \-128 to -1 | LZ4 compression. Lower values are faster but compress less. Default is -1. |
| 0 | Compression is disabled. |
| 1 to 12 | LZ4 HC compression. Higher values compress more, but are slower. |

Timings will vary depending on hardware and source code being preprocessed, but example timings compressing a ~1.8MiB flattened source file are as follows:

File : Tools/FBuild/FBuildTest/Data/TestCompressor/TestPreprocessedFile.ii Size : 1802697 Compression Decompression Level | Time (ms) MB/s Ratio | Time (ms) MB/s ------------------------------------------------ 0 | 0.289 5943.6 1.00 | 0.283 6066.8 -256 | 0.739 2324.8 1.25 | 0.224 7663.8 -128 | 0.822 2091.3 1.44 | 0.248 6944.6 -64 | 0.742 2315.8 1.86 | 0.356 4824.0 -32 | 1.027 1674.6 2.53 | 0.431 3989.9 -16 | 1.191 1443.5 3.37 | 0.467 3681.7 -8 | 1.311 1311.0 4.05 | 0.484 3550.5 -4 | 1.455 1181.6 4.53 | 0.511 3365.3 -2 | 1.423 1208.1 4.80 | 0.476 3614.2 **\-1 | 1.474 1166.2 4.94 | 0.507 3387.7 <--- Default** 1 | 2.312 743.6 5.43 | 0.489 3514.5 3 | 6.322 271.9 6.44 | 0.496 3469.3 6 | 11.180 153.8 6.67 | 0.416 4129.6 9 | 25.354 67.8 6.72 | 0.390 4411.8 12 | 86.380 19.9 6.82 | 0.386 4451.4 ------------------------------------------------

Print detailed information about distributed compilation. This can help when investigating connectivity issues. Activates -dist if not already specified.

Generate an fbuild.gv DOT file for known dependencies which can be visualized in various third party tools such as [Graphviz](https://graphviz.org/).

Example:

fbuild.exe -dot Game-x86-Debug

If no target is specified, "all" is used.

By default, all leaf FileNodes (typically source files) are pruned from the graph. A full graph can be emitted by using **\-dotfull**.

**NOTE:** The dependencies shown will reflect the state as of the last completed build. i.e. dependencies that would be discovered during the next build will not be shown.

**NOTE:** Large graphs may not be handled well by some visualizers.

Enables re-formatting of warnings, errors and notes for GCC/SNC & Clang to Visual Studio format. Additionally, relative paths are expanded to full paths. This allows these errors to be double-clickable inside Visual Studio.

Enabled automatically when '-vs' is used.

Prevents all local compilation of distributable jobs.

FASTBuild will normally utilize local CPU resources to compile distributable jobs in several situations, in order to improve performance:

-   When there are no remote workers available (otherwise build would not complete)
-   When all remote workers are busy and local CPUs would be idle
-   When blocked on remote work

This option prevents local consumption of distributable jobs in all these cases. This will generally result in slower builds and may even prevent the build completing entirely. As such, this options should generally only be used for troubleshooting.

Additionally, this option disabled use of the cache.

**NOTE:** This option can prevent builds from completing (if no workers are available for example).

**NOTE:** This option will generally degrade build performance.

Prints command line usage information, as per the summary at the top of this page.

IDE integration mode. Enables several options that are commonly desired when running from within an IDE such as VisualStudio, XCode or kDevelop. The following options are enabled:

-   [-noprogress](#noprogress)
-   [-fixuperrorpaths](#fixuperrorpaths) (Windows only)
-   [-wrapper](#wrapper) (Windows only)

**Generally, the default behaviour will give best performance, and this option should only be used in very specific situations.**

The -j\[x] option allows you to artificially control local parallelism by modifying the local thread pool size.

FASTBuild will normally determine the optimal number of local threads to use by detecting the number of hardware cores present on the host. The -j option allows you to override this.

Positive values for x can be used to set the number of tasks which can be performed locally in parallel. This can be used to limit CPU usage on a machine that needs to perform other work while compilation is in progress. Values greater than the number of physical processors are also accepted, but will almost always result in degraded performance.

A value of 0 for x indicates that no additional threads should be spawned, and build graph processing and compilation should occur on the same thread. This can be useful for build process debugging, especially when combined with the '-verbose' option.

This option has no direct bearing on distributed compilation, but modifying local parallelism will reduce the ability of FASTBuild to distribute work efficiently.

Output a machine readable file for use by 3rd party tools.

A machine readable file is written to %TEMP%/FastBuild/FastBuildLog.log and updated throughout the build. This file can be monitored by 3rd party applications to provide enhanced visualization of the build state.

Disable aborting other tasks as soon any task fails.

Normally, when a task fails, any tasks running on other threads are aborted (external processes are terminated), allowing builds with errors to fail quickly. If this behavior is undesirable, it can be disabled with -nofastcancel. If "fastcancel" is disabled, any already started tasks will be allowed to complete.

Disable local race of remotely started jobs. This can be useful for debugging.

**NOTE:** This option can prevent builds from completing (if remote workers become unresponsive for example).

**NOTE:** This option will generally degrade build performance.

Suppresses the progress bar that is normally shown while compiling.

This should be used when targetting compilation from within Visual Studio or another IDE. (or use -vs)

When encountering build errors, FASTBuild will normally stop as quickly as possible.

-nostoponerror instructs FASTBuild to instead build as much as possible before stopping when failures occur. This is useful if you want to see as many errors as possible in your compilation output.

NOTE: When specifying multiple targets to compile on the command line, -nostoponerror is implied.

The -nosummaryonerror option instructs FASTBuild to only print the -summary overview if the build completes successfully.

NOTE: When specifying -nosummaryonerror, -summary is implied if not already specified.

Individually build all files normally in Unity.

All files specified in Unity will instead be built as if specified individually outside of Unity.

Output a Chrome tracing format fbuild\_profile.json describing the build.

When "build profiling" is activing, scheduling information for items (local and remote) is recorded to an fbuild\_profile.json file. This file is written at the very end of the build, and can be viewed in Chrome's profiling viewer (chrome://tracing).

NOTE: This may have a small impact on build performance.

Show the build progress bar even if it would otherwise be disabled.

FASTBuild shows a build progress bar unless it detects that the stdout has been redirected (indicating that it's not being run from a command prompt). You can override this behavior and force the progress bar to be enabled using -progress.

Don't show build output. Information about which items are being built and the overall state of the build will be suppressed.

Output a detailed report at the end of the build. The report is written to a report.html or report.json file (default html if no option given) in the current directory.

The build report contains details of:

-   The build environment (version, cmd line used etc.)
-   All items built.
-   Cache utilization.
-   Include file usage.

NOTE: This option will lengthen the total build time, depending on the complexity of the build.

Displays the full output of external processes regardless of outcome.

Normally FASTBuild suppresses the output of external processes unless there are warnings or failures. In some cases (for debugging for example), it can be useful to see the complete output.

NOTE: This option may have an impact on build performance.

Displays the full command lines passed to external tools as they are invoked.

This option is useful for debugging build configurations, where the -verbose mode is too spammy.

NOTE: This option may have an impact on build performance.

Displays the hierearchy of dependencies for the specified target(s). This can be useful for debugging build configurations.

Example:

fbuild.exe -showdeps Game-x86-Debug

If no target is specified, "all" is used.

**NOTE:** The dependencies shown will reflect the state as of the last completed build. i.e. dependencies that would be discovered during the next build will not be shown.

Displays the list of targets defined in the bff configuration file, excluding those which have the .Hidden property set.

Displays the list of targets defined in the bff configuration file, including those which have the .Hidden property set.

Displays a summary upon build completion.

Show detailed diagnostic information for debugging.

This can be used to provide more information when debugging a build configuration problem. It will display detailed information as the build configuration is parsed, as well as detailed information during the build, including full command line arguments passed to external executables.

It is usually useful to combine this flag with [-j0](#jx) to serialize the build process and output (avoiding the output of different threads being mixed together).

Prints executable version information and exits. No configuration parsing or building is performed.

[Deprecated] VisualStudio mode - same is [-ide](#ide). Use [-ide](#ide) instead.

Queue build after an already running build completes.

Only one instance of FASTBuild can run at a time within the same root working directory. If you launch another FASTBuild while one is already running, the error "Another FASTBuild is already running." will be emitted.

If you wish to build multiple targets, you should specify them together on the command line. This allows for parallelization across both targets.

Alternatively, the -wait command line arg allows you to queue the second build, so instead of failing, it will start after the first build completes. This will be slower than if both targets were invoked together on the original command line.

While building, the reason for each item being built is shown. This can be useful for diagnosing unexpected dependencies.

Spawns FASTBuild via an intermediate sub-process to be able to cleanly terminate a build from Visual Studio.

When canceling a build in Visual Studio, the FASTBuild process will be killed, with no opportunity to save the build database, resulting in lost compilation work. Specifying this option spawns an orphaned child process to do the actual work. When the parent process is terminated by Visual Studio, the child process detects this and cleanly shuts down.

If a subsequent "wrapper mode" build is initiated before the first terminates, FASTBuild will wait for this first process to complete.

Invoke a command inside the Windows Subsystem for Linux.

It doesn't seem to be possible to invoke wsl.exe directly from Visual Studio as a BuildCommand. To allow this to be possible, FASTBuild can act as a forwarder using the -wsl command line option. This can be used to run the Linux version of FASTBuild for example.

Example:

fbuild.exe -wsl c:\\Windows\\System32\\wsl.exe ./FBuild-Linux Game-x64-Debug

## FBuildWorker.exe Detailed

Disable worker UI.

The FBuildWorker can run in a UI-less mode on Windows. (On OSX and Linux, the worker currently always runs in UI-less mode)

Control worker CPUs allocation.

The number of workers available is normally controlled through the UI of the FBuildWorker.exe. The "-cpus" command line option will override this as follows:

| Syntax | Description |
| --- | --- |
| -cpus=n | Value n will be used. |
| -cpus=-n | Value of NUMBER\_OF\_PROCESSORS-n will be used. |
| -cpus=n% | Specify number of CPUs as a percentage of NUMBER\_OF\_PROCESSORS. |

In all cases, the number used will be clamped between 1 and the NUMBER\_OF\_PROCESSORS environment variable.

NOTE: The newly overridden options will be saved and used on subsequent restarts of the worker.

[Windows Only] Display a message box on startup to allow a debugger to be attached. Can be useful if triaging problems with FASTBuild that can't be reproduced in the debugger.

[Windows Only] Override the default minimum memory limit (in MiB) from the default of 1024 (1 GiB). When a worked has less memory available than this amount it will not accept work.

minfreememory

Control worker availability.

The FBuildWorker.exe mode is normally controlled through the UI. The "-mode" command line option will override this as follows:

| Syntax | Description |
| --- | --- |
| -mode=disabled | Worker will accept no tasks. |
| -mode=idle | Worker will accept tasks when PC is considered idle. |
| -mode=dedicated | Worker will accept tasks regardless of PC state. |
| -mode=proportional | Worker will accept tasks proportional to PC's idle CPU power. |

NOTE: The newly overridden options will be saved and used on subsequent restarts of the worker.

Don't spawn a sub-process copy of the worker.

By default, when the FBuildWorker is launched, it makes a copy of itself (FBuildWorker.exe.copy), launches the copy and terminates. The duplicate process monitors the original executable file for changes, and re-launches itself if the file is updated. In this way, the FBuildWorker.exe can be kept under revision control, and when synchronized to a new version, will automatically re-start.

The "-nosubprocess" option suppresses this behaviour.

Restart worker every 4 hours.

If worker reliability issues are encountered, perhaps due to uncontrolable factors such as OS instability, network driver issues or as yet unresolved FASTBuild bugs, the worker can be instructed to periodically restart itself as a potential workaround.
