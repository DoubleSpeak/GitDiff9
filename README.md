
# GitDiff9  - GitDiff for Xcode 9

A port of GitDiff to Xcode 9 inside an extensible framework of generalised providers of line number gutter highlights. This version of GitDiff provides four types of line number lighlights

* Unstaged differences against a project's git repo
* Highlight of changes comitted in the last week
* Format linting hints provided by swiftformat and clang-format
* an indication that code in unused using the Xcode 8 indexdb

To use, clone this project and build targte LNXcodeSupport. You'll need to unsign you Xcode binary for the Xcode side of the plugin to load. The user interface is largely as it was before. If differences don't display switch away and back to the file you're editing. The plugin runs a menubar app which contains plugin preferences and allows you to turn on and off individual highlights.

![Icon](http://johnholdsworth.com/gitdiff9.png)

Lines that have been changed are highlighted in amber, new lines highighted in blue. Code lint suggestions are highlighted in dark blue and lines with a recent commit (the last 7 days by default) are highlighted in light green, fading with time. If you would like to revert the code change or apply the lint suggestion, hover over the highlight until a button appears and press it. See the document "LineNumberPlugin.pages" for details about the XPC based architecture.

### Expandability

The new implementation has been generalised to provide line number highlighting as a service from inside the new Xcode plugin. The project includes an menubar app "LNProvider" which is run to provide the default implementations out of process using XPC. Any application can register with the plugin to provide line number highlights if it follow the distributed objects protocol documented in LNExtensionProtocol.h. Whenever a file is saved or reloaded a call is made to your application's client to the plugin to provide JSON describing the intended highlights.
