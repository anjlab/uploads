utils = @AnjLab.Uploads.Utils

class @AnjLab.Uploads.Uploader

  constructor: (element, options)->
    @$element = $(element)
    @options = $.extend(true, {}, $.fn.uploaderDefaults, @$element.data(), options)
    # number of files being uploaded
    @filesInProgress = []
    @storedFileIds = []
    @autoRetries = []
    @retryTimeouts = []
    @preventRetries = []

    @paramsStore = @createParamsStore()
    @endpointStore = @createEndpointStore()

    @handler = @createUploadHandler()
    @dnd = @createDragAndDrop()

    if @options.button
      @button = new AnjLab.Uploads.Button(@options.button, {
        multiple: @options.multiple && utils.isXhrUploadSupported()
        acceptFiles: @options.validation.acceptFiles
        onChange: (input)=>
          @onInputChange(input)
        hoverClass: @options.classes.buttonHover
        focusClass: @options.classes.buttonFocus
      })

  log: (str, level) ->
    if @options.debug && (!level || level == 'info')
      utils.log('[FineUploader] ' + str)
    else if level && level != 'info'
      utils.log('[FineUploader] ' + str, level)
    true

  setParams: (params, fileId) ->
    if fileId?
      @paramsStore.setParams(params, fileId)
    else
      @options.request.params = params

  setEndpoint: (endpoint, fileId) ->
    if fileId?
      @endpointStore.setEndpoint(endpoint, fileId)
    else
      @options.request.endpoint = endpoint

  getInProgress: -> @filesInProgress.length

  createDragAndDrop: ->
    new AnjLab.Uploads.DragAndDrop(@options.dropzones,
      {
        multiple: @options.multiple
        classes:
          dropActive: @options.classes.dropActive
          bodyDragover: @options.classes.bodyDragover
        callbacks:
          dropProcessing: (isProcessing, files) =>
            if files
              @addFiles(files)
          error: (code, filename) =>
            @error(code, filename)
          log: (message, level) =>
            @log(message, level)
      })
  
  uploadStoredFiles: ->
    while @storedFileIds.length
      idToUpload = @storedFileIds.shift()
      @filesInProgress.push(idToUpload)
      @handler.upload(idToUpload)

  clearStoredFiles: -> @storedFileIds = []

  retry: (id) ->
    if @onBeforeManualRetry(id)
      @handler.retry(id)
      true
    else
      false

  cancel: (fileId) ->
    @handler.cancel(fileId)

  reset: ->
    @log("Resetting uploader...")
    @handler.reset()
    @filesInProgress = []
    @storedFileIds = []
    @autoRetries = []
    @retryTimeouts = []
    @preventRetries = []
    @button.reset()
    @paramsStore.reset()
    @endpointStore.reset()


  addFiles: (filesOrInputs)->
    verifiedFilesOrInputs = []

    return if !filesOrInputs

    if !window.FileList || !(filesOrInputs instanceof FileList)
      filesOrInputs = [].concat(filesOrInputs)

    for fileOrInput in filesOrInputs
      if utils.isFileOrInput(fileOrInput)
        verifiedFilesOrInputs.push(fileOrInput);
      else
        @log("#{fileOrInput} is not a File or INPUT element!  Ignoring!", 'warn')
    @log("Processing #{verifiedFilesOrInputs.length} files or inputs...")
    @uploadFileList(verifiedFilesOrInputs)

  getUuid: (fileId) -> @handler.getUuid(fileId)
  getResumableFilesData: -> @handler.getResumableFilesData()
  getSize: (fileId) -> @handler.getSize(fileId)
  getFile: (fileId) -> @handler.getFile(fileId)

  createParamsStore: ->
    paramsStore = {}
    self = this

    {
      setParams: (params, fileId)->
        paramsStore[fileId] = $.extend(true, {}, params)
      getParams: (fileId) ->
        if fileId? && paramsStore[fileId]
          $.extend(true, {}, paramsStore[fileId])
        else
          $.extend(true, {}, self.options.request.params)
      remove: (fileId) -> delete paramsStore[fileId]
      reset: -> paramsStore = {}
    }

  createEndpointStore: () ->
    endpointStore = {}
    self = this

    {
      setEndpoint: (endpoint, fileId) ->
        endpointStore[fileId] = endpoint

      getEndpoint: (fileId) ->
        if fileId? && endpointStore[fileId]
          return endpointStore[fileId]

        self.options.request.endpoint;

      remove: (fileId) -> delete endpointStore[fileId]

      reset: -> endpointStore = {}
    }

  preventLeaveInProgress: ->
    $(window).on 'beforeunload', (e)=>
      return if !@filesInProgress.length

      e.returnValue = @options.messages.onLeave
  onSubmit: (id, fileName) ->
    if @options.autoUpload
      @filesInProgress.push(id)

  onProgress: (id, fileName, loaded, total) -> false

  onComplete: (id, fileName, result, xhr) ->
    @removeFromFilesInProgress(id)
    @maybeParseAndSendUploadError(id, fileName, result, xhr)

  onCancel: (id, fileName) ->
    @removeFromFilesInProgress(id)

    clearTimeout(@retryTimeouts[id])

    storedFileIndex = $.inArray(id, @storedFileIds)
    if !@options.autoUpload && storedFileIndex >= 0
      @storedFileIds.splice(storedFileIndex, 1)

  removeFromFilesInProgress: (id) ->
    index = $.inArray(id, @filesInProgress)
    if index >= 0
      @filesInProgress.splice(index, 1)

  onUpload: (id, fileName) -> null

  onInputChange: (input) ->
    if utils.isXhrUploadSupported()
      @addFiles(input.files)
    else
      @addFiles(input)
    @button.reset()

  onBeforeAutoRetry: (id, fileName) ->
    @log("Waiting #{@options.retry.autoAttemptDelay} seconds before retrying #{fileName}...")

  onAutoRetry: (id, fileName, responseJSON) ->
    @log("Retrying #{fileName}...")
    @autoRetries[id]++
    @handler.retry(id)

  shouldAutoRetry: (id, fileName, responseJSON) ->
    if !@preventRetries[id] && @options.retry.enableAuto
      if !@autoRetries[id]?
        @autoRetries[id] = 0

      return @autoRetries[id] < @options.retry.maxAutoAttempts

    false

  uploadFile: (fileContainer) ->
    id = @handler.add(fileContainer)
    fileName = @handler.getName(id)

    if @options.callbacks.onSubmit(id, fileName) != false
      @onSubmit(id, fileName)
      if @options.autoUpload
        @handler.upload(id)
      else
        @storeFileForLater(id)

  storeFileForLater: (id) -> @storedFileIds.push(id)

  parseFileSize: (file) ->
    size = null
    # fix missing properties in Safari 4 and firefox 11.0a2
    size = file.fileSize ? file.size if !file.value
    size

  formatSize: (bytes) ->
    i = -1;
    while true
      bytes = bytes / 1024
      i++
      break if bytes <= 99

    Math.max(bytes, 0.1).toFixed(1) + @options.text.sizeSymbols[i]

  parseFileName: (file) ->
    if file.value
      # it is a file input
      # get input value and remove path to normalize
      file.value.replace(/.*(\/|\\)/, "")
    else
      # fix missing properties in Safari 4 and firefox 11.0a2
      file.fileName ? file.name

  getValidationDescriptor: (file) ->
    fileDescriptor = {name: @parseFileName(file)}
    size = @parseFileSize(file)

    fileDescriptor.size = size if size

    fileDescriptor

  getValidationDescriptors: (files) ->
    @getValidationDescriptor(file) for file in files

  isAllowedExtension: (fileName) ->
    allowed = @options.validation.allowedExtensions

    return true if !allowed.length
      
    for allowedExt in allowed
      extRegex = new RegExp('\\.' + allowedExt + "$", 'i')

      return true if fileName.match(extRegex)?

    false

  validateFile: (file) ->
    validationDescriptor = @getValidationDescriptor(file)
    name = validationDescriptor.name
    size = validationDescriptor.size

    return false if @options.callbacks.onValidate(validationDescriptor) == false

    if !@isAllowedExtension(name)
      @error('typeError', name)
      false
    else if size == 0
      @error('emptyError', name)
      false
    else if size && @options.validation.sizeLimit && size > @options.validation.sizeLimit
      @error('sizeError', name)
      false
    else if (size && size < @options.validation.minSizeLimit)
      @error('minSizeError', name)
      false
    else
      true

  error: (code, fileName) ->
    message = @options.messages[code]
    r = (name, replacement) -> message = message.replace(name, replacement)

    extensions = @options.validation.allowedExtensions.join(', ').toLowerCase()

    r('{file}', @options.formatFileName(fileName))
    r('{extensions}', extensions)
    r('{sizeLimit}', @formatSize(@options.validation.sizeLimit))
    r('{minSizeLimit}', @formatSize(@options.validation.minSizeLimit))

    @options.callbacks.onError(null, fileName, message)

    message

  # return false if we should not attempt the requested retry
  onBeforeManualRetry: (id) ->
    if @preventRetries[id]
      @log("Retries are forbidden for id #{id}", 'warn')
      false
    else if @handler.isValid(id)
      fileName = @handler.getName(id);

      return false if @options.callbacks.onManualRetry(id, fileName) == false

      @log("Retrying upload for '#{fileName}' (id: #{id})...")
      @filesInProgress.push(id)
      true
    else
      @log("'#{id}' is not a valid file ID", 'error')
      false

  maybeParseAndSendUploadError: (id, fileName, response, xhr) ->
    # assuming no one will actually set the response code to something other than 200 and still set 'success' to true
    if !response.success
      if xhr && xhr.status != 200 && !response.error
        @options.callbacks.onError(id, fileName, "XHR returned response code #{xhr.status}")
      else
        errorReason = if response.error then response.error else "Upload failure reason unknown"
        @options.callbacks.onError(id, fileName, errorReason)

  uploadFileList: (files) ->
    validationDescriptors = @getValidationDescriptors(files)
    batchInvalid = @options.callbacks.onValidateBatch(validationDescriptors) == false
    if !batchInvalid
      if files.length > 0
        for file in files
          if @validateFile(file)
            @uploadFile(file)
          else
            return if @options.validation.stopOnFirstInvalidFile
      else
        @error('noFilesError', "")


  createUploadHandler: ->
    AnjLab.Uploads.UploadHandler.create({
      debug: @options.debug
      forceMultipart: @options.request.forceMultipart
      maxConnections: @options.maxConnections
      customHeaders: @options.request.customHeaders
      inputName: @options.request.inputName
      uuidParamName: @options.request.uuidName
      totalFileSizeParamName: @options.request.totalFileSizeName
      demoMode: @options.demoMode
      paramsStore: @paramsStore
      endpointStore: @endpointStore
      chunking: @options.chunking
      resume: @options.resume
      log: (str, level) => @log(str, level)

      onProgress: (id, fileName, loaded, total) =>
        @onProgress(id, fileName, loaded, total)
        @options.callbacks.onProgress(id, fileName, loaded, total)

      onComplete: (id, fileName, result, xhr) =>
        @onComplete(id, fileName, result, xhr)
        @options.callbacks.onComplete(id, fileName, result)

      onCancel: (id, fileName) =>
        @onCancel(id, fileName)
        @options.callbacks.onCancel(id, fileName)

      onUpload: (id, fileName) =>
        @onUpload(id, fileName)
        @options.callbacks.onUpload(id, fileName)

      onUploadChunk: (id, fileName, chunkData) =>
        @options.callbacks.onUploadChunk(id, fileName, chunkData)
      
      onResume: (id, fileName, chunkData) =>
        @options.callbacks.onResume(id, fileName, chunkData)

      onAutoRetry: (id, fileName, responseJSON, xhr) =>
        @preventRetries[id] = responseJSON[@options.retry.preventRetryResponseProperty]

        if @shouldAutoRetry(id, fileName, responseJSON)
          @maybeParseAndSendUploadError(id, fileName, responseJSON, xhr)
          @options.callbacks.onAutoRetry(id, fileName, self._autoRetries[id] + 1)
          @onBeforeAutoRetry(id, fileName)

          @retryTimeouts[id] = setTimeout( =>
            @onAutoRetry(id, fileName, responseJSON)
          , @options.retry.autoAttemptDelay * 1000
          )

          true
        else
          false
    })



