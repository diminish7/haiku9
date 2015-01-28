// Generated by CoffeeScript 1.7.1
(function() {
  var Asset, C50N, CoffeeScript, FileSystem, all, attempt, basename, extname, glob, jade, join, md2html, promise, stylus, _ref, _ref1;

  FileSystem = require("fs");

  _ref = require("path"), basename = _ref.basename, extname = _ref.extname, join = _ref.join;

  glob = require("panda-glob");

  _ref1 = require("when"), promise = _ref1.promise, all = _ref1.all, attempt = _ref1.attempt;

  md2html = require("marked");

  jade = require("jade");

  stylus = require("stylus");

  C50N = require("c50n");

  CoffeeScript = require("coffee-script");

  Asset = (function() {
    Asset.read = function(path) {
      return promise(function(resolve, reject) {
        return FileSystem.readFile(path, {
          encoding: "utf8"
        }, function(error, content) {
          if (error == null) {
            return resolve(new Asset(path, content));
          } else {
            return reject(error);
          }
        });
      });
    };

    Asset.readFiles = function(files) {
      return promise(function(resolve, reject) {
        var file;
        if (files.length > 0) {
          return all((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = files.length; _i < _len; _i++) {
              file = files[_i];
              _results.push(Asset.read(file));
            }
            return _results;
          })()).then((function(_this) {
            return function(assets) {
              return resolve(assets);
            };
          })(this));
        } else {
          return resolve([]);
        }
      });
    };

    Asset.readDir = function(path) {
      return promise(function(resolve, reject) {
        return FileSystem.readdir(path, function(error, files) {
          var file;
          if (error == null) {
            return Asset.readFiles((function() {
              var _i, _len, _results;
              _results = [];
              for (_i = 0, _len = files.length; _i < _len; _i++) {
                file = files[_i];
                _results.push(join(path, file));
              }
              return _results;
            })()).then(function(assets) {
              return resolve(assets);
            });
          } else {
            return reject(error);
          }
        });
      });
    };

    Asset.glob = function(path, pattern) {
      return promise(function(resolve, reject) {
        var file;
        return Asset.readFiles((function() {
          var _i, _len, _ref2, _results;
          _ref2 = glob(path, pattern);
          _results = [];
          for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
            file = _ref2[_i];
            _results.push(join(path, file));
          }
          return _results;
        })()).then(function(assets) {
          return resolve(assets);
        });
      });
    };

    Asset.registerFormatter = function(_arg, formatter) {
      var from, to, _base, _base1;
      to = _arg.to, from = _arg.from;
      if (this.formatters == null) {
        this.formatters = {};
      }
      if ((_base = this.formatters)[from] == null) {
        _base[from] = {};
      }
      this.formatters[from][to] = formatter;
      if (this.formatsFor == null) {
        this.formatsFor = {};
      }
      if ((_base1 = this.formatsFor)[to] == null) {
        _base1[to] = [];
      }
      return this.formatsFor[to].push(from);
    };

    Asset.registerExtension = function(_arg) {
      var extension, format;
      extension = _arg.extension, format = _arg.format;
      if (Asset.extensions == null) {
        Asset.extensions = {};
      }
      Asset.extensions[extension] = format;
      if (Asset.extensionFor == null) {
        Asset.extensionFor = {};
      }
      return Asset.extensionFor[format] = extension;
    };

    Asset.extensionsForFormat = function(format) {
      var _i, _len, _ref2, _results;
      _ref2 = this.formatsFor[format];
      _results = [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        format = _ref2[_i];
        _results.push(this.extensionFor[format]);
      }
      return _results;
    };

    Asset.patternForFormat = function(format, name) {
      if (name == null) {
        name = "*";
      }
      return "" + name + ".{" + (this.extensionsForFormat(format)) + ",}";
    };

    Asset.globForFormat = function(path, format) {
      return this.glob(path, this.patternForFormat(format));
    };

    Asset.globNameForFormat = function(path, name, format) {
      return promise(function(resolve, reject) {
        return Asset.glob(path, Asset.patternForFormat(format, name)).then(function(assets) {
          var key, keys;
          keys = Object.keys(assets);
          if (keys.length > 0) {
            key = keys[0];
            return resolve(assets[key]);
          } else {
            return reject(new Error("Asset: No matching " + format + " asset found "), +(" for " + (join(path, name))));
          }
        })["catch"](function(error) {
          return reject(error);
        });
      });
    };

    function Asset(path, content) {
      var divider, error, extension, frontmatter;
      this.path = path;
      extension = extname(this.path);
      this.key = basename(this.path, extension);
      this.format = Asset.extensions[extension.slice(1)];
      divider = content.indexOf("\n---\n");
      if (divider >= 0) {
        frontmatter = content.slice(0, +(divider - 1) + 1 || 9e9);
        try {
          this.data = C50N.parse(frontmatter);
        } catch (_error) {
          error = _error;
          console.log(error);
        }
        this.content = content.slice(divider + 5);
      } else {
        this.content = content;
      }
    }

    Asset.prototype.render = function(format, context) {
      var formatter, _ref2;
      if (context == null) {
        context = this.context;
      }
      formatter = (_ref2 = Asset.formatters[this.format]) != null ? _ref2[format] : void 0;
      if (formatter == null) {
        formatter = Asset.identityFormatter;
      }
      if (context == null) {
        context = {};
      }
      context.filename = this.path;
      return formatter(this.content, context);
    };

    return Asset;

  })();

  Asset.registerExtension({
    extension: "md",
    format: "markdown"
  });

  Asset.registerExtension({
    extension: "jade",
    format: "jade"
  });

  Asset.registerExtension({
    extension: "styl",
    format: "stylus"
  });

  Asset.registerExtension({
    extension: "coffee",
    format: "coffeescript"
  });

  Asset.registerExtension({
    extension: "js",
    format: "javascript"
  });

  Asset.identityFormatter = function(content) {
    return promise(function(resolve, reject) {
      return resolve(content);
    });
  };

  Asset.registerFormatter({
    to: "html",
    from: "markdown"
  }, function(markdown) {
    return attempt(md2html, markdown);
  });

  Asset.registerFormatter({
    to: "html",
    from: "jade"
  }, function(markup, context) {
    context.cache = true;
    return attempt(jade.renderFile, context.filename, context);
  });

  Asset.registerFormatter({
    to: "css",
    from: "stylus"
  }, function(code) {
    return attempt(stylus.render, code);
  });

  Asset.registerFormatter({
    to: "javascript",
    from: "coffeescript"
  }, function(code) {
    return attempt(CoffeeScript.compile, code);
  });

  module.exports = Asset;

}).call(this);