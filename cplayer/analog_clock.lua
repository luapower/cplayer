local player = require'cplayer'

--point on the circle of radius r, at position n, on a circle with f positions starting at -90 degrees.
local function point(n, r, f)
	local a = math.rad((n - f / 4) * (360 / f))
	local y = math.sin(a) * r
	local x = math.cos(a) * r
	return x, y
end

function player:analog_clock(t)
	local cx, cy, r
	if t.cx then
		cx, cy, r = t.cx, t.cy, t.r
	else
		--fit clock in a box
		local x, y, w, h = self:getbox(t)
		r = math.min(w, h) / 2
		cx = x + w / 2
		cy = y + h / 2
	end
	local h = t.time.hour
	local m = t.time.min
	local s = t.time.sec

	--marker lines
	for i = 0, 59 do
		local x1, y1 = point(i, r, 60)
		local x2, y2 = point(i, r * 0.95 * (i % 5 == 0 and 0.9 or 1), 60)
		self:line(cx + x1, cy + y1, cx + x2, cy + y2, t.marker_color or t.color, t.marker_width or t.width)
	end

	h = h + m / 60 --adjust hour by minute

	--hour tongue
	local x2, y2 = point(h, r * 0.4, 12)
	self:line(cx, cy, cx + x2, cy + y2, t.hour_color or t.color, t.hour_width or t.width)

	--minute tongue
	local x2, y2 = point(m, r * 0.7, 60)
	self:line(cx, cy, cx + x2, cy + y2, t.min_color or t.color, t.min_width or t.width)

	--seconds tongue
	local x2, y2 = point(s, r * 0.9, 60)
	self:line(cx, cy, cx + x2, cy + y2, t.sec_color or t.color, t.sec_width or t.width)
end

if not ... then

function player:on_render(cr)
	self:analog_clock{x = 10, y = 10, w = self.w - 20, h = self.h - 20, time = os.date'*t',
		sec_color = '#ff0000', marker_width = 2}
end

player:play()

end
