utils = @AnjLab.Uploads.Utils

class @AnjLab.Uploads.UploadHandlerXhr extends @AnjLab.Uploads.UploadHandler

  constructor: (options)->
    super(options)
    @fileState = []
    @cookieItemDelimiter = "|"
    @chunkFiles = @options.chunking.enabled && utils.isFileChunkingSupported()
    @resumeEnabled = @options.resume.enabled && @chunkFiles && utils.areCookiesEnabled()
    @resumeId = @getResumeId()
    @multipart = @options.forceMultipart

  addChunkingSpecificParams: (id, params, chunkData)->
    size = @getSize(id)
    name = @getName(id);

    params[@options.chunking.paramNames.partIndex] = chunkData.part
    params[@options.chunking.paramNames.partByteOffset] = chunkData.start
    params[@options.chunking.paramNames.chunkSize] = chunkData.end - chunkData.start
    params[@options.chunking.paramNames.totalParts] = chunkData.count
    params[@options.totalFileSizeParamName] = size


    
    # When a Blob is sent in a multipart request, the filename value in the content-disposition header is either "blob"
    # or an empty string.  So, we will need to include the actual file name as a param in this case.
    if @multipart
      params[@options.chunking.paramNames.filename] = name

  addResumeSpecificParams: (params) ->
    params[@options.resume.paramNames.resuming] = true

  getChunk: (file, startByte, endByte) ->
    if file.slice
      file.slice(startByte, endByte)
    else if file.mozSlice
      file.mozSlice(startByte, endByte)
    else if file.webkitSlice
      file.webkitSlice(startByte, endByte)

  getChunkData: (id, chunkIndex) ->
    chunkSize = @options.chunking.partSize
    fileSize = @getSize(id)
    file = @fileState[id].file
    startBytes = chunkSize * chunkIndex
    endBytes = startBytes+chunkSize >= if fileSize then fileSize else startBytes+chunkSize
    totalChunks = @getTotalChunks(id)

    {
      part: chunkIndex
      start: startBytes
      end: endBytes
      count: totalChunks,
      blob: @getChunk(file, startBytes, endBytes)
    }

  getTotalChunks: (id) ->
    Math.ceil(@getSize(id) / @options.chunking.partSize)

  createXhr: (id) ->
    @fileState[id].xhr = new XMLHttpRequest()
    # fileState[id].xhr

  setParamsAndGetEntityToSend: (params, xhr, fileOrBlob, id) ->
    formData = new FormData()
    protocol = if @options.demoMode then "GET" else "POST"
    endpoint = @options.endpointStore.getEndpoint(id)
    url = endpoint
    name = @getName(id)
    size = @getSize(id)

    params[@options.uuidParamName] = @fileState[id].uuid;

    params[@options.totalFileSizeParamName] = size if @multipart

    params[@options.inputName] = name
    params['_' + @options.inputName] = name
    params['utf8'] = '✓'

    csrf_param = $("meta[name=csrf-param]").attr("content")
    csrf_token = $("meta[name=csrf-token]").attr("content")

    params[csrf_param] = csrf_token

    url = endpoint + (if /\?/.test(url) then '&' else '?') + $.param(params)

    xhr.open protocol, url, true
    fileOrBlob

  setHeaders: (id, xhr) ->
      extraHeaders = @options.customHeaders
      name = @getName(id)
      file = @fileState[id].file

      xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");
      xhr.setRequestHeader("Cache-Control", "no-cache");

      xhr.setRequestHeader("Content-Type", "application/octet-stream");
      # NOTE: return mime type in xhr works on chrome 16.0.9 firefox 11.0a2
      xhr.setRequestHeader("X-Mime-Type", file.type);

      for own name, val of extraHeaders
        xhr.setRequestHeader(name, val)

  handleCompletedFile: (id, response, xhr) ->
    name = @getName(id)
    size = @getSize(id)

    @fileState[id].attemptingResume = false

    @options.onProgress(id, name, size, size)

    @options.onComplete(id, name, response, xhr)
    delete @fileState[id].xhr
    @uploadComplete(id)

  handleSuccessfullyCompletedChunk: (id, response, xhr) ->
    chunkIdx = @fileState[id].remainingChunkIdxs.shift()
    chunkData = @getChunkData(id, chunkIdx)

    @fileState[id].attemptingResume = false
    @fileState[id].loaded += chunkData.end - chunkData.start

    if @fileState[id].remainingChunkIdxs.length > 0
      @uploadNextChunk(id)
    else 
      @deletePersistedChunkData(id)
      @handleCompletedFile(id, response, xhr)

  isErrorResponse: (xhr, response) ->
    xhr.status != 200 || !response.success || response.reset

  parseResponse: (xhr) ->
    try
      utils.parseJson(xhr.responseText)
    catch error
      @log("Error when attempting to parse xhr response text (#{error})", 'error');
      {}

  handleResetResponse: (id)->
    @log('Server has ordered chunking effort to be restarted on next attempt for file ID ' + id, 'error');

    if @resumeEnabled
      @deletePersistedChunkData(id)
    @fileState[id].remainingChunkIdxs = []
    delete @fileState[id].loaded

  handleResetResponseOnResumeAttempt: (id) ->
    @fileState[id].attemptingResume = false
    @log("Server has declared that it cannot handle resume for file ID " + id + " - starting from the first chunk", 'error');
    @uploadFile(id, true)

  getChunkDataForCallback: (chunkData) ->
    {
      partIndex: chunkData.part
      startByte: chunkData.start + 1
      endByte: chunkData.end
      totalParts: chunkData.count
    }

  getReadyStateChangeHandler: (id, xhr) ->
    => @onComplete(id, xhr) if xhr.readyState == 4

  persistChunkData: (id, chunkData) ->
    fileUuid = @getUuid(id)
    cookieName = @getChunkDataCookieName(id)
    cookieValue = fileUuid + @cookieItemDelimiter + chunkData.part
    cookieExpDays = @options.resume.cookiesExpireIn

    utils.setCookie(cookieName, cookieValue, cookieExpDays)

  deletePersistedChunkData: (id) ->
    cookieName = @getChunkDataCookieName(id)

    utils.deleteCookie(cookieName)

  getPersistedChunkData: (id) ->
    chunkCookieValue = utils.getCookie(@getChunkDataCookieName(id))

    return if !chunkCookieValue

    delimiterIndex = chunkCookieValue.indexOf(@cookieItemDelimiter)
    uuid = chunkCookieValue.substr(0, delimiterIndex)
    partIndex = parseInt(chunkCookieValue.substr(delimiterIndex + 1, chunkCookieValue.length - delimiterIndex), 10)

    {
      uuid: uuid
      part: partIndex
    }

  handleNonResetErrorResponse: (id, response, xhr) ->
    return if @options.onAutoRetry(id, @getName(id), response, xhr)

    @handleCompletedFile(id, response, xhr)

  getChunkDataCookieName: (id) ->
    filename = @getName(id)
    fileSize = @getSize(id)
    maxChunkSize = @options.chunking.partSize

    parts = ['qqfilechunk', encodeURIComponent(filename), fileSize, maxChunkSize]
    parts << @resumeId if @resumeId?
    parts.join(@cookieItemDelimiter)

  getResumeId: ->
    @options.resume.id if @options.resume.id? &&
        !$.isFunction(@options.resume.id) &&
        !$.isObject(@options.resume.id)

  uploadNextChunk: (id) ->
    chunkData = @getChunkData(id, @fileState[id].remainingChunkIdxs[0])
    xhr = @createXhr(id)
    size = @getSize(id)
    name = @getName(id)

    if @fileState[id].loaded?
        @fileState[id].loaded = 0

    @persistChunkData(id, chunkData)

    xhr.onreadystatechange = @getReadyStateChangeHandler(id, xhr)

    xhr.upload.onprogress = (e) =>
      if e.lengthComputable
        if @fileState[id].loaded < size
          totalLoaded = e.loaded + @fileState[id].loaded
          @options.onProgress(id, name, totalLoaded, size)

    @options.onUploadChunk(id, name, @getChunkDataForCallback(chunkData))

    params = @options.paramsStore.getParams(id)
    @addChunkingSpecificParams(id, params, chunkData)

    @addResumeSpecificParams(params) if @fileState[id].attemptingResume
      
    toSend = @setParamsAndGetEntityToSend(params, xhr, chunkData.blob, id);
    @setHeaders(id, xhr)

    @log('Sending chunked upload request for ' + id + ": bytes " + (chunkData.start+1) + "-" + chunkData.end + " of " + size);
    xhr.send(toSend)

  onComplete: (id, xhr) ->
    # the request was aborted/cancelled
    return if !@fileState[id]

    @log("xhr - server response received for " + id)
    @log("responseText = " + xhr.responseText)

    response = @parseResponse(xhr)

    if @isErrorResponse(xhr, response)
      if response.reset
        @handleResetResponse(id);

      if @fileState[id].attemptingResume && response.reset
        @handleResetResponseOnResumeAttempt(id)
      else
        @handleNonResetErrorResponse(id, response, xhr)
    else if @chunkFiles
      @handleSuccessfullyCompletedChunk(id, response, xhr)
    else
      @handleCompletedFile(id, response, xhr)

  handleFileChunkingUpload: (id, retry) ->
    name = @getName(id)
    firstChunkIndex = 0

    if !@fileState[id].remainingChunkIdxs || @fileState[id].remainingChunkIdxs.length == 0
      @fileState[id].remainingChunkIdxs = []

      if @resumeEnabled && !retry
        persistedChunkInfoForResume = @getPersistedChunkData(id);
        if persistedChunkInfoForResume
          firstChunkDataForResume = @getChunkData(id, persistedChunkInfoForResume.part)
          if @options.onResume(id, name, @getChunkDataForCallback(firstChunkDataForResume)) != false
            firstChunkIndex = persistedChunkInfoForResume.part
            @fileState[id].uuid = persistedChunkInfoForResume.uuid
            @fileState[id].loaded = firstChunkDataForResume.start
            @fileState[id].attemptingResume = true
            @log('Resuming ' + name + " at partition index " + firstChunkIndex)

      currentChunkIndex = @getTotalChunks(id) - 1
      while currentChunkIndex >= firstChunkIndex
        @fileState[id].remainingChunkIdxs.unshift(currentChunkIndex)
        currentChunkIndex -= 1

    @uploadNextChunk(id)

  handleStandardFileUpload: (id)->
    file = @fileState[id].file
    name = @getName(id)

    @fileState[id].loaded = 0

    xhr = @createXhr(id)

    xhr.upload.onprogress = (e) =>
      if e.lengthComputable
        @fileState[id].loaded = e.loaded
        @options.onProgress(id, name, e.loaded, e.total)

    xhr.onreadystatechange = @getReadyStateChangeHandler(id, xhr)

    params = @options.paramsStore.getParams(id);
    toSend = @setParamsAndGetEntityToSend(params, xhr, file, id)
    @setHeaders(id, xhr)

    @log('Sending upload request for ' + id)
    xhr.send(toSend)

  # Adds file to the queue
  # Returns id to use with upload, cancel
  add: (file) ->
    if !(file instanceof File)
      throw new Error('Passed obj in not a File (in qq.UploadHandlerXhr)');

    id = @fileState.push(file: file) - 1
    @fileState[id].uuid = utils.getUniqueId()

    id

  getName: (id) ->
    file = @fileState[id].file
    # fix missing name in Safari 4
    #NOTE: fixed missing name firefox 11.0a2 file.fileName is actually undefined
    file.fileName ? file.name

  getSize: (id) ->
    file = @fileState[id].file
    file.fileSize ? file.size

  getFile: (id) ->
    return @fileState[id].file if @fileState[id]

  # Returns uploaded bytes for file identified by id
  getLoaded: (id) -> @fileState[id].loaded || 0

  isValid: (id) -> @fileState[id]?

  reset: =>
    super()
    @fileState = []

  getUuid: (id) -> @fileState[id].uuid

  # Sends the file identified by id to the server
  uploadFile: (id, retry) ->
    name = @getName(id)

    @options.onUpload(id, name)

    if @chunkFiles
      @handleFileChunkingUpload(id, retry)
    else
      @handleStandardFileUpload(id)

  cancelFile: (id) ->
    @options.onCancel(id, @getName(id))

    @fileState[id].xhr.abort() if @fileState[id].xhr
        
    @deletePersistedChunkData(id) if @resumeEnabled

    delete @fileState[id]

  getResumableFilesData: ->
    matchingCookieNames = []
    resumableFilesData = []

    if @chunkFiles && @resumeEnabled
      if !@resumeId?
        matchingCookieNames = utils.getCookieNames(new RegExp("^qqfilechunk\\" + @cookieItemDelimiter + ".+\\" +
                  @cookieItemDelimiter + "\\d+\\" + @cookieItemDelimiter + @options.chunking.partSize + "="))
      else
        matchingCookieNames = utils.getCookieNames(new RegExp("^qqfilechunk\\" + @cookieItemDelimiter + ".+\\" +
              @cookieItemDelimiter + "\\d+\\" + @cookieItemDelimiter + @options.chunking.partSize + "\\" +
              @cookieItemDelimiter + @resumeId + "="))


      for cookieName in matchingCookieNames
        cookiesNameParts = cookieName.split(@cookieItemDelimiter)
        cookieValueParts = utils.getCookie(cookieName).split(@cookieItemDelimiter)

        resumableFilesData.push
          name: decodeURIComponent(cookiesNameParts[1])
          size: cookiesNameParts[2]
          uuid: cookieValueParts[0]
          partIdx: cookieValueParts[1]

      resumableFilesData
    else
      []