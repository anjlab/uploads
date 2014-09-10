utils = @AnjLab.Uploads.Utils

class @AnjLab.Uploads.DragAndDrop

  constructor: (zones, options)->
    @droppedFiles = []
    @droppedEntriesCount = 0
    @droppedEntriesParsedCount = 0
    @options = options
    @setupDragDrop(zones)
    
  maybeUploadDroppedFiles: ->
    if @droppedEntriesCount == @droppedEntriesParsedCount && !@dirPending
      @options.callbacks.log("Grabbed #{@droppedFiles.length} files after tree traversal.")
      @zones.each -> $(this).data('dropZone').dropDisabled(false)
      @options.callbacks.dropProcessing(false, @droppedFiles)

  addDroppedFile: (file)->
    @droppedFiles.push(file)
    @droppedEntriesParsedCount += 1
    @maybeUploadDroppedFiles()

  traverseFileTree: (entry)->
    # var dirReader, i;
    dirPending = false
    @droppedEntriesCount+=1

    if entry.isFile
      entry.file (file) => @addDroppedFile(file)
    else if entry.isDirectory
      dirPending = true
      dirReader = entry.createReader();
      dirReader.readEntries (entries) =>
        @droppedEntriesParsedCount+=1;
        for e in entries
          @traverseFileTree(e)

        dirPending = false;

        if !entries.length
          @maybeUploadDroppedFiles()

  isFileDrag: (dragEvent) ->
    for own key, val of dragEvent.dataTransfer.types
      return true if val == 'Files'

    false

  handleDataTransfer: (dataTransfer) ->
    @options.callbacks.dropProcessing(true)
    @zones.each -> $(this).data('dropZone').dropDisabled(true)

    if dataTransfer.files.length > 1 && !@options.multiple
      @options.callbacks.dropProcessing(false)
      @options.callbacks.error('tooManyFilesError', "")
      @zones.each -> $(this).data('dropZone').dropDisabled(false)
    else
      @droppedFiles = [];
      @droppedEntriesCount = 0
      @droppedEntriesParsedCount = 0

      if utils.isFolderDropSupported(dataTransfer)
        items = dataTransfer.items

        i = 0
        for item in items
          entry = item.webkitGetAsEntry()
          if entry
            # due to a bug in Chrome's File System API impl - #149735
            if entry.isFile
              @droppedFiles.push(items[i].getAsFile());
              if (i == items.length - 1)
                @maybeUploadDroppedFiles()
              else
                @traverseFileTree(entry)
          i += 1
      else
        @options.callbacks.dropProcessing(false, dataTransfer.files)
        @zones.each -> $(this).data('dropZone').dropDisabled(false)

  setupDragDrop: (zones)->
    dnd = this
    @zones = $(zones).each ->
      $zone = $(this)
      zoneOpts = $.extend(true, {}, {
        onEnter: (e) =>
          $zone.toggleClass(dnd.options.classes.dropActive, true)
          e.stopPropagation()

        onLeaveNotDescendants: (e) =>
          $zone.toggleClass(dnd.options.classes.dropActive, false)

        onDrop: (e) =>
          $zone.toggleClass(dnd.options.classes.dropActive, false)

          dnd.handleDataTransfer(e.originalEvent.dataTransfer)
      }, dnd.options)

      $zone.data('dropZone', new AnjLab.Uploads.UploadDropZone(this, zoneOpts))

    $(document).on 'drop', (e) -> e.preventDefault()

_dropOutsideDisabled = false
_collection = $()

class @AnjLab.Uploads.UploadDropZone

  constructor: (element, options)->
    @$element = $(element)

    defaultOptions =
      onEnter: (e) -> null
      onLeave: (e) -> null
      # is not fired when leaving element by hovering descendants
      onLeaveNotDescendants: (e) -> null,
      onDrop: (e) -> null

    @options = $.extend(true, {}, defaultOptions, options)

    @disableDropOutside()
    @attachEvents()

  docDragEnter:(e)->
    if (_collection.size() == 0)
      $('body').toggleClass(@options.classes.bodyDragover, true)
    _collection = _collection.add(e.target)

  docDragLeave:(e)->
    #timeout is needed because Firefox 3.6 fires the dragleave event on
    # the previous element before firing dragenter on the next one
    setTimeout( =>
      # remove 'left' element from the collection
      _collection = _collection.not(e.target)

      # if collection is empty we have left the original element
      # (dragleave has fired on all 'entered' elements)
      if _collection.size() == 0
        $('body').toggleClass(@options.classes.bodyDragover, false)
    , 1)

  disableDropOutside: (e) ->
    # run only once for all instances
    if !_dropOutsideDisabled

      $(document).on 'dragover', (e)->
        if e.originalEvent.dataTransfer
          e.originalEvent.dataTransfer.dropEffect = 'none'
          e.preventDefault()
          false

      $(document).on 'dragenter', (e) => @docDragEnter(e)

      $(document).on 'dragleave drop', (e)=> @docDragLeave(e)

    _dropOutsideDisabled = true

  isValidFileDrag: (e)->
    # e.dataTransfer currently causing IE errors
    # IE9 does NOT support file API, so drag-and-drop is not possible
    return false if utils.ie() && !utils.ie10()

    dt = e.originalEvent.dataTransfer
    # do not check dt.types.contains in webkit, because it crashes safari 4
    isSafari = utils.safari()

    # dt.effectAllowed is none in Safari 5
    # dt.types.contains check is for firefox
    effectTest = if utils.ie10() then true else dt.effectAllowed != 'none'
    dt && effectTest && (dt.files || (!isSafari && dt.types.contains && dt.types.contains('Files')))

  isOrSetDropDisabled: (isDisabled)->
    @preventDrop = isDisabled if isDisabled != undefined
    @preventDrop

  attachEvents: ->
    @$element.on 'dragover', (e) =>
      return if !@isValidFileDrag(e)
            
      if utils.ie()
        effect = null
      else
        effect = e.originalEvent.dataTransfer.effectAllowed
      if effect == 'move' || effect == 'linkMove'
        e.originalEvent.dataTransfer.dropEffect = 'move' # for FF (only move allowed)
      else
        e.originalEvent.dataTransfer.dropEffect = 'copy' # for Chrome

      e.stopPropagation()
      e.preventDefault()
      false

    @$element.on 'dragenter', (e) =>
      @docDragEnter(e)
      if !@isOrSetDropDisabled()
        return if !@isValidFileDrag(e)
        @options.onEnter(e)

    @$element.on 'dragleave', (e) =>
      @docDragLeave(e)
      return if !@isValidFileDrag(e)

      @options.onLeave(e)

      relatedTarget = document.elementFromPoint(e.clientX, e.clientY)
      # do not fire when moving a mouse over a descendant
      return if $.contains(this, relatedTarget)

      @options.onLeaveNotDescendants(e)

    @$element.on 'drop', (e) =>
      @docDragLeave(e)
      if !@isOrSetDropDisabled()
        return if !@isValidFileDrag(e)
        e.preventDefault()
        @options.onDrop(e)
        false

  dropDisabled: (isDisabled) -> @isOrSetDropDisabled(isDisabled)
