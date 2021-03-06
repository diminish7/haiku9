{join} = require "path"
program = require "commander"
{call, read} = require "fairmont"

require "./index"
{run} = require "panda-9000"

call ->

  {version} = JSON.parse yield read join __dirname, "..", "package.json"

  program
    .version(version)

  program
    .command('serve')
    .description('run a Web server to serve your content')
    .action(-> run "serve")

  program
    .command('build')
    .description('compile the Website assets into the "target" directory')
    .action(-> run "build")

  program
    .command('publish [env]')
    .description('deploy Website assets from "target" to AWS infrastructure')
    .action(
      (env)->
        if !env
          console.error "No environment has been provided."
          console.error "Usage: h9 publish <environment>"
          process.exit 1

        run "publish", [env]
    )


  # Begin execution.
  program.parse(process.argv);
