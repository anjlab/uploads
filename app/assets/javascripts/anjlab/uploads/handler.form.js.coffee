utils = @AnjLab.Uploads.Utils

class @AnjLab.Uploads.UploadHandlerForm extends @AnjLab.Uploads.UploadHandler

  constructor: (options)->
    super(options)
    @inputs = []
    @uuids = []
    @detachLoadEvents = {}

  attachLoadEvent: (iframe, callback)->
    detach = =>
      return if !@detachLoadEvents[iframe.id]
      @log('Received response for ' + iframe.id)
      # when we remove iframe from dom
      # the request stops, but in IE load
      # event fires
      return if !iframe.parentNode

      try
        # fixing Opera 10.53
        # In Opera event is fired second time
        # when body.innerHTML changed from false
        # to server response approx. after 1 sec
        # when we upload file with iframe
        return if iframe.contentDocument?.body?.innerHTML == 'false'

      catch error
        #IE may throw an "access is denied" error when attempting to access contentDocument on the iframe in some cases
        @log("Error when attempting to access iframe during handling of upload response (#{error})", 'error')

      callback()
      delete @detachLoadEvents[iframe.id]
    
    @detachLoadEvents[iframe.id] = detach
    $(iframe).on 'load', detach

  # Returns json object received by iframe from server.
  getIframeContentJson: (iframe)->
    # IE may throw an "access is denied" error when attempting to access contentDocument on the iframe in some cases
    try
      # iframe.contentWindow.document - for IE<7
      doc = iframe.contentDocument || iframe.contentWindow.document
      innerHTML = doc.body.innerHTML

      @log "converting iframe's innerHTML to JSON"
      @log "innerHTML = #{innerHTML}"
      # plain text response may be wrapped in <pre> tag
      if innerHTML && innerHTML.match(/^<pre/i)
        innerHTML = doc.body.firstChild.firstChild.nodeValue

      utils.parseJson(innerHTML)
    catch error
      @log "Error when attempting to parse form upload response (#{error })", 'error'
      {success: false}

  # Creates iframe with unique name
  createIframe: (id)->
    # We can't use following code as the name attribute
    # won't be properly registered in IE6, and new window
    # on form submit will open
    # var iframe = document.createElement('iframe');
    # iframe.setAttribute('name', id);

    iframe = $("<iframe src='javascript:false;' name='#{id}' />")[0]
    # src="javascript:false;" removes ie6 prompt on https
    iframe.setAttribute('id', id);
    iframe.style.display = 'none';
    document.body.appendChild(iframe)
    iframe

  # Creates form, that will be submitted to iframe
  createForm: (id, iframe)->
    params = @options.paramsStore.getParams(id)
    protocol = if @options.demoMode then "GET" else "POST"
    csrf_param = $("meta[name=csrf-param]").attr("content")
    csrf_token = $("meta[name=csrf-token]").attr("content")
    $form = $("<form method='#{protocol}' accept-charset='utf-8' enctype='multipart/form-data'>
  <input type='hidden' name='#{csrf_param}' value='#{csrf_token}'>
</form>")
    endpoint = @options.endpointStore.getEndpoint(id)
    url = endpoint

    params[@options.uuidParamName] = @uuids[id]
    params['utf8'] = '✓'

    url = endpoint + (if /\?/.test(url) then '&' else '?') + $.param(params)

    $form.attr 'action', url
    $form.attr 'target', iframe.name
    $form.css {display: 'none'}
    $form.appendTo(document.body)

    $form

  # api

  add: (fileInput)->
    fileInput.setAttribute('name', @options.inputName)

    id = @inputs.push(fileInput) - 1
    @uuids[id] = utils.getUniqueId()

    # remove file input from DOM
    $(fileInput).remove()

    id

  getName: (id)->
    # get input value and remove path to normalize
    @inputs[id].value.replace(/.*(\/|\\)/, "")

  isValid: (id)-> @inputs[id]?

  reset: ->
    super()
    @inputs = []
    @uuids = []
    @detachLoadEvents = {}

  getUuid: (id) -> @uuids[id]

  cancelFile: (id) ->
    @options.onCancel(id, @getName(id))

    delete @inputs[id]
    delete @uuids[id]
    delete @detachLoadEvents[id]

    iframe = document.getElementById(id)
    if iframe
      # to cancel request set src to something else
      # we use src="javascript:false;" because it doesn't
      # trigger ie6 prompt on https
      iframe.setAttribute('src', 'java' + String.fromCharCode(115) + 'cript:false;'); # deal with "JSLint: javascript URL" warning, which apparently cannot be turned off
      $(iframe).remove()

  uploadFile: (id) ->
    input = @inputs[id]
    fileName = @getName(id)
    iframe = @createIframe(id)
    $form = @createForm(id, iframe);

    if !input
      throw new Error('file with passed id was not added, or already uploaded or cancelled')

    @options.onUpload(id, this.getName(id))

    $form.append(input)

    @attachLoadEvent(iframe, ()=>
      @log('iframe loaded')

      response = @getIframeContentJson(iframe)
      # timeout added to fix busy state in FF3.6
      setTimeout(()->
        $(iframe).remove()
      , 1)

      if !response.success
        if @options.onAutoRetry(id, fileName, response)
          return
            
      @options.onComplete(id, fileName, response)
      @uploadComplete(id)
    )

    @log("Sending upload request for #{id}")
    $form.submit()
    $form.remove()

    id
