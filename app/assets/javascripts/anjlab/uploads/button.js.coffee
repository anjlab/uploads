class @AnjLab.Uploads.Button

  constructor: (element, options) ->
    @options = $.extend(true, {}, $.fn.uploaderButtonDefaults, options)
    @$element = $(@options.element ? element)

    # make button suitable container for input
    @$element.css
      position: 'relative'
      overflow: 'hidden'
      # Make sure browse button is in the right side
      # in Internet Explorer
      direction: 'ltr'

    @input = @createInput()

  getInput: -> @input

  # cleans/recreates the file input
  reset: ->
    if @input.parentNode
      $(@input).remove()

    @$element.removeClass(@options.focusClass)
    @input = @createInput()

  createInput: ->
    input = document.createElement("input")

    if @options.multiple
      input.setAttribute("multiple", "multiple")

    if @options.acceptFiles
      input.setAttribute("accept", @options.acceptFiles)

    input.setAttribute("type", "file")
    input.setAttribute("name", @options.name)

    $(input).css
      position: 'absolute'
      # in Opera only 'browse' button
      # is clickable and it is located at
      # the right side of the input
      right: 0
      top: 0
      height: 'auto' # bootstrap input[file] height workaround
      fontFamily: 'Arial'
      # 4 persons reported this, the max values that worked for them were 243, 236, 236, 118
      fontSize: '118px'
      margin: 0
      padding: 0
      cursor: 'pointer'
      opacity: 0

    @$element.append(input)

    $(input).on 
      change:    => @options.onChange(input)
      mouseover: => @$element.addClass(@options.hoverClass)
      mouseout:  => @$element.removeClass(@options.hoverClass)
      focus:     => @$element.addClass(@options.focusClass)
      blur:      => @$element.removeClass(@options.focusClass)

    # IE and Opera, unfortunately have 2 tab stops on file input
    # which is unacceptable in our case, disable keyboard access
    if window.attachEvent
      # it is IE or Opera
      input.setAttribute('tabIndex', '-1')

    input

$.fn.uploaderButtonDefaults =  
  element: null
  # if set to true adds multiple attribute to file input
  multiple: false,
  acceptFiles: null,
  # name attribute of file input
  name: 'file',
  onChange: (input) -> null,
  hoverClass: 'qq-upload-button-hover',
  focusClass: 'qq-upload-button-focus'