utils = @AnjLab.Uploads.Utils

class @AnjLab.Uploads.UploadHandler
  constructor: (options)->
    @options = options
    @queue = []
    @log = options.log

  @create: (options) ->
    opts = $.extend(true, {}, $.fn.uploadHandlerDefaults, options)
    if utils.isXhrUploadSupported()
      new AnjLab.Uploads.UploadHandlerXhr(opts)
    else
      new AnjLab.Uploads.UploadHandlerForm(opts)

  # Removes element from queue, starts upload of next
  dequeue: (id) ->
    i = $.inArray(id, @queue)
    max = @options.maxConnections

    @queue.splice(i, 1)

    if @queue.length >= max && i < max
      nextId = @queue[max-1]
      @uploadFile(nextId)

  upload: (id) ->
    # if too many active uploads, wait...
    @uploadFile(id) if @queue.push(id) <= @options.maxConnections

  retry: (id) ->
    if $.inArray(id, @queue) >= 0
      @uploadFile(id, true)
    else
      @upload(id)

  cancel: (id) ->
      @log("Cancelling #{id}")
      @options.paramsStore.remove(id)
      @cancelFile(id)
      @dequeue(id)

  cancelAll: ->
    for fileId in @queue
      @cancel(fileId)

    @queue = []

  getQueue: -> @queue

  reset: ->
    @log('Resetting upload handler')
    @queue = []
    # all handers should call super in their resets

  uploadComplete: (id) -> @dequeue(id)

  # protocol for handlers to implement

  add: (file) -> @log('Not implemented')
  uploadFile: (id, m) -> @log('Not implemented')
  cancelFile: (id) -> @log('Not implemented')
  getName: (id) -> @log('Not implemented')  
  getUuid: (id) -> @log('Not implemented')
  isValid: (id) -> @log('Not implemented')
  getSize: (id) -> null
  getFile: (id) -> null
  getResumableFilesData: -> []

$.fn.uploadHandlerDefaults =
  debug: false
  forceMultipart: true
  paramsStore: {}
  endpointStore: {}
  maxConnections: 3 # maximum number of concurrent uploads
  uuidParamName: 'qquuid'
  totalFileSizeParamName: 'qqtotalfilesize'
  chunking:
    enabled: false
    partSize: 2000000 # bytes
    paramNames:
        partIndex: 'qqpartindex'
        partByteOffset: 'qqpartbyteoffset'
        chunkSize: 'qqchunksize'
        totalParts: 'qqtotalparts'
        filename: 'qqfilename'
  resume:
    enabled: false
    id: null
    cookiesExpireIn: 7 #days
    paramNames:
      resuming: "qqresume"

  log: (str, level) -> null
  onProgress: (id, fileName, loaded, total) -> null
  onComplete: (id, fileName, response, xhr) -> null
  onCancel: (id, fileName) -> null
  onUpload: (id, fileName) -> null
  onUploadChunk: (id, fileName, chunkData) -> null
  onAutoRetry: (id, fileName, response, xhr) -> null
  onResume: (id, fileName, chunkData) -> null