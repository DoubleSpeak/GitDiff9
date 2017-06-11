
# GitDiff9  - GitDiff for Xcode 9

A port of GitDiff to Xcode 9 inside an extensible framework of generalised providers of line number gutter highlights. This version of GitDiff provides four types of line number lighlights

* Unstaged differences against a project's git repo
* Highlight of changes comitted in the last week
* Format linting hints provided by swiftformat and clang-format
* an indication that code is unused using an Xcode 8 indexdb

To use, clone this project and build targte LNXcodeSupport. You'll need to unsign you Xcode binary for the Xcode side of the plugin to load. The user interface is largely as it was before. If differences don't display switch away and back to the file you're editing.

![Icon](http://johnholdsworth.com/gitdiff9.png)

Lines that have been changed relative to the repo are highlighted in amber, new lines highighted in blue. Code lint suggestions are highlighted in dark blue and lines with a recent commit (the last 7 days by default) are highlighted in light green, fading with time. Hovering over a chnage or lint highlight will overlay the previous or suggested version over the source edior and if you would like to revert the code change or apply a lint suggestion, hover over the highlight until a small button appears and press it. The plugin runs a menubar app which contains color preferences and allows you to turn on and off individual highlights.

![Icon](http://johnholdsworth.com/lnprovider9a.png)

### Expandability

The new implementation has been generalised to provide line number highlighting as a service from inside the new Legacy Xcode plugin. The project includes an menubar app "LNProvider" which is run to provide the default implementations out of process using XPC. Any application can register with the plugin to provide line number highlights if it follow the Distributed Objects protocol documented in LNExtensionProtocol.h. Whenever a file is saved or reloaded a call is made by the plugin to your application to provide JSON describing the intended highlights. See the document "LineNumberPlugin.pages" for details about the XPC based architecture.

![Icon](http://johnholdsworth.com/lnprovider9b.png)

### Code linting

Contains binary releases of [swiftformat](https://github.com/nicklockwood/SwiftFormat) and [clang-format](https://clang.llvm.org/docs/ClangFormatStyleOptions.html) under their respective licenses. To modify linting preferences, edit the files swift_format.sh and clang_format.sh in the "FormatImpl" directory and rebuild.
