local glue = require'glue'
local ffi = require'ffi'
assert(ffi.abi'32bit', 'use luajit32 with this')
local cairo = require'cairo'
require'cairo_quartz'
local objc = require'objc'
--objc.debug = true
local bs = require'objc.BridgeSupport'
bs.loadFramework'Foundation'
bs.loadFramework'AppKit'
bs.loadFramework'CoreGraphics'

--cocoa proxy mechanism

local proxies = {}

local proxyclass = {}

function proxyclass:new(nsobject)
	self = glue.inherit({}, self)
	proxies[tostring(nsobject)] = self
	return self
end

local function proxy(nsself, method, ...)
	local self = proxies[tostring(nsself)]
	return self[method](self, ...)
end

--CairoView subclass

local CairoView = objc.createClass(objc.NSView, 'CairoView', {})

local cview

objc.addMethod(CairoView, objc.SEL('drawRect:'), function(self, sel, ...)
	return proxy(self, 'drawRect', ...)
end, 'v@:ffff')

objc.addMethod(CairoView, objc.SEL('mouseMoved:'), function(self, sel, ...)
	return proxy(self, 'mouseMoved', ...)
end, 'v@:@')

objc.addMethod(CairoView, objc.SEL('mouseDown:'), function(self, sel, ...)
	return proxy(self, 'mouseDown', ...)
end, 'v@:@')

objc.addMethod(CairoView, objc.SEL('rightMouseDown:'), function(self, sel, ...)
	return proxy(self, 'rightMouseDown', ...)
end, 'v@:@')

objc.addMethod(CairoView, objc.SEL('isFlipped'), function(self, sel)
	return true
end, 'B@:')

--CairoView proxy class

local cairoview = glue.update({}, proxyclass)

function cairoview:on_render(cr) end --stub

function cairoview:drawRect(x, y, w, h)
	local q_context = ffi.cast('CGContextRef', objc.NSGraphicsContext:currentContext():graphicsPort())
	if self.q_context ~= q_context or
		self.p_surface:get_image_width() ~= w or 
		self.p_surface:get_image_height() ~= h
	then
		if self.q_surface then
				self.q_cx:free()
				self.q_surface:free()
				self.p_cx:free()
				self.p_surface:free()
		end
		self.q_context = q_context
		self.q_surface = cairo.cairo_quartz_surface_create_for_cg_context(self.q_context, w, h)
		self.q_cx = self.q_surface:create_context()
		self.p_surface = cairo.cairo_image_surface_create(cairo.CAIRO_FORMAT_RGB24, w, h)
		self.q_cx:set_source_surface(self.p_surface, 0, 0)
		self.p_cx = self.p_surface:create_context()
	end
	self:on_render(self.p_cx)
	self.q_cx:paint()
end

function cairoview:mouseMoved(event)
	local loc = event:locationInWindow()
	print(loc.x, loc.y)
end

function cairoview:mouseDown(event)
	local loc = event:locationInWindow()
	print(loc.x, loc.y)
end

function cairoview:rightMouseDown(event)
	local loc = event:locationInWindow()
	print(loc.x, loc.y)
end

--app class

local app = {}

--[[
--create the menubar
local menuBar = NSMenu:alloc():init()
local appMenuItem = NSMenuItem:alloc():init()
menuBar:addItem(appMenuItem)
NSApp:setMainMenu(menuBar)

--create the app menu
local appMenu = NSMenu:alloc():init()
appMenu:setTitle(appName)
quitMenuItem = NSMenuItem:alloc():initWithTitle_action_keyEquivalent(NSStr'Quit', SEL('terminate:'), NSStr('q'))
appMenu:addItem(quitMenuItem)
appMenuItem:setSubmenu(appMenu)
]]

function app:get()
	if not self.nsapp then
		self.nsapp = objc.NSApplication:sharedApplication()
		self.nsapp:setActivationPolicy(bs.NSApplicationActivationPolicyRegular) --normal app with dock and menu bar
	end
	return self
end

function app:run()
	self.nsapp:run()
end

function app:activate()
	self.nsapp:activateIgnoringOtherApps(true)
end

function app:client_rect() end

--window class

local window = {}

function window:new(t) -- {x, y, w, h, state = 'normal'|'minimized'|'maximized', visibile=, title=, resizeable}
	local self = glue.inherit({}, self)
	
	self.nswindow = objc.NSWindow:alloc():initWithContentRect_styleMask_backing_defer({{t.x, t.y}, {t.w, t.h}},
		bit.bor(
			bs.NSTitledWindowMask,
			bs.NSClosableWindowMask,
			bs.NSMiniaturizableWindowMask,
			bs.NSResizableWindowMask),
		bs.NSBackingStoreBuffered,
		false)

	if t.title then
		self:settitle(t.title)
	end
	
	--make a cview and set it as the contents view of the window
	self.cview = CairoView:alloc():init()
	self.cviewp = cairoview:new(self.cview)
	self.cviewp.on_render = self.on_render
	self.nswindow:setContentView(self.cview)
	cview = self.cview
	
	--set tracking area on cview
	local opts = bit.bor(bs.NSTrackingActiveAlways,  --receive mouse-move even when the app is inactive
								bs.NSTrackingInVisibleRect, --auto-sync when the view resizes
								bs.NSTrackingMouseEnteredAndExited,
								bs.NSTrackingMouseMoved)
	local area = objc.NSTrackingArea:alloc():initWithRect_options_owner_userInfo(self.nswindow:frame(), opts, self.cview, nil)
	self.cview:addTrackingArea(area)
	
	return self
end

function window:free()
	proxies[tonumber(self.cview)] = nil
	self.nswindow:release()
end

function window:settitle(title)
	self.nswindow:setTitle(objc.NSStr(title))
end

function window:activate()
  self.nswindow:makeKeyAndOrderFront(app:get().nsapp)
end

function window:show() 

end

function window:hide() end
function window:state(state) end
function window:frame_rect(x, y, w, h) end
function window:client_rect(x, y, w, h) end

function window:on_render(cr)
	cr:set_source_rgba(1,0,0,1)
	cr:paint()
end

if not ... then
	local app = app:get()
	local win = window:new{x = 10, y = 10, w = 800, h = 400, title = 'duude'}
	function win:on_render(cr)
		cr:set_source_rgba(1, 0, 0, 1)
		cr:paint()
	end
	app:activate()
	win:activate()
	app:run()
end


return {
	app = app,
	window = window,
}

