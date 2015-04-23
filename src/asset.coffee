{include, read, read_buffer, write, readdir, async, keys,
  first, rest, collect, map, binary, curry} = require "fairmont"
{createReadStream} = require "fs"
{dirname, basename, extname, join, resolve} = require "path"
join = curry binary join
{attempt, promise} = require "when"
glob = require "panda-glob"
md2html = require "marked"
jade = require "jade"
stylus = require "stylus"
yaml = require "js-yaml"
CoffeeScript = require "coffee-script"

class Asset

  @create: (path) -> new Asset path

  @map: (paths) ->
    (Asset.create path) for path in paths

  @readDir: async (path) ->
    files = yield readdir path
    Asset.map (collect map (join path), files)

  @glob: (path, pattern) ->
    files = glob path, pattern
    Asset.map (collect map (join path), files)

  @registerFormatter: ({to, from}, formatter) ->
    @formatters ?= {}
    @formatters[from] ?= {}
    @formatters[from][to] = formatter
    @formatsFor ?= {}
    @formatsFor[to] ?= []
    @formatsFor[to].push from

  @formatterFor: (source, target) ->
    formatter = Asset.formatters[source]?[target]
    formatter ?= Asset.identityFormatter

  @registerExtension: ({extension, format}) ->
    Asset.extensions ?= {}
    Asset.extensions[extension] = format
    Asset.extensionFor ?= {}
    Asset.extensionFor[format] = extension

  @extensionsForFormat: (format) ->
    formats = @formatsFor[format]
    if formats?
      for format in [format, formats...]
        @extensionFor[format]
    else
      [format]

  @patternForFormat: (format, name="*") ->
    @patternForFormats [format], name

  @patternForFormats: (formats, name="*") ->
    extensions = map (format) => @extensionsForFormat format
    "#{name}.{#{collect extensions formats},}"

  @globNameForFormat: (path, name, formats...) ->
     Asset.glob path, Asset.patternForFormats formats, name

  constructor: (@path) ->
    extension = extname @path
    @extension = rest extension
    @key = basename @path, extension
    @format = Asset.extensions[@extension]
    @format ?= @extension
    @target = {}
    formatters = Asset.formatters[@format]
    @supportedFormats = if formatters? then keys formatters else [@format]
    @target.format = first @supportedFormats
    @target.extension = Asset.extensionFor[@target.format]
    @target.extension ?= @target.format

  targetPath: (path) ->
    if @target.extension?
      join path, "#{@key}.#{@target.extension}"
    else
      join path, @key

  write: async (path) ->
    write (@targetPath path), yield @render()

    # divider = content.indexOf("\n---\n")
    # if divider >= 0
    #   frontmatter = content[0...divider]
    #   try
    #     @data = yaml.safeLoad frontmatter
    #   catch error
    #     @data = {}
    #   @content = content[(divider+5)..]
    # else
    #   @content = content

  render: ->
    ((Asset.formatterFor @format, @target.format) @)


Asset.registerExtension extension: "md", format: "markdown"
Asset.registerExtension extension: "jade", format: "jade"
Asset.registerExtension extension: "styl", format: "stylus"
Asset.registerExtension extension: "coffee", format: "coffeescript"
Asset.registerExtension extension: "js", format: "javascript"

Asset.identityFormatter = async ({path}) -> yield read_buffer path

