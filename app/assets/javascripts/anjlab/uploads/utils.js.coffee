@AnjLab ?= {}
@AnjLab.Uploads ?= {}

@AnjLab.Uploads.Utils = {
  log: (message, level)->
    if window.console
      if !level || level == 'info'
        window.console.log(message)
      else
        if window.console[level]
          window.console[level](message)
        else
          window.console.log "[#{level}] #{message}"

  isXhrUploadSupported: ->
    input = document.createElement('input')
    input.type = 'file'

    input.multiple != undefined &&
      typeof File != "undefined" &&
      typeof FormData != "undefined" &&
      typeof (new XMLHttpRequest()).upload != "undefined"

  isFolderDropSupported: (dataTransfer)->
    dataTransfer.items && dataTransfer.items[0].webkitGetAsEntry

  isFileChunkingSupported: ->
    @android() && #android's impl of Blob.slice is broken
    @isXhrUploadSupported() &&
    (File.prototype.slice || File.prototype.webkitSlice || File.prototype.mozSlice)

  parseJson: (string)->
    if JSON?
      JSON.parse string
    else      
      eval("(#{string})")

  # this is a version 4 UUID
  getUniqueId: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3|0x8)
      v.toString(16)
    )

  isFileOrInput: (maybeFileOrInput) ->
    return true if window.File && maybeFileOrInput instanceof File

    if window.HTMLInputElement
      if maybeFileOrInput instanceof HTMLInputElement
        return true if maybeFileOrInput.type && maybeFileOrInput.type.toLowerCase() == 'file'

    if maybeFileOrInput.tagName
      if maybeFileOrInput.tagName.toLowerCase() == 'input'
        return true if maybeFileOrInput.type && maybeFileOrInput.type.toLowerCase() == 'file'

    false

  # Browsers and platforms detection

  ie:      -> navigator.userAgent.indexOf('MSIE') != -1
  ie10:    -> navigator.userAgent.indexOf('MSIE 10') != -1;
  safari:  -> navigator.vendor ? navigator.vendor.indexOf('Apple') != -1
  chrome:  -> navigator.vendor ? navigator.vendor.indexOf('Google') != -1
  firefox: -> navigator.userAgent.indexOf('Mozilla') != -1 && navigator.vendor ? navigator.vendor == ''
  windows: -> navigator.platform == 'Win32'
  android: -> navigator.userAgent.toLowerCase().indexOf('android') != -1

  # Cookies

  setCookie: (name, value, days)->
    date = new Date()
    expires = ""

    if days
      date.setTime(date.getTime()+(days*24*60*60*1000))
      expires = "; expires=#{date.toGMTString()}"

    document.cookie = "#{name}=#{value}#{expires}; path=/"

  getCookie: (name)->
    nameEQ = "#{name}="
    ca = document.cookie.split(';')

    for c in ca
      if c.replace(/^\s+/, '').indexOf(nameEQ) == 0
       return c.substring(nameEQ.length, c.length)

    null

  deleteCookie: (name)->
    @setCookie(name, '', -1)

  getCookieNames: (regexp)->
    cookies = document.cookie.split(';')
    cookieNames = []

    for cookie in cookies
      cookie = cookie.trim()
      equalsIdx = cookie.indexOf('=')

      cookieNames.push(cookie.substr(0, equalsIdx)) if cookie.match(regexp)

    cookieNames

  areCookiesEnabled: ->
    randNum = Math.random() * 100000
    name = "AnjLabCookieTest:#{randNum}"
    @setCookie(name, 1)

    if @getCookie(name)
      @deleteCookie(name)
      true
    else
      false
}