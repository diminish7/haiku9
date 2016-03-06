{createReadStream} = require "fs"
{join} = require "path"

{async} = require "fairmont"
mime = require "mime"

config = require "../../configuration"

# Uploads / Deletes S3 objects as neccessary from the target bucket.
module.exports = (s3) ->
  bucket = require("./s3")(s3)

  async ({dlist, ulist}) ->
    console.log "Syncing S3 bucket."
    # Delete Files
    try
      for file in dlist
        params =
          Bucket: config.s3.hostnames[0]
          Key: file

        yield s3.deleteObject params
    catch e
      console.error "Failed to delete object.", e
      throw new Error()

    # Cleanup any S3 pseudo "directories" emptied by the deletion.
    try
      data = yield bucket.list config.s3.hostnames[0], {}
      for k, v of data when k.match /.*\/$/ && v.size == 0
        params =
          Bucket: config.s3.hostnames[0]
          Key: k

        yield s3.deleteObject params
    catch e
      console.error "Failed to delete object.", e
      throw new Error()

    # Upload Files
    try
      for {file, hash} in ulist
        params =
          Bucket: config.s3.hostnames[0]
          Key: file.split(".html")[0]   # Strip ".html" extension for S3 key.
          ACL: "public-read"
          ContentType: mime.lookup file
          ContentMD5: new Buffer(hash, "hex").toString('base64')
          Body: createReadStream join config.target, file

        yield s3.putObject params
    catch e
      console.error "Failed to upload object.", e
      throw new Error()