# NOTES:
# This does not work. A couple of templates get an error that Jade thinks is on
# line 3 of the markdown file, but are related to something else. I don't know
# what it is. It's not the markdown, because I've tried pre-compiling the
# markdown, as shown below. The errors reference `url` and `action` properties
# of something, but I can't figure out what that is referencing. It's not
# anything in the Jade source, nor in the various templates being compiled,
# nor in the Haiku9 source.
#
# I can't view the render function itself because it's just a wrapper that
# Jade generates. The debugging output is indecipherable.
#
# In addition to this problem, we still have to provide support for partials
# and include the data for the specific file in the context. These two
# things are relatively easy to do, but the whole thing feels rickety.
#
# For example, the errors generated by processing the generated templates
# obviously reference the wrong file. That's going to be very annoying when
# you have an error in the markdown. I can probably fix that, but there are
# a lot of these little disconnects between the way these things want to
# work and the way I'm using them.
#
# We have a couple of possibilities here. One is to simplify things. For
# example, each blog post could become a directory. There would be a simple
# markdown wrapper, the _data file, and the markdown itself. We can ease
# creation of all this with a generator script.
#
# Similarly, in the case where we're using the `partial` function to render
# files within a loop, and the pathname is generated dynamically. We could
# simply include the markdown for each file (it's not much different than
# putting each name in a _data.json file).
#
# That keeps the Asset framework itself fairly simple. However, the drawback
# is that we still have some weirdness. Blog posts being directories is
# weird. The whole `_data.json` thing is weird. (And having to reference the
# data using a `_data` property feels unnatural.)
#
# More generally, it feels a lot like the Assets need to know about the
# asset tree itself. For example, when computing the path for the right
# layout file, the code below will go into an infinite loop if there is
# no layout file. The issue here is that they don't know what the root
# directory is, even though we have that information when we compile
# the tree. Similarly, a `partial`-style function ideally can just
# glob to any asset in the tree. That's actually do-able right now,
# but the relative path can, again, actually reference things outside
# of the root (source) directory because we don't know what that is.
#
# On the other hand, we're pretty close now…if I just add an appropriate
# dynamic include function, that might solve a lot of problems. We can
# add values into the meta-tree for each file easily enough. The values of
# those can be the data object, which could just have the same name, only
# with a different extension. Or we could just do front-matter. You wouldn't
# need data associated with a directory, but even if you did, you could
# just create an arbitrarily named JSON/YAML file for it. It really wouldn't
# be associated with a directory, it would just be another property of the
# tree. So maybe we're not too far off…maybe we just need to add the root
# directory to the asset properties and then incrementally add this other
# stuff (an include function and the data-per-file bit).
#
# That just leaves layout. If a markdown file can be linked to a Jade layout
# file, ala Harp and Jekyll, and we don't want to generate a Jade file on
# the fly (which we don't, see below), we actually need to render the layout
# file and pass in the reference to the markdown so it can be referenced
# via the include function.
#
# I was hoping to come up with something a bit more elegant, especially since
# Jade already has primitives for supporting layout and includes.

Asset.registerFormatter
  to: "html"
  from:  "markdown"
  async (asset) -> # md2html yield read asset.path
    if !asset.renderer?
      directory = dirname asset.path
      layout = "_layout"
      until layout.length > 13 || "_layout.jade" in (yield readdir directory)
        directory = resolve directory, ".."
        layout = join "..", layout
      html = (md2html (yield read asset.path))
        .replace /#\{/gm, "&num;{"
        .replace /\n/gm, "\n    "
      template = """
        extends #{layout}
        block content
          :verbatim
            #{html}
      """
      asset.renderer = jade.compile template,
        cache: false, filename: asset.path
    try
      asset.renderer asset.context
    catch
      # we ignore the Jade error since it references the markdown
      # instead of our generated file. we could dump the template
      # file and re-run the processor, but that still isn't very
      # useful--Jade doesn't 'see into' filters.
      throw "Unable to render markdown in #{asset.path}"


Asset.registerFormatter
  to: "html"
  from:  "jade"
  (asset) ->
    {path} = asset
    asset.renderer ?= jade.compileFile path, cache: false
    asset.renderer asset.context

Asset.registerFormatter
  to: "css"
  from:  "stylus"
  async ({path}) ->
    stylus (yield read path)
    .set "filename", path
    .render()

Asset.registerFormatter
  to: "javascript"
  from:  "coffeescript"
  async ({path}) ->
    CoffeeScript.compile (yield read path)

module.exports = Asset