$.fn.uploaderDefaults =
  debug: false
  button: null
  multiple: true
  maxConnections: 3
  disableCancelForFormUploads: false
  autoUpload: true
  request:
    endpoint: '/uploads'
    params: {}
    customHeaders: {}
    forceMultipart: true
    inputName: 'qqfile'
    uuidName: 'qquuid'
    totalFileSizeName: 'qqtotalfilesize'
  validation:
    allowedExtensions: []
    sizeLimit: 0
    minSizeLimit: 0
    stopOnFirstInvalidFile: true
  callbacks:
    onSubmit: (id, fileName) -> null
    onComplete: (id, fileName, responseJSON) -> null
    onCancel: (id, fileName) -> null
    onUpload: (id, fileName) -> null
    onUploadChunk: (id, fileName, chunkData) -> null
    onResume: (id, fileName, chunkData) -> null
    onProgress: (id, fileName, loaded, total) -> null
    onError: (id, fileName, reason) -> null
    onAutoRetry: (id, fileName, attemptNumber) -> null
    onManualRetry: (id, fileName) -> false
    onValidateBatch: (fileData) -> null
    onValidate: (fileData) -> null
  messages:
    typeError: "{file} has an invalid extension. Valid extension(s): {extensions}."
    sizeError: "{file} is too large, maximum file size is {sizeLimit}."
    minSizeError: "{file} is too small, minimum file size is {minSizeLimit}."
    emptyError: "{file} is empty, please select files again without it."
    noFilesError: "No files to upload.",
    onLeave: "The files are being uploaded, if you leave now the upload will be cancelled."
  retry:
    enableAuto: false
    maxAutoAttempts: 3
    autoAttemptDelay: 5
    preventRetryResponseProperty: 'preventRetry'
  classes:
    buttonHover: 'qq-upload-button-hover'
    buttonFocus: 'qq-upload-button-focus'
    bodyDragover: 'qq-upload-dragging'
  chunking:
    enabled: false
    partSize: 2000000
    paramNames:
      partIndex: 'qqpartindex'
      partByteOffset: 'qqpartbyteoffset'
      chunkSize: 'qqchunksize'
      totalFileSize: 'qqtotalfilesize'
      totalParts: 'qqtotalparts'
      filename: 'qqfilename'
  resume:
    enabled: false
    id: null
    cookiesExpireIn: 7 #days
    paramNames:
      resuming: "qqresume"
  text:
    sizeSymbols: ['kB', 'MB', 'GB', 'TB', 'PB', 'EB']

  formatFileName: (fileName)->
    if fileName.length > 33
      fileName = fileName.slice(0, 19) + '...' + fileName.slice(-14)
    fileName

$.fn.uploader = (option) ->
  this.each ->
    $this = $(this)
    data = $this.data('uploader')    
    if !data
      options = $.extend(true, {}, typeof option == 'object' && option)
      $this.data('uploader', (data = new AnjLab.Uploads.Uploader(this, options)))
    if (typeof option == 'string')
      data[option]()